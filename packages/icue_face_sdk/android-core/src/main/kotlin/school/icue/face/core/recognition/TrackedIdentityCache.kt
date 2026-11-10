package school.icue.face.core.recognition

/**
 * Remembers who each ML Kit-tracked face is, so live tracking computes an embedding only for
 * new faces and periodic re-checks instead of for every face in every frame. Embeddings are the
 * dominant per-frame cost on low-end phones once several students are in view.
 *
 * One instance per camera stream: ML Kit tracking IDs mean nothing across streams. Not
 * thread-safe; [school.icue.face.core.IcueFaceSdk] uses it inside its operation lock.
 */
internal class TrackedIdentityCache(
    // Tuning knobs: higher saves more work on slow phones, lower corrects a wrong label sooner.
    private val matchedRefreshFrames: Int = 10,
    private val unmatchedRefreshFrames: Int = 3,
) {
    data class Identity(val personId: String?, val score: Float, val matched: Boolean)

    private data class Entry(val identity: Identity, val storedAtFrame: Long)

    private val entries = HashMap<Int, Entry>()
    private var frame = 0L

    /** Starts a new frame and forgets faces the detector is no longer tracking. */
    fun startFrame(trackingIds: Set<Int>) {
        frame++
        entries.keys.retainAll(trackingIds)
    }

    /** The remembered identity, or null when the face is new or due for a re-check. */
    fun reusable(trackingId: Int?): Identity? {
        val entry = entries[trackingId ?: return null] ?: return null
        val refreshFrames = if (entry.identity.matched) matchedRefreshFrames else unmatchedRefreshFrames
        return entry.identity.takeIf { frame - entry.storedAtFrame < refreshFrames }
    }

    fun store(trackingId: Int?, identity: Identity) {
        if (trackingId != null) entries[trackingId] = Entry(identity, frame)
    }
}
