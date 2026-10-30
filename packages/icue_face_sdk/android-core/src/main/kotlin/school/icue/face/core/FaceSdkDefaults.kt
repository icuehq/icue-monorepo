package school.icue.face.core

object FaceSdkDefaults {
    const val MODEL_ASSET = "mobilefacenet.tflite"
    const val MODEL_MANIFEST_ASSET = "model_manifest.json"
    const val MOBILEFACENET_INPUT_SIZE = 112
    const val MOBILEFACENET_EMBEDDING_SIZE = 192
    const val DEFAULT_MATCH_THRESHOLD = 0.68f
    const val DEFAULT_AMBIGUITY_MARGIN = 0.05f
    const val DEFAULT_MAX_FACES = 20

    // ArcFace 5-Point Canonical Landmarks
    const val CANONICAL_LEFT_EYE_X = 38.2946f
    const val CANONICAL_LEFT_EYE_Y = 51.6963f
    const val CANONICAL_RIGHT_EYE_X = 73.5318f
    const val CANONICAL_RIGHT_EYE_Y = 51.5014f
    const val CANONICAL_NOSE_X = 56.0252f
    const val CANONICAL_NOSE_Y = 71.7366f
    const val CANONICAL_LEFT_MOUTH_X = 41.5493f
    const val CANONICAL_LEFT_MOUTH_Y = 92.3655f
    const val CANONICAL_RIGHT_MOUTH_X = 70.7299f
    const val CANONICAL_RIGHT_MOUTH_Y = 92.2041f

    fun defaultThreadCount(): Int =
        (Runtime.getRuntime().availableProcessors() - 1).coerceIn(1, 4)

    fun normalizeRgbChannel(value: Int): Float = (value - 127.5f) / 128.0f
}
