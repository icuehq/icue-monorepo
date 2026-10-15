package school.icue.face.core.model

enum class AttendanceType {
    ATTENDANCE,
    TRANSPORT;

    companion object {
        fun fromString(value: String?): AttendanceType {
            return when (value?.trim()?.uppercase()) {
                "ATTENDANCE" -> ATTENDANCE
                else -> TRANSPORT
            }
        }
    }
}
