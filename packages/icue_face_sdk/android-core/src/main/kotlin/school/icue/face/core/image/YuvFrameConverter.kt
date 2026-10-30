package school.icue.face.core.image

import android.graphics.Bitmap
import android.graphics.Matrix
import school.icue.face.core.model.IcueYuv420Frame

internal class YuvFrameConverter {
    private var argbBuffer = IntArray(0)

    fun nv21ToBitmap(
        bytes: ByteArray,
        width: Int,
        height: Int,
        rotationDegrees: Int,
        mirrorHorizontally: Boolean,
    ): Bitmap {
        validateDimensions(width, height, rotationDegrees)
        require(width % 2 == 0 && height % 2 == 0) { "NV21 dimensions must be even" }
        val expectedSize = width * height * 3 / 2
        require(bytes.size >= expectedSize) {
            "NV21 buffer is too small. expected=$expectedSize, actual=${bytes.size}"
        }

        ensureArgbCapacity(width * height)
        val frameSize = width * height
        for (row in 0 until height) {
            val chromaRow = frameSize + (row shr 1) * width
            for (column in 0 until width) {
                val chromaOffset = chromaRow + (column and -2)
                val v = (bytes[chromaOffset].toInt() and 0xff) - 128
                val u = (bytes[chromaOffset + 1].toInt() and 0xff) - 128
                argbBuffer[row * width + column] = yuvToArgb(
                    bytes[row * width + column].toInt() and 0xff,
                    u,
                    v,
                )
            }
        }
        return transform(createBitmap(width, height), rotationDegrees, mirrorHorizontally)
    }

    fun yuv420ToBitmap(frame: IcueYuv420Frame): Bitmap {
        validateDimensions(frame.width, frame.height, frame.rotationDegrees)
        validateFrame(frame)
        ensureArgbCapacity(frame.width * frame.height)

        for (row in 0 until frame.height) {
            val yRow = row * frame.yRowStride
            val uRow = (row shr 1) * frame.uRowStride
            val vRow = (row shr 1) * frame.vRowStride
            for (column in 0 until frame.width) {
                val y = frame.yBytes[yRow + column].toInt() and 0xff
                val chromaColumn = column shr 1
                val u = (frame.uBytes[uRow + chromaColumn * frame.uPixelStride].toInt() and 0xff) - 128
                val v = (frame.vBytes[vRow + chromaColumn * frame.vPixelStride].toInt() and 0xff) - 128
                argbBuffer[row * frame.width + column] = yuvToArgb(y, u, v)
            }
        }

        return transform(
            createBitmap(frame.width, frame.height),
            frame.rotationDegrees,
            frame.mirrorHorizontally,
        )
    }

    private fun createBitmap(width: Int, height: Int): Bitmap =
        Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
            it.setPixels(argbBuffer, 0, width, 0, 0, width, height)
        }

    private fun transform(source: Bitmap, rotationDegrees: Int, mirrorHorizontally: Boolean): Bitmap {
        if (rotationDegrees == 0 && !mirrorHorizontally) return source
        val matrix = Matrix().apply {
            postRotate(rotationDegrees.toFloat())
            if (mirrorHorizontally) postScale(-1f, 1f)
        }
        return Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true).also {
            if (it !== source) source.recycle()
        }
    }

    private fun ensureArgbCapacity(size: Int) {
        if (argbBuffer.size < size) argbBuffer = IntArray(size)
    }

    private fun validateDimensions(width: Int, height: Int, rotationDegrees: Int) {
        require(width > 0 && height > 0) { "Frame dimensions must be positive" }
        require(rotationDegrees in setOf(0, 90, 180, 270)) {
            "rotationDegrees must be 0, 90, 180, or 270"
        }
    }

    private fun validateFrame(frame: IcueYuv420Frame) {
        require(frame.yRowStride >= frame.width) { "yRowStride must be at least width" }
        require(frame.uPixelStride > 0 && frame.vPixelStride > 0) { "Pixel strides must be positive" }
        val chromaWidth = (frame.width + 1) / 2
        val chromaHeight = (frame.height + 1) / 2
        require(frame.uRowStride >= (chromaWidth - 1) * frame.uPixelStride + 1) {
            "uRowStride is too small"
        }
        require(frame.vRowStride >= (chromaWidth - 1) * frame.vPixelStride + 1) {
            "vRowStride is too small"
        }
        val requiredY = (frame.height - 1) * frame.yRowStride + frame.width
        val requiredU = (chromaHeight - 1) * frame.uRowStride + (chromaWidth - 1) * frame.uPixelStride + 1
        val requiredV = (chromaHeight - 1) * frame.vRowStride + (chromaWidth - 1) * frame.vPixelStride + 1
        require(frame.yBytes.size >= requiredY) { "Y plane is too small" }
        require(frame.uBytes.size >= requiredU) { "U plane is too small" }
        require(frame.vBytes.size >= requiredV) { "V plane is too small" }
    }

    private fun yuvToArgb(yValue: Int, u: Int, v: Int): Int {
        val y = (yValue - 16).coerceAtLeast(0)
        val y1192 = 1192 * y
        val red = (y1192 + 1634 * v).coerceIn(0, 262143)
        val green = (y1192 - 833 * v - 400 * u).coerceIn(0, 262143)
        val blue = (y1192 + 2066 * u).coerceIn(0, 262143)
        return -0x1000000 or
            ((red shl 6) and 0x00ff0000) or
            ((green shr 2) and 0x0000ff00) or
            ((blue shr 10) and 0x000000ff)
    }
}
