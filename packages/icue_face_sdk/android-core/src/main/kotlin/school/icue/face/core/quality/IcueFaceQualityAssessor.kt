package school.icue.face.core.quality

import android.graphics.Bitmap
import android.graphics.Color
import com.google.mlkit.vision.face.Face

enum class FaceQualityStatus {
    OK,
    TOO_SMALL,
    BLURRY,
    EXTREME_POSE
}

data class FaceQualityResult(
    val status: FaceQualityStatus,
    val blurScore: Float,
    val isValid: Boolean,
)

object IcueFaceQualityAssessor {
    const val DEFAULT_MIN_FACE_SIZE = 24
    const val DEFAULT_BLUR_THRESHOLD = 80.0f
    const val DEFAULT_LIVE_BLUR_THRESHOLD = 12.0f
    const val MAX_YAW_ANGLE = 35.0f
    const val MAX_PITCH_ANGLE = 25.0f
    const val MAX_LIVE_PITCH_ANGLE = 30.0f

    /**
     * Assesses the quality of a face crop using bounding box size, head pose angles,
     * and grayscale Laplacian variance blur estimation.
     */
    fun assessQuality(
        bitmap: Bitmap,
        face: Face,
        minFaceSize: Int = DEFAULT_MIN_FACE_SIZE,
        minBlurThreshold: Float = DEFAULT_BLUR_THRESHOLD,
    ): FaceQualityResult = assessWithMetrics(
        faceWidth = face.boundingBox.width(),
        faceHeight = face.boundingBox.height(),
        yaw = face.headEulerAngleY,
        pitch = face.headEulerAngleX,
        minFaceSize = minFaceSize,
        maxYawAngle = MAX_YAW_ANGLE,
        maxPitchAngle = MAX_PITCH_ANGLE,
        minBlurThreshold = minBlurThreshold,
        measureBlur = { calculateLaplacianVariance(bitmap) },
    )

    /**
     * Fast quality gate for live recognition on an already-aligned 112x112 face crop.
     * Checks size and pose before computing blur so turned faces skip pixel work.
     */
    internal fun assessAlignedQuality(
        alignedFace: Bitmap,
        face: Face,
        minFaceSize: Int = 30,
        minBlurThreshold: Float = DEFAULT_LIVE_BLUR_THRESHOLD,
        maxYawAngle: Float = MAX_YAW_ANGLE,
        maxPitchAngle: Float = MAX_LIVE_PITCH_ANGLE,
    ): FaceQualityResult = assessWithMetrics(
        faceWidth = face.boundingBox.width(),
        faceHeight = face.boundingBox.height(),
        yaw = face.headEulerAngleY,
        pitch = face.headEulerAngleX,
        minFaceSize = minFaceSize,
        maxYawAngle = maxYawAngle,
        maxPitchAngle = maxPitchAngle,
        minBlurThreshold = minBlurThreshold,
        measureBlur = { calculateLaplacianVariance(alignedFace) },
    )

    internal inline fun assessWithMetrics(
        faceWidth: Int,
        faceHeight: Int,
        yaw: Float,
        pitch: Float,
        minFaceSize: Int,
        maxYawAngle: Float,
        maxPitchAngle: Float,
        minBlurThreshold: Float,
        measureBlur: () -> Float,
    ): FaceQualityResult {
        if (faceWidth < minFaceSize || faceHeight < minFaceSize) {
            return FaceQualityResult(FaceQualityStatus.TOO_SMALL, 0f, false)
        }
        if (kotlin.math.abs(yaw) > maxYawAngle || kotlin.math.abs(pitch) > maxPitchAngle) {
            return FaceQualityResult(FaceQualityStatus.EXTREME_POSE, 0f, false)
        }
        if (minBlurThreshold <= 0f) {
            return FaceQualityResult(FaceQualityStatus.OK, 0f, true)
        }
        val blurScore = measureBlur()
        val adaptiveScale = (faceWidth.toFloat() / 112f).coerceIn(0.25f, 1.0f)
        val effectiveBlurThreshold = minBlurThreshold * adaptiveScale
        if (blurScore < effectiveBlurThreshold) {
            return FaceQualityResult(FaceQualityStatus.BLURRY, blurScore, false)
        }
        return FaceQualityResult(FaceQualityStatus.OK, blurScore, true)
    }

    /**
     * Calculates the variance of Laplacian on the bitmap to estimate image sharpness.
     * Higher variance indicates sharper edges; low variance indicates blur.
     */
    fun calculateLaplacianVariance(bitmap: Bitmap): Float {
        val width = bitmap.width
        val height = bitmap.height
        if (width < 3 || height < 3) return 0f

        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        return calculateLaplacianVariance(pixels, width, height)
    }

    internal fun calculateLaplacianVariance(pixels: IntArray, width: Int, height: Int): Float {
        if (width < 3 || height < 3 || pixels.size < width * height) return 0f

        // Convert to grayscale
        val gray = FloatArray(width * height)
        for (i in 0 until width * height) {
            val p = pixels[i]
            val r = (p shr 16) and 0xff
            val g = (p shr 8) and 0xff
            val b = p and 0xff
            gray[i] = 0.299f * r + 0.587f * g + 0.114f * b
        }

        // Apply 3x3 Laplacian kernel: [[0, 1, 0], [1, -4, 1], [0, 1, 0]]
        var sum = 0.0
        var sqSum = 0.0
        var count = 0

        for (y in 1 until height - 1) {
            val rowOffset = y * width
            val prevRowOffset = (y - 1) * width
            val nextRowOffset = (y + 1) * width

            for (x in 1 until width - 1) {
                val center = gray[rowOffset + x]
                val up = gray[prevRowOffset + x]
                val down = gray[nextRowOffset + x]
                val left = gray[rowOffset + x - 1]
                val right = gray[rowOffset + x + 1]

                val laplacian = up + down + left + right - 4f * center
                sum += laplacian
                sqSum += laplacian * laplacian
                count++
            }
        }

        if (count == 0) return 0f

        val mean = sum / count
        val variance = (sqSum / count) - (mean * mean)
        return variance.toFloat().coerceAtLeast(0f)
    }
}
