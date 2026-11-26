package school.icue.face.core.recognition

import school.icue.face.core.utils.EmbeddingMath

/**
 * Decides which faces in a live attendance session are people not on the roster. A face counts
 * only after [requiredChecks] model runs found no student for it, so a student's first blurry
 * frames are never reported as a stranger.
 *
 * Faces are told apart by their embeddings, not ML Kit tracking IDs: tracking IDs can be missing,
 * and change whenever a face is lost and found again, which would split or double-count people.
 *
 * Called from the analysis loop and, at the end, from the UI thread, so every method locks.
 */
internal class UnknownFaceTracker(
    private val requiredChecks: Int = 3,
    // Two embeddings this similar are the same person. The same face scores about 0.9 from frame
    // to frame and different people about 0.4, so 0.6 sits safely between.
    private val samePersonSimilarity: Float = 0.6f,
) {
    private class Candidate(var embedding: FloatArray, var checks: Int, var details: Map<String, Any?>)

    private val candidates = mutableListOf<Candidate>()

    /** A fresh model run found no student for this face. */
    @Synchronized
    fun recordMiss(embedding: FloatArray, details: Map<String, Any?>) {
        val candidate = find(embedding)
        if (candidate == null) {
            candidates += Candidate(embedding, 1, details)
        } else {
            candidate.checks++
            candidate.embedding = embedding
            candidate.details = details
        }
    }

    /** True once this face has been checked enough times and never turned out to be a student. */
    @Synchronized
    fun isConfirmed(embedding: FloatArray): Boolean = find(embedding)?.let { it.checks >= requiredChecks } == true

    /** The face was counted as a student, so its earlier misses were just bad frames. */
    @Synchronized
    fun forget(embedding: FloatArray) {
        candidates.removeAll { EmbeddingMath.dotProductOfNormalized(it.embedding, embedding) >= samePersonSimilarity }
    }

    /** One entry per confirmed unknown person. */
    @Synchronized
    fun confirmed(): List<Map<String, Any?>> = candidates.filter { it.checks >= requiredChecks }.map { it.details }

    private fun find(embedding: FloatArray): Candidate? =
        candidates
            .map { it to EmbeddingMath.dotProductOfNormalized(it.embedding, embedding) }
            .filter { (_, similarity) -> similarity >= samePersonSimilarity }
            .maxByOrNull { (_, similarity) -> similarity }
            ?.first
}
