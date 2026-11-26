package school.icue.face.core.recognition

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import school.icue.face.core.utils.EmbeddingMath

class UnknownFaceTrackerTest {
    // 192-value unit vectors: stranger, the same stranger a frame later, and a different person.
    private fun face(vararg values: Pair<Int, Float>) =
        EmbeddingMath.l2Normalize(FloatArray(192).also { array -> values.forEach { (index, value) -> array[index] = value } })

    private val stranger = face(0 to 1f)
    private val strangerNextFrame = face(0 to 1f, 1 to 0.2f)
    private val otherPerson = face(5 to 1f)

    @Test
    fun faceIsConfirmedUnknownOnlyAfterThreeMisses() {
        val tracker = UnknownFaceTracker()
        assertFalse(tracker.recordMiss(stranger, mapOf("n" to 1)))
        assertFalse(tracker.recordMiss(strangerNextFrame, mapOf("n" to 2)))
        assertFalse(tracker.isConfirmed(stranger))

        assertTrue(tracker.recordMiss(stranger, mapOf("n" to 3)))
        assertFalse(tracker.recordMiss(stranger, mapOf("n" to 4)))
        assertTrue(tracker.isConfirmed(strangerNextFrame))
        assertEquals(listOf(mapOf("n" to 4)), tracker.confirmed())
    }

    @Test
    fun differentPeopleAreCountedSeparately() {
        val tracker = UnknownFaceTracker(requiredChecks = 1)
        tracker.recordMiss(stranger, emptyMap())
        tracker.recordMiss(otherPerson, emptyMap())

        assertEquals(2, tracker.confirmed().size)
    }

    @Test
    fun faceCountedAsAStudentIsNeverReportedUnknown() {
        val tracker = UnknownFaceTracker()
        repeat(3) { tracker.recordMiss(stranger, emptyMap()) }
        tracker.forget(strangerNextFrame)

        assertFalse(tracker.isConfirmed(stranger))
        assertTrue(tracker.confirmed().isEmpty())
    }
}
