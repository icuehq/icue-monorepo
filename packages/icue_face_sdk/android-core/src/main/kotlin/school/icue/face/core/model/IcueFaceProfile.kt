package school.icue.face.core.model

data class IcueFaceProfile(
    val personId: String,
    val embedding: FloatArray,
    val name: String? = null,
    val label: String? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is IcueFaceProfile) return false
        if (personId != other.personId) return false
        if (name != other.name) return false
        if (label != other.label) return false
        if (!embedding.contentEquals(other.embedding)) return false
        return true
    }

    override fun hashCode(): Int {
        var result = personId.hashCode()
        result = 31 * result + (name?.hashCode() ?: 0)
        result = 31 * result + (label?.hashCode() ?: 0)
        result = 31 * result + embedding.contentHashCode()
        return result
    }
}
