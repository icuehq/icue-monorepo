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
    const val MAX_YAW_ANGLE = 35.0f
    const val MAX_PITCH_ANGLE = 25.0f

    /**
     * Assesses the quality of a face crop using bounding box size, head pose angles,
     * and grayscale Laplacian variance blur estimation.
     */
    fun assessQuality(
        bitmap: Bitmap,
        face: Face,
        minFaceSize: Int = DEFAULT_MIN_FACE_SIZE,
        minBlurThreshold: Float = DEFAULT_BLUR_THRESHOLD,
    ): FaceQualityResult {
        val bbox = face.boundingBox
        if (bbox.width() < minFaceSize || bbox.height() < minFaceSize) {
            return FaceQualityResult(FaceQualityStatus.TOO_SMALL, 0f, false)
        }

        val yaw = face.headEulerAngleY
        val pitch = face.headEulerAngleX
        if (Math.abs(yaw) > MAX_YAW_ANGLE || Math.abs(pitch) > MAX_PITCH_ANGLE) {
            return FaceQualityResult(FaceQualityStatus.EXTREME_POSE, 0f, false)
        }

        val blurScore = calculateLaplacianVariance(bitmap)
        val faceWidth = bbox.width()
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

        // Convert to grayscale
        val gray = FloatArray(width * height)
        for (i in pixels.indices) {
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
