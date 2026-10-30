package school.icue.face.core

enum class FaceSdkErrorCode {
    CLOSED,
    INVALID_ARGUMENT,
    MODEL_INVALID,
    NO_FACE,
    MULTIPLE_FACES,
}

class FaceSdkException(
    val code: FaceSdkErrorCode,
    message: String,
    cause: Throwable? = null,
) : IllegalStateException(message, cause)
