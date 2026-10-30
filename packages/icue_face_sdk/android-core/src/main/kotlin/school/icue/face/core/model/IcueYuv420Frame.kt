package school.icue.face.core.model

data class IcueYuv420Frame(
    val yBytes: ByteArray,
    val uBytes: ByteArray,
    val vBytes: ByteArray,
    val width: Int,
    val height: Int,
    val yRowStride: Int,
    val uRowStride: Int,
    val vRowStride: Int,
    val uPixelStride: Int,
    val vPixelStride: Int,
    val rotationDegrees: Int = 0,
    val mirrorHorizontally: Boolean = false,
)
