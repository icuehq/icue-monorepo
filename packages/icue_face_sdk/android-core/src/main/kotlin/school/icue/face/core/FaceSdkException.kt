package school.icue.face.core

enum class FaceSdkErrorCode {
    CLOSED,
    INVALID_ARGUMENT,
    MODEL_INVALID,
    NO_FACE,
    MULTIPLE_FACES,
    /** A face was found but is unusable for enrollment (eyes not visible, or turned away). */
    POOR_FACE,
}

class FaceSdkException(
    val code: FaceSdkErrorCode,
    message: String,
    cause: Throwable? = null,
) : IllegalStateException(message, cause)
