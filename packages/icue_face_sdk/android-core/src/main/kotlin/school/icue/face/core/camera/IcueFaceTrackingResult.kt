package school.icue.face.core.camera

import school.icue.face.core.model.IcueBoundingBox
import school.icue.face.core.model.IcueRecognitionResult

data class IcueFaceTrackingResult(
    val faces: List<IcueBoundingBox>,
    val recognitions: List<IcueRecognitionResult> = emptyList(),
    val frameWidth: Int,
    val frameHeight: Int,
    val timestampMillis: Long,
)
