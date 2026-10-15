package school.icue.face.core.model

data class IcueRecognitionResult(
    val personId: String?,
    val score: Float,
    val matched: Boolean,
    val boundingBox: IcueBoundingBox,
    val name: String? = null,
    val label: String? = null,
)
