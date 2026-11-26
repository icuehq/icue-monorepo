package school.icue.face.core.quality

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IcueFaceQualityAssessorTest {
    @Test
    fun rejectsSmallFacesAndExtremePoseBeforeBlur() {
        var blurCalled = false
        val small = IcueFaceQualityAssessor.assessWithMetrics(
            faceWidth = 20,
            faceHeight = 20,
            yaw = 0f,
            pitch = 0f,
            minFaceSize = 30,
            maxYawAngle = 35f,
            maxPitchAngle = 30f,
            minBlurThreshold = 12f,
            measureBlur = { blurCalled = true; 100f },
        )
        assertEquals(FaceQualityStatus.TOO_SMALL, small.status)
        assertFalse(small.isValid)
        assertFalse(blurCalled)

        val turned = IcueFaceQualityAssessor.assessWithMetrics(
            faceWidth = 80,
            faceHeight = 80,
            yaw = 40f,
            pitch = 0f,
            minFaceSize = 30,
            maxYawAngle = 35f,
            maxPitchAngle = 30f,
            minBlurThreshold = 12f,
            measureBlur = { blurCalled = true; 100f },
        )
        assertEquals(FaceQualityStatus.EXTREME_POSE, turned.status)
        assertFalse(turned.isValid)
        assertFalse(blurCalled)
    }

    @Test
    fun adaptiveBlurThresholdAllowsSharpSmallFacesAndRejectsSmearedOnes() {
        val sharpSmall = IcueFaceQualityAssessor.assessWithMetrics(
            faceWidth = 56,
            faceHeight = 56,
            yaw = 5f,
            pitch = -10f,
            minFaceSize = 30,
            maxYawAngle = 35f,
            maxPitchAngle = 30f,
            minBlurThreshold = 12f,
            measureBlur = { 8f }, // >= 12 * (56 / 112) = 6
        )
        assertEquals(FaceQualityStatus.OK, sharpSmall.status)
        assertTrue(sharpSmall.isValid)

        val smeared = IcueFaceQualityAssessor.assessWithMetrics(
            faceWidth = 112,
            faceHeight = 112,
            yaw = 0f,
            pitch = 0f,
            minFaceSize = 30,
            maxYawAngle = 35f,
            maxPitchAngle = 30f,
            minBlurThreshold = 12f,
            measureBlur = { 4f },
        )
        assertEquals(FaceQualityStatus.BLURRY, smeared.status)
        assertFalse(smeared.isValid)
    }

    @Test
    fun laplacianVarianceDistinguishesFlatAndSharpPatterns() {
        val size = 8
        val flat = IntArray(size * size) { 0xFF808080.toInt() }
        val checkerboard = IntArray(size * size) { index ->
            val x = index % size
            val y = index / size
            if ((x + y) % 2 == 0) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
        }

        assertEquals(0f, IcueFaceQualityAssessor.calculateLaplacianVariance(flat, size, size), 0.001f)
        assertTrue(IcueFaceQualityAssessor.calculateLaplacianVariance(checkerboard, size, size) > 1000f)
    }
}
