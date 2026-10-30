package school.icue.face.core.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import school.icue.face.core.FaceSdkDefaults

class EmbeddingMathTest {
    @Test
    fun l2NormalizeProducesUnitVector() {
        val normalized = EmbeddingMath.l2Normalize(floatArrayOf(3f, 4f))

        assertEquals(0.6f, normalized[0], 0.0001f)
        assertEquals(0.8f, normalized[1], 0.0001f)
        assertEquals(1f, EmbeddingMath.cosineSimilarity(normalized, normalized), 0.0001f)
    }

    @Test
    fun cosineSimilarityRejectsMismatchedEmbeddings() {
        assertThrows(IllegalArgumentException::class.java) {
            EmbeddingMath.cosineSimilarity(floatArrayOf(1f), floatArrayOf(1f, 2f))
        }
    }

    @Test
    fun validateEmbeddingRejectsWrongDimensionAndNonFiniteValues() {
        assertThrows(IllegalArgumentException::class.java) {
            EmbeddingMath.validateEmbedding(floatArrayOf(1f))
        }
        assertThrows(IllegalArgumentException::class.java) {
            EmbeddingMath.validateEmbedding(
                FloatArray(FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE).also {
                    it[0] = Float.NaN
                },
            )
        }
    }
}
