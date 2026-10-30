package school.icue.face.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Rect
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
import school.icue.face.core.recognition.MobileFaceNetRecognizer
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

        val faceBitmap = cropFace(bitmap, faces.first())
        return try {
            recognizer.extractEmbedding(faceBitmap)
        } finally {
            if (faceBitmap !== bitmap) faceBitmap.recycle()
        }
    }

    private suspend fun recognizeInternal(
        bitmap: Bitmap,
        profiles: List<PreparedProfile>,
        mode: RecognitionMode,
        maxFaces: Int,
        threshold: Float,
    ): List<IcueRecognitionResult> {
        validateRecognitionOptions(maxFaces, threshold)
        val allFaces = detector.detect(bitmap, requireLandmarks = true)
        val faces = allFaces.filter { it.boundingBox.width() >= 30 && it.boundingBox.height() >= 30 }
            .ifEmpty { allFaces }
            .take(maxFaces)

        if (mode == RecognitionMode.SINGLE && allFaces.size != 1) {
            val code = if (allFaces.isEmpty()) FaceSdkErrorCode.NO_FACE else FaceSdkErrorCode.MULTIPLE_FACES
            throw FaceSdkException(code, "Expected exactly one face. Found ${allFaces.size}")
        }

        if (faces.isEmpty()) return emptyList()

        val liveEmbeddings = faces.map { face ->
            val faceBitmap = cropFace(bitmap, face)
            try {
                recognizer.extractEmbedding(faceBitmap)
            } finally {
                if (faceBitmap !== bitmap) faceBitmap.recycle()
            }
        }

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

        data class CandidateMatch(val faceIdx: Int, val profileIdx: Int, val score: Float)
        val candidates = mutableListOf<CandidateMatch>()

        for (fIdx in faces.indices) {
            val liveEmb = liveEmbeddings[fIdx]
            for (pIdx in profiles.indices) {
                val score = EmbeddingMath.dotProductOfNormalized(liveEmb, profiles[pIdx].embedding)
                candidates.add(CandidateMatch(fIdx, pIdx, score))
            }
        }

        candidates.sortByDescending { it.score }

        val assignedFace = BooleanArray(faces.size)
        val assignedProfile = BooleanArray(profiles.size)
        val faceResults = Array<IcueRecognitionResult?>(faces.size) { null }

        for (candidate in candidates) {
            if (assignedFace[candidate.faceIdx] || assignedProfile[candidate.profileIdx]) continue
            if (candidate.score >= threshold) {
                assignedFace[candidate.faceIdx] = true
                assignedProfile[candidate.profileIdx] = true
                val matchedProfile = profiles[candidate.profileIdx]
                faceResults[candidate.faceIdx] = IcueRecognitionResult(
                    personId = matchedProfile.personId,
                    score = candidate.score,
                    matched = true,
                    boundingBox = faces[candidate.faceIdx].toBoundingBox(),
                )
            }
        }

        for (fIdx in faces.indices) {
            if (faceResults[fIdx] == null) {
                var bestScore = -1f
                for (pIdx in profiles.indices) {
                    val score = EmbeddingMath.dotProductOfNormalized(liveEmbeddings[fIdx], profiles[pIdx].embedding)
                    if (score > bestScore) bestScore = score
                }
                faceResults[fIdx] = IcueRecognitionResult(
                    personId = null,
                    score = bestScore,
                    matched = false,
                    boundingBox = faces[fIdx].toBoundingBox(),
                )
            }
        }

        return faceResults.filterNotNull()
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

    private fun cropFace(bitmap: Bitmap, face: Face): Bitmap {
        val leftEye = face.getLandmark(FaceLandmark.LEFT_EYE)?.position
        val rightEye = face.getLandmark(FaceLandmark.RIGHT_EYE)?.position
        if (leftEye != null && rightEye != null) {
            FaceAlignment.alignToCanonicalEyes(
                bitmap,
                leftEye.x,
                leftEye.y,
                rightEye.x,
                rightEye.y,
            )?.let { return it }
        }
        return cropBoxFace(bitmap, face.boundingBox)
    }

    private fun cropBoxFace(bitmap: Bitmap, boundingBox: Rect): Bitmap {
        val marginX = (boundingBox.width() * 0.25f).toInt()
        val marginY = (boundingBox.height() * 0.25f).toInt()
        val left = (boundingBox.left - marginX).coerceIn(0, bitmap.width - 1)
        val top = (boundingBox.top - marginY).coerceIn(0, bitmap.height - 1)
        val right = (boundingBox.right + marginX).coerceIn(left + 1, bitmap.width)
        val bottom = (boundingBox.bottom + marginY).coerceIn(top + 1, bitmap.height)
        return Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
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
    }
}
