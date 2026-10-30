package school.icue.face.core.recognition

import school.icue.face.core.FaceSdkDefaults
import school.icue.face.core.utils.EmbeddingMath
import java.util.concurrent.atomic.AtomicReference

enum class MatchStatus {
    MATCH,
    EMPTY_ROSTER,
    BELOW_THRESHOLD,
    AMBIGUOUS_MATCH,
    INVALID_QUERY,
    INCOMPATIBLE_ROSTER
}

data class NativeMatchResult(
    val status: MatchStatus,
    val matchedPersonId: String? = null,
    val score: Float = -1f,
    val rosterRevision: String = "",
    val top1Score: Float = -1f,
    val top2Score: Float = -1f
)

data class NativeRosterSnapshot(
    val rosterRevision: String,
    val modelContractId: String,
    val personIds: List<String>,
    val matrix: FloatArray, // Contiguous N x 192 FloatArray
    val rowCount: Int,
    val embeddingDim: Int = FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE
)

class NativeRosterMatcher {
    private val currentSnapshot = AtomicReference<NativeRosterSnapshot?>(null)

    fun loadRosterPayload(
        rosterRevision: String,
        modelContractId: String,
        personIds: List<String>,
        embeddingsBuffer: FloatArray
    ) {
        require(personIds.size * FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE == embeddingsBuffer.size) {
            "Embeddings buffer size does not match person count * 192"
        }

        val snapshot = NativeRosterSnapshot(
            rosterRevision = rosterRevision,
            modelContractId = modelContractId,
            personIds = personIds,
            matrix = embeddingsBuffer.copyOf(),
            rowCount = personIds.size
        )
        currentSnapshot.set(snapshot)
    }

    fun clearRoster() {
        currentSnapshot.set(null)
    }

    fun match(
        queryEmbedding: FloatArray,
        threshold: Float = FaceSdkDefaults.DEFAULT_MATCH_THRESHOLD,
        ambiguityMargin: Float = FaceSdkDefaults.DEFAULT_AMBIGUITY_MARGIN
    ): NativeMatchResult {
        val snapshot = currentSnapshot.get()
            ?: return NativeMatchResult(MatchStatus.EMPTY_ROSTER)

        if (snapshot.rowCount == 0) {
            return NativeMatchResult(MatchStatus.EMPTY_ROSTER, rosterRevision = snapshot.rosterRevision)
        }

        if (queryEmbedding.size != FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE) {
            return NativeMatchResult(MatchStatus.INVALID_QUERY, rosterRevision = snapshot.rosterRevision)
        }

        val N = snapshot.rowCount
        val dim = snapshot.embeddingDim
        val matrix = snapshot.matrix

        // Map highest score per distinct person ID
        val personTopScores = HashMap<String, Float>()

        for (i in 0 until N) {
            val personId = snapshot.personIds[i]
            val offset = i * dim
            
            // Fast Dot Product of L2-normalized vectors
            var dot = 0f
            for (j in 0 until dim) {
                dot += matrix[offset + j] * queryEmbedding[j]
            }

            val currentBest = personTopScores[personId] ?: -1f
            if (dot > currentBest) {
                personTopScores[personId] = dot
            }
        }

        val sortedEntries = personTopScores.entries.sortedByDescending { it.value }
        if (sortedEntries.isEmpty()) {
            return NativeMatchResult(MatchStatus.EMPTY_ROSTER, rosterRevision = snapshot.rosterRevision)
        }

        val top1PersonId = sortedEntries[0].key
        val top1Score = sortedEntries[0].value

        // Case 1: Single distinct person in roster
        if (sortedEntries.size == 1) {
            return if (top1Score >= threshold) {
                NativeMatchResult(
                    status = MatchStatus.MATCH,
                    matchedPersonId = top1PersonId,
                    score = top1Score,
                    rosterRevision = snapshot.rosterRevision,
                    top1Score = top1Score
                )
            } else {
                NativeMatchResult(
                    status = MatchStatus.BELOW_THRESHOLD,
                    score = top1Score,
                    rosterRevision = snapshot.rosterRevision,
                    top1Score = top1Score
                )
            }
        }

        // Case 2: Multi-person roster (Top-1 vs Top-2 ambiguity check)
        val top2Score = sortedEntries[1].value

        if (top1Score < threshold) {
            return NativeMatchResult(
                status = MatchStatus.BELOW_THRESHOLD,
                score = top1Score,
                rosterRevision = snapshot.rosterRevision,
                top1Score = top1Score,
                top2Score = top2Score
            )
        }

        if ((top1Score - top2Score) < ambiguityMargin) {
            return NativeMatchResult(
                status = MatchStatus.AMBIGUOUS_MATCH,
                score = top1Score,
                rosterRevision = snapshot.rosterRevision,
                top1Score = top1Score,
                top2Score = top2Score
            )
        }

        return NativeMatchResult(
            status = MatchStatus.MATCH,
            matchedPersonId = top1PersonId,
            score = top1Score,
            rosterRevision = snapshot.rosterRevision,
            top1Score = top1Score,
            top2Score = top2Score
        )
    }

    fun getActiveRevision(): String? = currentSnapshot.get()?.rosterRevision
}
