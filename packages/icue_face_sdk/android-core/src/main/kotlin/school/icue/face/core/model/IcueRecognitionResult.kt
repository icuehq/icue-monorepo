package school.icue.face.core.model

data class IcueRecognitionResult(
    val personId: String?,
    val score: Float,
    val matched: Boolean,
    val boundingBox: IcueBoundingBox,
)
