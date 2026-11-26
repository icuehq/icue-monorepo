package school.icue.face.core.recognition

import kotlin.math.sqrt

/**
 * Remembers who each ML Kit-tracked face is, so live tracking computes an embedding only for
 * new faces and periodic re-checks instead of for every face in every frame. Embeddings are the
 * dominant per-frame cost on low-end phones once several students are in view.
 *
 * A tracking ID alone does not prove it is still the same person: ML Kit keeps the ID when one
 * face replaces another in the same spot (a swapped photo, students crossing). So each entry
 * also keeps a tiny grayscale [signature] of the aligned face, and is reused only while the
 * current face still looks like it.
 *
 * One instance per camera stream: ML Kit tracking IDs mean nothing across streams. Not
 * thread-safe; [school.icue.face.core.IcueFaceSdk] uses it inside its operation lock.
 */
internal class TrackedIdentityCache(
    // Tuning knobs: higher saves more work on slow phones, lower corrects a wrong label sooner.
    private val matchedRefreshFrames: Int = 10,
    private val unmatchedRefreshFrames: Int = 3,
    // Correlation of two signatures below which the face is treated as a different person.
    // ponytail: fixed value; raise it if swaps slip through, lower it if live faces re-check too often.
    private val minSameFaceCorrelation: Float = 0.9f,
) {
    data class Identity(
        val personId: String?,
        val score: Float,
        val matched: Boolean,
        val embedding: FloatArray?,
        val signature: FloatArray? = null,
    )

    private data class Entry(val identity: Identity, val storedAtFrame: Long)

    private val entries = HashMap<Int, Entry>()
    private var frame = 0L

    /** Starts a new frame and forgets faces the detector is no longer tracking. */
    fun startFrame(trackingIds: Set<Int>) {
        frame++
        entries.keys.retainAll(trackingIds)
    }

    /**
     * The remembered identity, or null when the face is new, due for a re-check, or no longer
     * looks like the face that was recognized ([signature] is null when it cannot be compared).
     */
    fun reusable(trackingId: Int?, signature: FloatArray?): Identity? {
        val entry = entries[trackingId ?: return null] ?: return null
        val refreshFrames = if (entry.identity.matched) matchedRefreshFrames else unmatchedRefreshFrames
        if (frame - entry.storedAtFrame >= refreshFrames) return null
        val stored = entry.identity.signature ?: return null
        if (signature == null || correlation(stored, signature) < minSameFaceCorrelation) return null
        return entry.identity
    }

    /** Makes the next frame run the model on this face again. */
    fun forget(trackingId: Int?) {
        if (trackingId != null) entries.remove(trackingId)
    }

    fun store(trackingId: Int?, identity: Identity) {
        if (trackingId != null) entries[trackingId] = Entry(identity, frame)
    }

    companion object {
        /** Zero-mean, unit-length copy of [gray] luminance values, so lighting shifts matter less. */
        fun signatureOf(gray: FloatArray): FloatArray {
            val mean = gray.average().toFloat()
            val centred = FloatArray(gray.size) { gray[it] - mean }
            val norm = sqrt(centred.fold(0f) { sum, value -> sum + value * value })
            return if (norm == 0f) centred else FloatArray(centred.size) { centred[it] / norm }
        }

        fun correlation(first: FloatArray, second: FloatArray): Float {
            if (first.size != second.size) return -1f
            var dot = 0f
            for (index in first.indices) dot += first[index] * second[index]
            return dot
        }
    }
}
