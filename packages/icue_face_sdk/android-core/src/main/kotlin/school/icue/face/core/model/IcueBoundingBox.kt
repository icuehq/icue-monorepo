package school.icue.face.core.model

data class IcueBoundingBox(
    val left: Float,
    val top: Float,
    val right: Float,
    val bottom: Float,
    val trackingId: Int? = null,
)
