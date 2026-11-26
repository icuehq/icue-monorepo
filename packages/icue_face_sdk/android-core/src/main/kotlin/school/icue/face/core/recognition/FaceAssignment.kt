package school.icue.face.core.recognition

/**
 * Decides which roster profile each detected face is. A face is matched only to its own best
 * profile, and only when that score clears [threshold], beats the face's runner-up by [margin]
 * (two students who look alike are left unmatched rather than guessed), the profile is not in
 * [blockedProfiles], and no other face scores that profile higher.
 */
internal object FaceAssignment {
    /** [scores] is face x profile; returns the profile index for each face, or -1. */
    fun assign(
        scores: List<FloatArray>,
        threshold: Float,
        margin: Float,
        blockedProfiles: Set<Int> = emptySet(),
    ): IntArray {
        val assigned = IntArray(scores.size) { -1 }
        val owner = HashMap<Int, Int>()
        scores.forEachIndexed { face, row ->
            var best = -1
            var bestScore = -1f
            var runnerUp = -1f
            row.forEachIndexed { profile, score ->
                if (score > bestScore) {
                    runnerUp = bestScore
                    bestScore = score
                    best = profile
                } else if (score > runnerUp) {
                    runnerUp = score
                }
            }
            if (best < 0 || best in blockedProfiles) return@forEachIndexed
            if (bestScore < threshold || bestScore - runnerUp < margin) return@forEachIndexed
            val rival = owner[best]
            if (rival != null && scores[rival][best] >= bestScore) return@forEachIndexed
            if (rival != null) assigned[rival] = -1
            owner[best] = face
            assigned[face] = best
        }
        return assigned
    }
}
