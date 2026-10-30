package school.icue.face.core

import school.icue.face.core.model.FaceSdkAccelerator

data class FaceSdkConfig(
    val accelerator: FaceSdkAccelerator = FaceSdkAccelerator.CPU,
    val numThreads: Int = FaceSdkDefaults.defaultThreadCount(),
) {
    init {
        require(numThreads in 1..8) { "numThreads must be between 1 and 8" }
    }
}
