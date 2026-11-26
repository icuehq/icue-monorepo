package school.icue.face.core.model

data class IcueRecognitionResult(
    val personId: String?,
    val score: Float,
    val matched: Boolean,
    val boundingBox: IcueBoundingBox,
    /** The face's embedding; null when nothing was computed (no roster, or eyes not found). */
    val embedding: FloatArray? = null,
    /** True when live tracking replayed this face's earlier result instead of re-running the model. */
    val reused: Boolean = false,
)

/** Channel map of a face nobody matched, with its embedding so the app can enrol or cluster it. */
fun IcueRecognitionResult.toUnrecognizedFaceMap(): Map<String, Any?> = mapOf(
    "embedding" to embedding?.map { it.toDouble() },
    "score" to score.toDouble(),
    "boundingBox" to mapOf(
        "left" to boundingBox.left,
        "top" to boundingBox.top,
        "right" to boundingBox.right,
        "bottom" to boundingBox.bottom,
        "trackingId" to boundingBox.trackingId,
    ),
    "timestampMillis" to System.currentTimeMillis(),
)
