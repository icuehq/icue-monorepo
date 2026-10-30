package school.icue.face.core.detector

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlinx.coroutines.tasks.await

internal class IcueFaceDetector {
    private val landmarkDetector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
            .setMinFaceSize(0.05f)
            .enableTracking()
            .build(),
    )

    private val boundingBoxDetector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
            .setMinFaceSize(0.05f)
            .enableTracking()
            .build(),
    )

    suspend fun detect(bitmap: Bitmap, requireLandmarks: Boolean): List<Face> {
        if (bitmap.isRecycled) return emptyList()
        val detector = if (requireLandmarks) landmarkDetector else boundingBoxDetector
        return detector.process(InputImage.fromBitmap(bitmap, 0)).await()
    }

    fun close() {
        landmarkDetector.close()
        boundingBoxDetector.close()
    }
}
