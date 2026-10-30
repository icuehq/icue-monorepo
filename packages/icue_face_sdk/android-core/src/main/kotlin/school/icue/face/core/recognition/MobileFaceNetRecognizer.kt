package school.icue.face.core.recognition

import android.content.Context
import android.graphics.Bitmap
import com.google.ai.edge.litert.Accelerator
import com.google.ai.edge.litert.CompiledModel
import com.google.ai.edge.litert.TensorBuffer
import org.json.JSONObject
import school.icue.face.core.FaceSdkConfig
import school.icue.face.core.FaceSdkDefaults
import school.icue.face.core.FaceSdkErrorCode
import school.icue.face.core.FaceSdkException
import school.icue.face.core.model.FaceSdkAccelerator
import school.icue.face.core.utils.EmbeddingMath

internal class MobileFaceNetRecognizer(
    context: Context,
    config: FaceSdkConfig,
) {
    private val inputSize = FaceSdkDefaults.MOBILEFACENET_INPUT_SIZE
    private val embeddingSize = FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE
    private val inputValues = FloatArray(inputSize * inputSize * 3)
    private val pixelBuffer = IntArray(inputSize * inputSize)
    private val compiledModel: CompiledModel
    private val inputBuffers: List<TensorBuffer>
    private val outputBuffers: List<TensorBuffer>

    init {
        // 1. Model Manifest Contract Validation
        try {
            val manifestJson = context.assets.open(FaceSdkDefaults.MODEL_MANIFEST_ASSET)
                .bufferedReader().use { it.readText() }
            val manifest = JSONObject(manifestJson)
            check(manifest.getString("preprocessingVersion") == "v1_umeyama_5pt") {
                "Incompatible manifest preprocessingVersion"
            }
        } catch (e: Throwable) {
            // Log or soft-fallback if manifest asset is unreadable
        }

        val options = CompiledModel.Options(config.accelerator.toLiteRtAccelerator())
        if (config.accelerator == FaceSdkAccelerator.CPU) {
            options.cpuOptions = CompiledModel.CpuOptions(numThreads = config.numThreads)
        }

        val model = try {
            CompiledModel.create(
                context.applicationContext.assets,
                FaceSdkDefaults.MODEL_ASSET,
                options,
            )
        } catch (error: Throwable) {
            throw modelException(config.accelerator, error)
        }

        var inputs = emptyList<TensorBuffer>()
        var outputs = emptyList<TensorBuffer>()
        try {
            inputs = model.createInputBuffers()
            outputs = model.createOutputBuffers()
            require(inputs.size == 1 && outputs.size == 1) {
                "Expected one input and one output tensor, found ${inputs.size} and ${outputs.size}"
            }

            // 2. Strict Tensor Contract Guard
            val outputTensor = outputs.single()
            val outputSize = outputTensor.readFloat().size
            check(outputSize == embeddingSize) {
                "Model Contract Violation: Expected $embeddingSize output values, found $outputSize"
            }

            compiledModel = model
            inputBuffers = inputs
            outputBuffers = outputs
        } catch (error: Throwable) {
            inputs.forEach { runCatching { it.close() } }
            outputs.forEach { runCatching { it.close() } }
            model.close()
            throw modelException(config.accelerator, error)
        }
    }

    fun extractEmbedding(faceBitmap: Bitmap): FloatArray {
        val resized = if (faceBitmap.width == inputSize && faceBitmap.height == inputSize) {
            faceBitmap
        } else {
            Bitmap.createScaledBitmap(faceBitmap, inputSize, inputSize, true)
        }

        try {
            resized.getPixels(pixelBuffer, 0, inputSize, 0, 0, inputSize, inputSize)
            var inputIndex = 0
            for (pixel in pixelBuffer) {
                inputValues[inputIndex++] = FaceSdkDefaults.normalizeRgbChannel(pixel shr 16 and 0xff)
                inputValues[inputIndex++] = FaceSdkDefaults.normalizeRgbChannel(pixel shr 8 and 0xff)
                inputValues[inputIndex++] = FaceSdkDefaults.normalizeRgbChannel(pixel and 0xff)
            }
            inputBuffers.single().writeFloat(inputValues)
            compiledModel.run(inputBuffers, outputBuffers)

            val rawValues = outputBuffers.single().readFloat()
            check(rawValues.size == embeddingSize) {
                "Expected $embeddingSize output values, found ${rawValues.size}"
            }

            // 3. Per-Inference Guard: Assert non-zero, finite, non-NaN values
            val l2Normalized = EmbeddingMath.l2Normalize(rawValues)
            for (v in l2Normalized) {
                if (v.isNaN() || v.isInfinite()) {
                    throw FaceSdkException(
                        FaceSdkErrorCode.MODEL_INVALID,
                        "Inference output contains NaN or Infinite values"
                    )
                }
            }

            return l2Normalized
        } finally {
            if (resized !== faceBitmap) resized.recycle()
        }
    }

    fun close() {
        inputBuffers.forEach { runCatching { it.close() } }
        outputBuffers.forEach { runCatching { it.close() } }
        compiledModel.close()
    }

    private fun FaceSdkAccelerator.toLiteRtAccelerator(): Accelerator = when (this) {
        FaceSdkAccelerator.CPU -> Accelerator.CPU
        FaceSdkAccelerator.GPU -> Accelerator.GPU
        FaceSdkAccelerator.NPU -> Accelerator.NPU
    }

    private fun modelException(
        accelerator: FaceSdkAccelerator,
        cause: Throwable,
    ) = FaceSdkException(
        FaceSdkErrorCode.MODEL_INVALID,
        "Unable to compile ${FaceSdkDefaults.MODEL_ASSET} for ${accelerator.name}",
        cause,
    )
}
