package school.icue.face.core

import android.content.Context
import android.graphics.Bitmap
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceLandmark
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import school.icue.face.core.detector.IcueFaceDetector
import school.icue.face.core.image.YuvFrameConverter
import school.icue.face.core.model.IcueBoundingBox
import school.icue.face.core.model.IcueFaceProfile
import school.icue.face.core.model.IcueRecognitionResult
import school.icue.face.core.model.IcueYuv420Frame
import school.icue.face.core.model.RecognitionMode
import school.icue.face.core.quality.FaceQualityStatus
import school.icue.face.core.quality.IcueFaceQualityAssessor
import school.icue.face.core.recognition.FaceAssignment
import school.icue.face.core.recognition.MobileFaceNetRecognizer
import school.icue.face.core.recognition.TrackedIdentityCache
import school.icue.face.core.utils.EmbeddingMath

class IcueFaceSdk(
    context: Context,
    config: FaceSdkConfig = FaceSdkConfig(),
) {
    private val operationMutex = Mutex()
    private val detector = IcueFaceDetector()
    private val recognizer = MobileFaceNetRecognizer(context.applicationContext, config)
    private val frameConverter = YuvFrameConverter()

    @Volatile
    private var closed = false

    val isClosed: Boolean
        get() = closed

    suspend fun extractEmbedding(bitmap: Bitmap): FloatArray = operation {
        extractEmbeddingInternal(bitmap)
    }

    suspend fun recognize(
        bitmap: Bitmap,
        profiles: List<IcueFaceProfile>,
        mode: RecognitionMode = RecognitionMode.SINGLE,
        maxFaces: Int = FaceSdkDefaults.DEFAULT_MAX_FACES,
        threshold: Float = FaceSdkDefaults.DEFAULT_MATCH_THRESHOLD,
    ): List<IcueRecognitionResult> = operation {
        recognizeInternal(bitmap, prepareProfiles(profiles), mode, maxFaces, threshold)
    }

    /** Live multi-face recognition that reuses identities of faces still being tracked. */
    internal suspend fun recognizeTracked(
        bitmap: Bitmap,
        profiles: List<IcueFaceProfile>,
        maxFaces: Int,
        threshold: Float,
        cache: TrackedIdentityCache,
    ): List<IcueRecognitionResult> = operation {
        recognizeInternal(bitmap, prepareProfiles(profiles), RecognitionMode.MULTI, maxFaces, threshold, cache)
    }

    suspend fun detectFaces(bitmap: Bitmap): List<IcueBoundingBox> = operation {
        detectFacesInternal(bitmap)
    }

    suspend fun extractEmbeddingFromNv21(
        bytes: ByteArray,
        width: Int,
        height: Int,
        rotationDegrees: Int = 0,
        mirrorHorizontally: Boolean = false,
    ): FloatArray = operation {
        withConvertedBitmap(
            frameConverter.nv21ToBitmap(bytes, width, height, rotationDegrees, mirrorHorizontally),
            ::extractEmbeddingInternal,
        )
    }

    suspend fun recognizeNv21(
        bytes: ByteArray,
        width: Int,
        height: Int,
        profiles: List<IcueFaceProfile>,
        rotationDegrees: Int = 0,
        mirrorHorizontally: Boolean = false,
        mode: RecognitionMode = RecognitionMode.SINGLE,
        maxFaces: Int = FaceSdkDefaults.DEFAULT_MAX_FACES,
        threshold: Float = FaceSdkDefaults.DEFAULT_MATCH_THRESHOLD,
    ): List<IcueRecognitionResult> = operation {
        val preparedProfiles = prepareProfiles(profiles)
        withConvertedBitmap(
            frameConverter.nv21ToBitmap(bytes, width, height, rotationDegrees, mirrorHorizontally),
        ) { bitmap ->
            recognizeInternal(bitmap, preparedProfiles, mode, maxFaces, threshold)
        }
    }

    suspend fun detectFacesInNv21(
        bytes: ByteArray,
        width: Int,
        height: Int,
        rotationDegrees: Int = 0,
        mirrorHorizontally: Boolean = false,
    ): List<IcueBoundingBox> = operation {
        withConvertedBitmap(
            frameConverter.nv21ToBitmap(bytes, width, height, rotationDegrees, mirrorHorizontally),
            ::detectFacesInternal,
        )
    }

    suspend fun recognizeYuv420(
        frame: IcueYuv420Frame,
        profiles: List<IcueFaceProfile>,
        mode: RecognitionMode = RecognitionMode.MULTI,
        maxFaces: Int = FaceSdkDefaults.DEFAULT_MAX_FACES,
        threshold: Float = FaceSdkDefaults.DEFAULT_MATCH_THRESHOLD,
    ): List<IcueRecognitionResult> = operation {
        val preparedProfiles = prepareProfiles(profiles)
        withConvertedBitmap(frameConverter.yuv420ToBitmap(frame)) { bitmap ->
            recognizeInternal(bitmap, preparedProfiles, mode, maxFaces, threshold)
        }
    }

    suspend fun detectFacesInYuv420(frame: IcueYuv420Frame): List<IcueBoundingBox> = operation {
        withConvertedBitmap(frameConverter.yuv420ToBitmap(frame), ::detectFacesInternal)
    }

    suspend fun extractEmbeddingFromYuv420(frame: IcueYuv420Frame): FloatArray = operation {
        withConvertedBitmap(frameConverter.yuv420ToBitmap(frame), ::extractEmbeddingInternal)
    }

    fun compareEmbeddings(first: FloatArray, second: FloatArray): Float =
        EmbeddingMath.cosineSimilarity(first, second)

    suspend fun close() {
        operationMutex.withLock {
            if (closed) return
            closed = true
            recognizer.close()
            detector.close()
        }
    }

    private suspend fun extractEmbeddingInternal(bitmap: Bitmap): FloatArray {
        val faces = detector.detect(bitmap, requireLandmarks = true)
        when {
            faces.isEmpty() -> throw FaceSdkException(FaceSdkErrorCode.NO_FACE, "No face detected")
            faces.size > 1 -> throw FaceSdkException(
                FaceSdkErrorCode.MULTIPLE_FACES,
                "Multiple faces detected. Expected exactly one.",
            )
        }

        val face = faces.first()
        // Blur is not checked: server photos are often small and soft but still usable.
        val quality = IcueFaceQualityAssessor.assessQuality(bitmap, face, minBlurThreshold = 0f)
        if (quality.status == FaceQualityStatus.EXTREME_POSE) {
            throw FaceSdkException(FaceSdkErrorCode.POOR_FACE, "Face is turned away. Use a front-facing photo.")
        }
        val faceBitmap = alignFace(bitmap, face)
            ?: throw FaceSdkException(FaceSdkErrorCode.POOR_FACE, "Eyes not clearly visible. Use a clearer front-facing photo.")
        return try {
            recognizer.extractEmbedding(faceBitmap)
        } finally {
            faceBitmap.recycle()
        }
    }

    private suspend fun recognizeInternal(
        bitmap: Bitmap,
        profiles: List<PreparedProfile>,
        mode: RecognitionMode,
        maxFaces: Int,
        threshold: Float,
        cache: TrackedIdentityCache? = null,
    ): List<IcueRecognitionResult> {
        validateRecognitionOptions(maxFaces, threshold)
        val allFaces = detector.detect(bitmap, requireLandmarks = true)
        // Tiny faces upscale into unreliable crops, so they are not recognized at all.
        val faces = allFaces.filter { it.boundingBox.width() >= 30 && it.boundingBox.height() >= 30 }
            .take(maxFaces)

        if (mode == RecognitionMode.SINGLE && allFaces.size != 1) {
            val code = if (allFaces.isEmpty()) FaceSdkErrorCode.NO_FACE else FaceSdkErrorCode.MULTIPLE_FACES
            throw FaceSdkException(code, "Expected exactly one face. Found ${allFaces.size}")
        }

        cache?.startFrame(faces.mapNotNullTo(HashSet()) { it.trackingId })
        if (faces.isEmpty()) return emptyList()

        if (profiles.isEmpty()) {
            return faces.map { face ->
                IcueRecognitionResult(
                    personId = null,
                    score = -1f,
                    matched = false,
                    boundingBox = face.toBoundingBox(),
                )
            }
        }

        // Aligned once per face: the crop feeds both the "same face?" check and the model.
        val alignedFaces = faces.map { alignFace(bitmap, it) }
        try {
            val signatures = alignedFaces.map { aligned -> if (cache == null) null else aligned?.let(::faceSignature) }
            val faceResults = Array(faces.size) { fIdx ->
                cache?.reusable(faces[fIdx].trackingId, signatures[fIdx])?.let { identity ->
                    IcueRecognitionResult(
                        personId = identity.personId,
                        score = identity.score,
                        matched = identity.matched,
                        boundingBox = faces[fIdx].toBoundingBox(),
                        embedding = identity.embedding,
                        reused = true,
                    )
                }
            }
            // A student a tracked face already holds cannot also be matched to a fresh face.
            val claimedPersonIds = faceResults.mapNotNullTo(HashSet()) { result ->
                result?.personId?.takeIf { result.matched }
            }
            val blockedProfiles = profiles.indices.filterTo(HashSet()) { profiles[it].personId in claimedPersonIds }

            val freshFaceIndices = faces.indices.filter { faceResults[it] == null }
            val scoredFaces = freshFaceIndices.mapNotNull { fIdx ->
                alignedFaces[fIdx]?.let { fIdx to recognizer.extractEmbedding(it) }
            }
            val scores = scoredFaces.map { (_, embedding) ->
                FloatArray(profiles.size) { pIdx -> EmbeddingMath.dotProductOfNormalized(embedding, profiles[pIdx].embedding) }
            }
            val assignment = FaceAssignment.assign(
                scores,
                threshold,
                FaceSdkDefaults.DEFAULT_AMBIGUITY_MARGIN,
                blockedProfiles,
            )

            scoredFaces.forEachIndexed { row, (fIdx, embedding) ->
                val profileIdx = assignment[row]
                faceResults[fIdx] = IcueRecognitionResult(
                    personId = profiles.getOrNull(profileIdx)?.personId,
                    score = if (profileIdx >= 0) scores[row][profileIdx] else scores[row].maxOrNull() ?: -1f,
                    matched = profileIdx >= 0,
                    boundingBox = faces[fIdx].toBoundingBox(),
                    embedding = embedding,
                )
            }
            // Faces whose eyes were not found: shown, never matched, re-checked like any unmatched face.
            for (fIdx in freshFaceIndices) {
                val result = faceResults[fIdx] ?: IcueRecognitionResult(
                    personId = null,
                    score = -1f,
                    matched = false,
                    boundingBox = faces[fIdx].toBoundingBox(),
                ).also { faceResults[fIdx] = it }
                cache?.store(
                    faces[fIdx].trackingId,
                    TrackedIdentityCache.Identity(
                        result.personId,
                        result.score,
                        result.matched,
                        result.embedding,
                        signatures[fIdx],
                    ),
                )
            }

            return faceResults.filterNotNull()
        } finally {
            alignedFaces.forEach { it?.recycle() }
        }
    }

    /** A 16x16 grayscale fingerprint of an aligned face; cheap next to running the model. */
    private fun faceSignature(aligned: Bitmap): FloatArray {
        val small = Bitmap.createScaledBitmap(aligned, SIGNATURE_SIZE, SIGNATURE_SIZE, true)
        val pixels = IntArray(SIGNATURE_SIZE * SIGNATURE_SIZE)
        small.getPixels(pixels, 0, SIGNATURE_SIZE, 0, 0, SIGNATURE_SIZE, SIGNATURE_SIZE)
        if (small !== aligned) small.recycle()
        return TrackedIdentityCache.signatureOf(
            FloatArray(pixels.size) { index ->
                val pixel = pixels[index]
                0.299f * (pixel shr 16 and 0xff) + 0.587f * (pixel shr 8 and 0xff) + 0.114f * (pixel and 0xff)
            },
        )
    }

    private suspend fun detectFacesInternal(bitmap: Bitmap): List<IcueBoundingBox> =
        detector.detect(bitmap, requireLandmarks = false).map { it.toBoundingBox() }

    private fun prepareProfiles(profiles: List<IcueFaceProfile>): List<PreparedProfile> =
        profiles.map { profile ->
            require(profile.personId.isNotBlank()) { "personId cannot be blank" }
            EmbeddingMath.validateEmbedding(profile.embedding)
            PreparedProfile(profile.personId, EmbeddingMath.l2Normalize(profile.embedding))
        }

    private fun validateRecognitionOptions(maxFaces: Int, threshold: Float) {
        require(maxFaces > 0) { "maxFaces must be greater than zero" }
        require(threshold.isFinite() && threshold in -1f..1f) {
            "threshold must be finite and between -1 and 1"
        }
    }

    /** The 112x112 eye-aligned face, or null when ML Kit found no eyes. */
    private fun alignFace(bitmap: Bitmap, face: Face): Bitmap? {
        val leftEye = face.getLandmark(FaceLandmark.LEFT_EYE)?.position ?: return null
        val rightEye = face.getLandmark(FaceLandmark.RIGHT_EYE)?.position ?: return null
        return FaceAlignment.alignToCanonicalEyes(bitmap, leftEye.x, leftEye.y, rightEye.x, rightEye.y)
    }

    private suspend fun <T> operation(block: suspend () -> T): T = withContext(Dispatchers.Default) {
        operationMutex.withLock {
            if (closed) throw FaceSdkException(FaceSdkErrorCode.CLOSED, "SDK is closed")
            block()
        }
    }

    private suspend fun <T> withConvertedBitmap(bitmap: Bitmap, block: suspend (Bitmap) -> T): T =
        try {
            block(bitmap)
        } finally {
            // Bitmap is left for Android's NativeAllocationRegistry (GC) to reclaim safely once MLKit
            // background tasks (MlKitThreadPool) complete. Explicitly calling bitmap.recycle() here causes
            // native SIGABRT crashes ('Error, cannot access an invalid/free'd bitmap here!') if the coroutine
            // is cancelled (e.g. closing camera) while MLKit is actively processing the frame.
        }

    private fun Face.toBoundingBox() = IcueBoundingBox(
        left = boundingBox.left.toFloat(),
        top = boundingBox.top.toFloat(),
        right = boundingBox.right.toFloat(),
        bottom = boundingBox.bottom.toFloat(),
        trackingId = trackingId,
    )

    private data class PreparedProfile(
        val personId: String,
        val embedding: FloatArray,
    )

    companion object {
        const val SDK_VERSION = "0.2.0"
        private const val SIGNATURE_SIZE = 16
    }
}
