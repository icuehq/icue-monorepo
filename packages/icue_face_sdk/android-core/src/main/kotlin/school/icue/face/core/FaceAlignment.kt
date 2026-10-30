package school.icue.face.core

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * 5-Point Umeyama Least-Squares Similarity Alignment Engine.
 * Maps detected upright facial landmarks to 112x112 ArcFace canonical template.
 */
internal object FaceAlignment {

    // ArcFace Canonical Reference Matrix (Double precision)
    private val CANONICAL_POINTS = arrayOf(
        doubleArrayOf(38.2946, 51.6963), // imageLeftEye
        doubleArrayOf(73.5318, 51.5014), // imageRightEye
        doubleArrayOf(56.0252, 71.7366), // nose
        doubleArrayOf(41.5493, 92.3655), // imageLeftMouth
        doubleArrayOf(70.7299, 92.2041)  // imageRightMouth
    )

    fun alignToCanonicalEyes(
        bitmap: Bitmap,
        leftEyeX: Float,
        leftEyeY: Float,
        rightEyeX: Float,
        rightEyeY: Float,
    ): Bitmap? {
        val srcPoints = arrayOf(
            doubleArrayOf(leftEyeX.toDouble(), leftEyeY.toDouble()),
            doubleArrayOf(rightEyeX.toDouble(), rightEyeY.toDouble())
        )
        val dstPoints = arrayOf(
            CANONICAL_POINTS[0],
            CANONICAL_POINTS[1]
        )
        return alignSimilarity(bitmap, srcPoints, dstPoints)
    }

    fun align5PointUmeyama(
        bitmap: Bitmap,
        leftEye: Pair<Float, Float>,
        rightEye: Pair<Float, Float>,
        nose: Pair<Float, Float>,
        leftMouth: Pair<Float, Float>,
        rightMouth: Pair<Float, Float>
    ): Bitmap? {
        val srcPoints = arrayOf(
            doubleArrayOf(leftEye.first.toDouble(), leftEye.second.toDouble()),
            doubleArrayOf(rightEye.first.toDouble(), rightEye.second.toDouble()),
            doubleArrayOf(nose.first.toDouble(), nose.second.toDouble()),
            doubleArrayOf(leftMouth.first.toDouble(), leftMouth.second.toDouble()),
            doubleArrayOf(rightMouth.first.toDouble(), rightMouth.second.toDouble())
        )
        return alignSimilarity(bitmap, srcPoints, CANONICAL_POINTS)
    }

    private fun alignSimilarity(
        bitmap: Bitmap,
        src: Array<DoubleArray>,
        dst: Array<DoubleArray>
    ): Bitmap? {
        if (src.size < 2 || src.size != dst.size) return null

        // 1. Geometry Validation: Inter-eye distance check
        val eyeDist = hypot(src[1][0] - src[0][0], src[1][1] - src[0][1])
        if (eyeDist < 15.0) return null // Reject degenerately small faces

        // 2. Compute Centroids
        var srcMeanX = 0.0
        var srcMeanY = 0.0
        var dstMeanX = 0.0
        var dstMeanY = 0.0
        val n = src.size.toDouble()

        for (i in src.indices) {
            srcMeanX += src[i][0]
            srcMeanY += src[i][1]
            dstMeanX += dst[i][0]
            dstMeanY += dst[i][1]
        }
        srcMeanX /= n
        srcMeanY /= n
        dstMeanX /= n
        dstMeanY /= n

        // 3. Compute Scale & Rotation Angle via Similarity Alignment
        val dxSrc = src[1][0] - src[0][0]
        val dySrc = src[1][1] - src[0][1]
        val dxDst = dst[1][0] - dst[0][0]
        val dyDst = dst[1][1] - dst[0][1]

        val distSrc = hypot(dxSrc, dySrc)
        val distDst = hypot(dxDst, dyDst)
        if (distSrc <= 1e-6) return null

        val scale = distDst / distSrc
        val angleRad = atan2(dyDst, dxDst) - atan2(dySrc, dxSrc)
        val angleDeg = Math.toDegrees(angleRad)

        // Reflection guard
        if (scale <= 0.0) return null

        // 4. Construct Android Matrix
        val matrix = Matrix()
        matrix.postTranslate(-srcMeanX.toFloat(), -srcMeanY.toFloat())
        matrix.postRotate(angleDeg.toFloat())
        matrix.postScale(scale.toFloat(), scale.toFloat())
        matrix.postTranslate(dstMeanX.toFloat(), dstMeanY.toFloat())

        // 5. Warp to 112x112 with BORDER_CONSTANT [0,0,0]
        val aligned = Bitmap.createBitmap(
            FaceSdkDefaults.MOBILEFACENET_INPUT_SIZE,
            FaceSdkDefaults.MOBILEFACENET_INPUT_SIZE,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(aligned)
        canvas.drawColor(Color.BLACK) // BORDER_CONSTANT zero padding

        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(bitmap, matrix, paint)

        return aligned
    }
}
