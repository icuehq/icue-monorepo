package school.icue.face.core.recognition

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class FaceAssignmentTest {
    private fun assign(vararg rows: FloatArray, blocked: Set<Int> = emptySet()) =
        FaceAssignment.assign(rows.toList(), threshold = 0.68f, margin = 0.05f, blockedProfiles = blocked)

    @Test
    fun clearBestMatchIsAssigned() {
        assertArrayEquals(intArrayOf(1), assign(floatArrayOf(0.30f, 0.82f, 0.40f)))
    }

    @Test
    fun scoreBelowThresholdIsUnmatched() {
        assertArrayEquals(intArrayOf(-1), assign(floatArrayOf(0.30f, 0.60f)))
    }

    @Test
    fun nearTieIsUnmatchedInsteadOfGuessed() {
        assertArrayEquals(intArrayOf(-1), assign(floatArrayOf(0.80f, 0.77f)))
    }

    @Test
    fun singleProfileNeedsOnlyTheThreshold() {
        assertArrayEquals(intArrayOf(0), assign(floatArrayOf(0.70f)))
    }

    @Test
    fun strongerFaceKeepsAContestedProfileAndTheOtherIsNotReassigned() {
        // Both faces look most like profile 0; the weaker one must not fall back to profile 1.
        assertArrayEquals(
            intArrayOf(-1, 0),
            assign(floatArrayOf(0.80f, 0.70f), floatArrayOf(0.90f, 0.10f)),
        )
    }

    @Test
    fun profileHeldByATrackedFaceBlocksTheMatch() {
        assertArrayEquals(intArrayOf(-1), assign(floatArrayOf(0.90f, 0.75f), blocked = setOf(0)))
    }
}
