package school.icue.face.core.model

data class IcueRecognitionResult(
    val personId: String?,
    val score: Float,
    val matched: Boolean,
    val boundingBox: IcueBoundingBox,
    /** The face's embedding; null only when no roster was given, so nothing was computed. */
    val embedding: FloatArray? = null,
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
