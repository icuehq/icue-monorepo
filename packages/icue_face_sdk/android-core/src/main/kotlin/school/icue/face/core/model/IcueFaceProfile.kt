package school.icue.face.core.model

data class IcueFaceProfile(
    val personId: String,
    val embedding: FloatArray,
    /** Shown on the camera overlay instead of [personId] when present. */
    val name: String? = null,
)
