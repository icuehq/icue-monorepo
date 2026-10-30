package school.icue.face.core.utils

import kotlin.math.sqrt
import school.icue.face.core.FaceSdkDefaults

object EmbeddingMath {
    fun cosineSimilarity(first: FloatArray, second: FloatArray): Float {
        validatePair(first, second)

        var dotProduct = 0f
        var firstMagnitude = 0f
        var secondMagnitude = 0f
        for (index in first.indices) {
            val firstValue = first[index]
            val secondValue = second[index]
            dotProduct += firstValue * secondValue
            firstMagnitude += firstValue * firstValue
            secondMagnitude += secondValue * secondValue
        }

        if (firstMagnitude == 0f || secondMagnitude == 0f) return 0f
        return dotProduct / (sqrt(firstMagnitude) * sqrt(secondMagnitude))
    }

    fun dotProductOfNormalized(first: FloatArray, second: FloatArray): Float {
        validatePair(first, second)
        var result = 0f
        for (index in first.indices) result += first[index] * second[index]
        return result.coerceIn(-1f, 1f)
    }

    fun l2Normalize(embedding: FloatArray): FloatArray {
        require(embedding.isNotEmpty()) { "Embedding cannot be empty" }
        require(embedding.all(Float::isFinite)) { "Embedding values must be finite" }

        var sum = 0f
        for (value in embedding) sum += value * value
        val norm = sqrt(sum)
        if (norm == 0f) return embedding.copyOf()
        return FloatArray(embedding.size) { embedding[it] / norm }
    }

    fun validateEmbedding(embedding: FloatArray) {
        require(embedding.size == FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE) {
            "Embedding must contain ${FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE} values"
        }
        require(embedding.all(Float::isFinite)) { "Embedding values must be finite" }
    }

    private fun validatePair(first: FloatArray, second: FloatArray) {
        require(first.isNotEmpty()) { "First embedding cannot be empty" }
        require(first.size == second.size) {
            "Embedding sizes must match. first=${first.size}, second=${second.size}"
        }
        require(first.all(Float::isFinite) && second.all(Float::isFinite)) {
            "Embedding values must be finite"
        }
    }
}
