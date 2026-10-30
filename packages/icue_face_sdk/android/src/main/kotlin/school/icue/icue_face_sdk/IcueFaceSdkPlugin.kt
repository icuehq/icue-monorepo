package school.icue.icue_face_sdk

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import school.icue.face.core.FaceSdkConfig
import school.icue.face.core.FaceSdkDefaults
import school.icue.face.core.FaceSdkException
import school.icue.face.core.IcueFaceSdk
import school.icue.face.core.camera.IcueCameraLens
import school.icue.face.core.camera.IcueFaceCamera
import school.icue.face.core.camera.IcueFaceTrackingResult
import school.icue.face.core.model.FaceSdkAccelerator
import school.icue.face.core.model.IcueBoundingBox
import school.icue.face.core.model.IcueFaceProfile
import school.icue.face.core.model.IcueRecognitionResult
import school.icue.face.core.model.IcueYuv420Frame
import school.icue.face.core.model.RecognitionMode

class IcueFaceSdkPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var trackingEventChannel: EventChannel
    private lateinit var scope: CoroutineScope
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var trackingEventSink: EventChannel.EventSink? = null
    private var sdk: IcueFaceSdk? = null
    private val lifecycleMutex = Mutex()
    private val frameInFlight = AtomicBoolean(false)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        scope = newScope()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        trackingEventChannel = EventChannel(binding.binaryMessenger, TRACKING_CHANNEL_NAME)
        trackingEventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> initialize(call, result)
                "getInfo" -> getInfo(result)
                "extractEmbedding" -> extractEmbedding(call, result)
                "recognize" -> recognize(call, result)
                "compareEmbeddings" -> compareEmbeddings(call, result)
                "detectFaces" -> detectFaces(call, result)
                "extractEmbeddingFromNv21" -> extractEmbeddingFromNv21(call, result)
                "detectFacesInFrame" -> detectFacesInFrame(call, result)
                "recognizeInFrame" -> recognizeInFrame(call, result)
                "detectFacesInYuvFrame" -> detectFacesInYuvFrame(call, result)
                "recognizeInYuvFrame" -> recognizeInYuvFrame(call, result)
                "captureEmbeddingWithCamera" -> captureEmbeddingWithCamera(call, result)
                "startFaceTracking" -> startFaceTracking(call, result)
                "stopFaceTracking" -> stopFaceTracking(result)
                "startLiveAttendance" -> startLiveAttendance(call, result)
                "startMultiPhotoAttendance" -> startMultiPhotoAttendance(call, result)
                "processAttendanceFromImages" -> processAttendanceFromImages(call, result)
                "dispose" -> dispose(result)
                else -> result.notImplemented()
            }
        } catch (error: IllegalArgumentException) {
            result.error("INVALID_ARGUMENT", error.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        trackingEventChannel.setStreamHandler(null)
        val sdkToClose = sdk
        sdk = null
        applicationContext = null
        activity = null
        trackingEventSink = null
        IcueFaceCamera.stop()
        scope.cancel()
        frameInFlight.set(false)
        if (sdkToClose != null) {
            CoroutineScope(SupervisorJob() + Dispatchers.Default).launch {
                sdkToClose.close()
            }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
        IcueFaceCamera.stop()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        trackingEventSink = events
    }

    override fun onCancel(arguments: Any?) {
        trackingEventSink = null
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val context = applicationContext
            ?: return result.error("UNINITIALIZED", "Plugin is detached", null)
        val configuredThreads = call.argument<Int>("numThreads")
        val accelerator = when (call.argument<String>("accelerator") ?: "cpu") {
            "cpu" -> FaceSdkAccelerator.CPU
            "gpu" -> FaceSdkAccelerator.GPU
            "npu" -> FaceSdkAccelerator.NPU
            else -> throw IllegalArgumentException("accelerator must be cpu, gpu, or npu")
        }
        val config = FaceSdkConfig(
            accelerator = accelerator,
            numThreads = configuredThreads ?: FaceSdkDefaults.defaultThreadCount(),
        )
        scope.launch {
            try {
                lifecycleMutex.withLock {
                    if (sdk == null) {
                        sdk = withContext(Dispatchers.Default) { IcueFaceSdk(context, config) }
                    }
                }
                result.success(null)
            } catch (error: Throwable) {
                sendError(result, error, "INIT_FAILED")
            }
        }
    }

    private fun getInfo(result: MethodChannel.Result) {
        if (sdk == null) return result.error("NOT_INITIALIZED", "SDK is not initialized", null)
        result.success(
            mapOf(
                "sdkVersion" to IcueFaceSdk.SDK_VERSION,
                "modelName" to FaceSdkDefaults.MODEL_ASSET,
                "embeddingSize" to FaceSdkDefaults.MOBILEFACENET_EMBEDDING_SIZE,
            ),
        )
    }

    private fun extractEmbedding(call: MethodCall, result: MethodChannel.Result) {
        val imagePath = call.required<String>("imagePath")
        val mirror = call.argument<Boolean>("isFrontCamera") ?: false
        launchSdkCall(result) { currentSdk ->
            withBitmap(imagePath, mirror) { currentSdk.extractEmbedding(it) }
        }
    }

    private fun recognize(call: MethodCall, result: MethodChannel.Result) {
        val imagePath = call.required<String>("imagePath")
        val profiles = call.profiles()
        val options = call.recognitionOptions(RecognitionMode.SINGLE)
        val mirror = call.argument<Boolean>("isFrontCamera") ?: false
        launchSdkCall(result) { currentSdk ->
            withBitmap(imagePath, mirror) { bitmap ->
                currentSdk.recognize(
                    bitmap,
                    profiles,
                    options.mode,
                    options.maxFaces,
                    options.threshold,
                ).toRecognitionChannelValue()
            }
        }
    }

    private fun compareEmbeddings(call: MethodCall, result: MethodChannel.Result) {
        val first = call.floatArray("first")
        val second = call.floatArray("second")
        launchSdkCall(result) { currentSdk ->
            withContext(Dispatchers.Default) { currentSdk.compareEmbeddings(first, second) }
        }
    }

    private fun detectFaces(call: MethodCall, result: MethodChannel.Result) {
        val imagePath = call.required<String>("imagePath")
        val mirror = call.argument<Boolean>("isFrontCamera") ?: false
        launchSdkCall(result) { currentSdk ->
            withBitmap(imagePath, mirror) { currentSdk.detectFaces(it).toBoundingBoxChannelValue() }
        }
    }

    private fun extractEmbeddingFromNv21(call: MethodCall, result: MethodChannel.Result) {
        val frame = call.nv21Frame()
        launchSdkCall(result, isFrame = true) { currentSdk ->
            currentSdk.extractEmbeddingFromNv21(
                frame.bytes,
                frame.width,
                frame.height,
                frame.rotation,
                frame.mirrorHorizontally,
            )
        }
    }

    private fun detectFacesInFrame(call: MethodCall, result: MethodChannel.Result) {
        val frame = call.nv21Frame()
        launchSdkCall(result, isFrame = true) { currentSdk ->
            currentSdk.detectFacesInNv21(
                frame.bytes,
                frame.width,
                frame.height,
                frame.rotation,
                frame.mirrorHorizontally,
            ).toBoundingBoxChannelValue()
        }
    }

    private fun recognizeInFrame(call: MethodCall, result: MethodChannel.Result) {
        val frame = call.nv21Frame()
        val profiles = call.profiles()
        val options = call.recognitionOptions(RecognitionMode.SINGLE)
        launchSdkCall(result, isFrame = true) { currentSdk ->
            currentSdk.recognizeNv21(
                frame.bytes,
                frame.width,
                frame.height,
                profiles,
                frame.rotation,
                frame.mirrorHorizontally,
                options.mode,
                options.maxFaces,
                options.threshold,
            ).toRecognitionChannelValue()
        }
    }

    private fun detectFacesInYuvFrame(call: MethodCall, result: MethodChannel.Result) {
        val frame = call.yuv420Frame()
        launchSdkCall(result, isFrame = true) { currentSdk ->
            currentSdk.detectFacesInYuv420(frame).toBoundingBoxChannelValue()
        }
    }

    private fun recognizeInYuvFrame(call: MethodCall, result: MethodChannel.Result) {
        val frame = call.yuv420Frame()
        val profiles = call.profiles()
        val options = call.recognitionOptions(RecognitionMode.MULTI)
        launchSdkCall(result, isFrame = true) { currentSdk ->
            currentSdk.recognizeYuv420(
                frame,
                profiles,
                options.mode,
                options.maxFaces,
                options.threshold,
            ).toRecognitionChannelValue()
        }
    }

    private fun captureEmbeddingWithCamera(call: MethodCall, result: MethodChannel.Result) {
        val hostActivity = activity
            ?: return result.error("NO_ACTIVITY", "A foreground Android activity is required", null)
        val currentSdk = sdk
            ?: return result.error("NOT_INITIALIZED", "SDK is not initialized", null)
        if (currentSdk.isClosed) {
            return result.error("CLOSED", "SDK is closed", null)
        }
        try {
            IcueFaceCamera.openCapture(
                hostActivity,
                currentSdk,
                call.cameraLens(),
                object : IcueFaceCamera.CaptureCallback {
                    override fun onCaptured(embedding: FloatArray) {
                        result.success(embedding)
                    }

                    override fun onCancelled() {
                        result.success(null)
                    }

                    override fun onError(code: String, message: String) {
                        result.error(code, message, null)
                    }
                },
            )
        } catch (error: IllegalStateException) {
            result.error("CAMERA_BUSY", error.message, null)
        }
    }

    private fun startFaceTracking(call: MethodCall, result: MethodChannel.Result) {
        val hostActivity = activity
            ?: return result.error("NO_ACTIVITY", "A foreground Android activity is required", null)
        val currentSdk = sdk
            ?: return result.error("NOT_INITIALIZED", "SDK is not initialized", null)
        if (currentSdk.isClosed) {
            return result.error("CLOSED", "SDK is closed", null)
        }
        val profiles = call.profiles()
        val options = call.recognitionOptions(RecognitionMode.MULTI)
        val showMatchingPercentage = call.argument<Boolean>("showMatchingPercentage") ?: true
        val showDetectedLabel = call.argument<Boolean>("showDetectedLabel") ?: true
        val showUnrecognizedLabel = call.argument<Boolean>("showUnrecognizedLabel") ?: true
        val unrecognizedLabel = call.argument<String>("unrecognizedLabel") ?: "UNREGISTERED STUDENT"
        val defaultZoom = (call.argument<Number>("defaultZoom") ?: 1.0).toFloat()
        try {
            IcueFaceCamera.startTracking(
                hostActivity,
                currentSdk,
                profiles,
                call.cameraLens(),
                options.maxFaces,
                options.threshold,
                showMatchingPercentage,
                showDetectedLabel,
                showUnrecognizedLabel,
                unrecognizedLabel,
                defaultZoom,
                object : IcueFaceCamera.TrackingListener {
                    override fun onFaces(result: IcueFaceTrackingResult) {
                        trackingEventSink?.success(result.toTrackingChannelValue())
                    }

                    override fun onStopped() {
                        trackingEventSink?.success(mapOf("type" to "stopped"))
                    }

                    override fun onError(code: String, message: String) {
                        trackingEventSink?.error(code, message, null)
                    }
                },
            )
            result.success(null)
        } catch (error: IllegalStateException) {
            result.error("CAMERA_BUSY", error.message, null)
        }
    }

    private fun stopFaceTracking(result: MethodChannel.Result) {
        IcueFaceCamera.stop()
        result.success(null)
    }

    private fun startLiveAttendance(call: MethodCall, result: MethodChannel.Result) {
        val hostActivity = activity
            ?: return result.error("NO_ACTIVITY", "A foreground Android activity is required", null)
        val currentSdk = sdk
            ?: return result.error("NOT_INITIALIZED", "SDK is not initialized", null)
        if (currentSdk.isClosed) {
            return result.error("CLOSED", "SDK is closed", null)
        }
        val roster = call.roster()
        val options = call.recognitionOptions(RecognitionMode.MULTI)
        val autoFinish = call.argument<Boolean>("autoFinish") ?: false
        val showMatchingPercentage = call.argument<Boolean>("showMatchingPercentage") ?: true
        val showDetectedLabel = call.argument<Boolean>("showDetectedLabel") ?: true
        val showUnrecognizedLabel = call.argument<Boolean>("showUnrecognizedLabel") ?: true
        val unrecognizedLabel = call.argument<String>("unrecognizedLabel") ?: "UNREGISTERED STUDENT"
        val defaultZoom = (call.argument<Number>("defaultZoom") ?: 1.0).toFloat()
        try {
            IcueFaceCamera.openLiveAttendance(
                hostActivity,
                currentSdk,
                roster,
                call.cameraLens(),
                options.maxFaces,
                options.threshold,
                autoFinish,
                showMatchingPercentage,
                showDetectedLabel,
                showUnrecognizedLabel,
                unrecognizedLabel,
                defaultZoom,
                object : IcueFaceCamera.AttendanceCallback {
                    override fun onCompleted(resultMap: Map<String, Any?>) {
                        result.success(resultMap)
                    }

                    override fun onCancelled() {
                        result.success(null)
                    }

                    override fun onError(code: String, message: String) {
                        result.error(code, message, null)
                    }
                },
            )
        } catch (error: IllegalStateException) {
            result.error("CAMERA_BUSY", error.message, null)
        }
    }

    private fun startMultiPhotoAttendance(call: MethodCall, result: MethodChannel.Result) {
        val hostActivity = activity
            ?: return result.error("NO_ACTIVITY", "A foreground Android activity is required", null)
        val currentSdk = sdk
            ?: return result.error("NOT_INITIALIZED", "SDK is not initialized", null)
        if (currentSdk.isClosed) {
            return result.error("CLOSED", "SDK is closed", null)
        }
        val roster = call.roster()
        val options = call.recognitionOptions(RecognitionMode.MULTI)
        val autoFinish = call.argument<Boolean>("autoFinish") ?: false
        val showMatchingPercentage = call.argument<Boolean>("showMatchingPercentage") ?: true
        val showDetectedLabel = call.argument<Boolean>("showDetectedLabel") ?: true
        val showUnrecognizedLabel = call.argument<Boolean>("showUnrecognizedLabel") ?: true
        val unrecognizedLabel = call.argument<String>("unrecognizedLabel") ?: "UNREGISTERED STUDENT"
        val defaultZoom = (call.argument<Number>("defaultZoom") ?: 1.0).toFloat()
        try {
            IcueFaceCamera.openMultiPhotoAttendance(
                hostActivity,
                currentSdk,
                roster,
                call.cameraLens(),
                options.maxFaces,
                options.threshold,
                autoFinish,
                showMatchingPercentage,
                showDetectedLabel,
                showUnrecognizedLabel,
                unrecognizedLabel,
                defaultZoom,
                object : IcueFaceCamera.AttendanceCallback {
                    override fun onCompleted(resultMap: Map<String, Any?>) {
                        result.success(resultMap)
                    }

                    override fun onCancelled() {
                        result.success(null)
                    }

                    override fun onError(code: String, message: String) {
                        result.error(code, message, null)
                    }
                },
            )
        } catch (error: IllegalStateException) {
            result.error("CAMERA_BUSY", error.message, null)
        }
    }

    private fun processAttendanceFromImages(call: MethodCall, result: MethodChannel.Result) {
        val imagePaths = call.required<List<String>>("imagePaths")
        val roster = call.roster()
        val threshold = (call.argument<Number>("threshold") ?: FaceSdkDefaults.DEFAULT_MATCH_THRESHOLD).toFloat()
        launchSdkCall(result) { currentSdk ->
            val startTimeMs = System.currentTimeMillis()
            val markedPresentMap = mutableMapOf<String, Map<String, Any?>>()
            var unrecognizedFaceCount = 0

            for (imagePath in imagePaths) {
                val bitmap = withContext(Dispatchers.IO) {
                    loadUprightBitmap(imagePath, false)
                } ?: continue
                try {
                    val recognitions = currentSdk.recognize(
                        bitmap,
                        roster,
                        RecognitionMode.MULTI,
                        FaceSdkDefaults.DEFAULT_MAX_FACES,
                        threshold,
                    )
                    var frameUnrecognized = 0
                    recognitions.forEach { recognition ->
                        if (recognition.matched && recognition.personId != null) {
                            val pId = recognition.personId
                            val existing = markedPresentMap[pId]
                            val existingScore = (existing?.get("score") as? Number)?.toDouble() ?: 0.0
                            if (existing == null || recognition.score > existingScore) {
                                markedPresentMap[pId] = mapOf(
                                    "personId" to pId,
                                    "score" to recognition.score.toDouble(),
                                    "boundingBox" to listOf(recognition.boundingBox).toBoundingBoxChannelValue().first(),
                                    "timestampMillis" to System.currentTimeMillis(),
                                    "sourceImagePath" to imagePath,
                                )
                            }
                        } else {
                            frameUnrecognized++
                        }
                    }
                    unrecognizedFaceCount += frameUnrecognized
                } finally {
                    // Bitmap is left for Android GC (NativeAllocationRegistry) to reclaim safely once MLKit finishes.
                }
            }

            val endTimeMs = System.currentTimeMillis()
            val presentList = markedPresentMap.values.toList()
            val presentIds = markedPresentMap.keys.toSet()
            val absentIds = roster.map { it.personId }.filter { !presentIds.contains(it) }

            mapOf(
                "present" to presentList,
                "absentPersonIds" to absentIds,
                "unrecognizedFaceCount" to unrecognizedFaceCount,
                "totalRosterCount" to roster.size,
                "sessionStartTimeMs" to startTimeMs,
                "sessionEndTimeMs" to endTimeMs,
                "mode" to "batchImages",
                "photosProcessed" to imagePaths.size,
                "capturedImagePaths" to imagePaths,
            )
        }
    }

    private fun dispose(result: MethodChannel.Result) {
        IcueFaceCamera.stop()
        scope.launch {
            try {
                lifecycleMutex.withLock {
                    sdk?.close()
                    sdk = null
                }
                result.success(null)
            } catch (error: Throwable) {
                sendError(result, error)
            }
        }
    }

    private fun launchSdkCall(
        result: MethodChannel.Result,
        isFrame: Boolean = false,
        block: suspend (IcueFaceSdk) -> Any?,
    ) {
        val currentSdk = sdk
            ?: return result.error("NOT_INITIALIZED", "SDK is not initialized", null)
        if (currentSdk.isClosed) {
            return result.error("CLOSED", "SDK is closed", null)
        }
        if (isFrame && !frameInFlight.compareAndSet(false, true)) {
            return result.error("FRAME_BUSY", "A camera frame is already being processed", null)
        }
        scope.launch {
            try {
                if (currentSdk.isClosed) {
                    result.error("CLOSED", "SDK is closed", null)
                    return@launch
                }
                result.success(block(currentSdk))
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                sendError(result, error)
            } finally {
                if (isFrame) frameInFlight.set(false)
            }
        }
    }

    private suspend fun <T> withBitmap(
        imagePath: String,
        mirrorHorizontally: Boolean,
        block: suspend (Bitmap) -> T,
    ): T {
        val bitmap = withContext(Dispatchers.IO) {
            loadUprightBitmap(imagePath, mirrorHorizontally)
        } ?: throw IllegalArgumentException("Unable to decode image: $imagePath")
        return try {
            block(bitmap)
        } finally {
            // Bitmap is left for Android GC (NativeAllocationRegistry) to reclaim safely once MLKit finishes.
        }
    }

    private fun loadUprightBitmap(path: String, mirrorHorizontally: Boolean): Bitmap? {
        val source = BitmapFactory.decodeFile(path) ?: return null
        val matrix = Matrix()
        when (ExifInterface(path).rotationDegrees) {
            90 -> matrix.postRotate(90f)
            180 -> matrix.postRotate(180f)
            270 -> matrix.postRotate(270f)
        }
        if (mirrorHorizontally) matrix.postScale(-1f, 1f)
        if (matrix.isIdentity) return source
        return Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true).also {
            if (it !== source) source.recycle()
        }
    }

    private fun MethodCall.profiles(): List<IcueFaceProfile> {
        val rawProfiles = required<List<*>>("profiles")
        return rawProfiles.mapIndexed { index, raw ->
            val map = raw as? Map<*, *>
                ?: throw IllegalArgumentException("profiles[$index] must be a map")
            val personId = map["personId"] as? String
                ?: throw IllegalArgumentException("profiles[$index].personId is required")
            IcueFaceProfile(personId, map["embedding"].toFloatArray("profiles[$index].embedding"))
        }
    }

    private fun MethodCall.roster(): List<IcueFaceProfile> {
        val rawProfiles = argument<List<*>>("roster") ?: required<List<*>>("profiles")
        return rawProfiles.mapIndexed { index, raw ->
            val map = raw as? Map<*, *>
                ?: throw IllegalArgumentException("roster[$index] must be a map")
            val personId = map["personId"] as? String
                ?: throw IllegalArgumentException("roster[$index].personId is required")
            IcueFaceProfile(personId, map["embedding"].toFloatArray("roster[$index].embedding"))
        }
    }

    private fun MethodCall.recognitionOptions(defaultMode: RecognitionMode): RecognitionOptions {
        val modeName = argument<String>("mode") ?: defaultMode.name
        val mode = try {
            RecognitionMode.valueOf(modeName)
        } catch (_: IllegalArgumentException) {
            throw IllegalArgumentException("Unknown recognition mode: $modeName")
        }
        return RecognitionOptions(
            mode,
            argument<Int>("maxFaces") ?: FaceSdkDefaults.DEFAULT_MAX_FACES,
            (argument<Number>("threshold") ?: FaceSdkDefaults.DEFAULT_MATCH_THRESHOLD).toFloat(),
        )
    }

    private fun MethodCall.nv21Frame() = Nv21Frame(
        bytes = required("nv21Bytes"),
        width = required("width"),
        height = required("height"),
        rotation = argument<Int>("rotation") ?: 0,
        mirrorHorizontally = argument<Boolean>("isFrontCamera") ?: false,
    )

    private fun MethodCall.yuv420Frame() = IcueYuv420Frame(
        yBytes = required("yBytes"),
        uBytes = required("uBytes"),
        vBytes = required("vBytes"),
        width = required("width"),
        height = required("height"),
        yRowStride = required("yRowStride"),
        uRowStride = required("uRowStride"),
        vRowStride = required("vRowStride"),
        uPixelStride = required("uPixelStride"),
        vPixelStride = required("vPixelStride"),
        rotationDegrees = argument<Int>("rotation") ?: 0,
        mirrorHorizontally = argument<Boolean>("isFrontCamera") ?: false,
    )

    private fun MethodCall.cameraLens(): IcueCameraLens =
        when (argument<String>("lens") ?: "front") {
            "front" -> IcueCameraLens.FRONT
            "back" -> IcueCameraLens.BACK
            else -> throw IllegalArgumentException("lens must be front or back")
        }

    private inline fun <reified T> MethodCall.required(name: String): T =
        argument<T>(name) ?: throw IllegalArgumentException("$name is required")

    private fun MethodCall.floatArray(name: String): FloatArray =
        arguments.let { required<Any>(name).toFloatArray(name) }

    private fun Any?.toFloatArray(name: String): FloatArray = when (this) {
        is FloatArray -> this
        is DoubleArray -> FloatArray(size) { this[it].toFloat() }
        is List<*> -> FloatArray(size) { index ->
            (this[index] as? Number)?.toFloat()
                ?: throw IllegalArgumentException("$name[$index] must be numeric")
        }
        else -> throw IllegalArgumentException("$name must be a float array")
    }

    private fun List<IcueBoundingBox>.toBoundingBoxChannelValue() = map { box ->
        mapOf(
            "left" to box.left,
            "top" to box.top,
            "right" to box.right,
            "bottom" to box.bottom,
            "trackingId" to box.trackingId,
        )
    }

    private fun List<IcueRecognitionResult>.toRecognitionChannelValue() = map { recognition ->
        mapOf<String, Any?>(
            "personId" to recognition.personId,
            "score" to recognition.score,
            "matched" to recognition.matched,
            "boundingBox" to listOf(recognition.boundingBox).toBoundingBoxChannelValue().first(),
        )
    }

    private fun IcueFaceTrackingResult.toTrackingChannelValue() = mapOf(
        "type" to "faces",
        "faces" to faces.toBoundingBoxChannelValue(),
        "recognitions" to recognitions.toRecognitionChannelValue(),
        "frameWidth" to frameWidth,
        "frameHeight" to frameHeight,
        "timestampMillis" to timestampMillis,
    )

    private fun sendError(
        result: MethodChannel.Result,
        error: Throwable,
        fallbackCode: String = "ERROR",
    ) {
        when (error) {
            is FaceSdkException -> result.error(error.code.name, error.message, null)
            is IllegalArgumentException -> result.error("INVALID_ARGUMENT", error.message, null)
            else -> result.error(fallbackCode, error.message ?: "Face SDK call failed", null)
        }
    }

    private data class RecognitionOptions(
        val mode: RecognitionMode,
        val maxFaces: Int,
        val threshold: Float,
    )

    private data class Nv21Frame(
        val bytes: ByteArray,
        val width: Int,
        val height: Int,
        val rotation: Int,
        val mirrorHorizontally: Boolean,
    )

    companion object {
        private const val CHANNEL_NAME = "icue_face_sdk"
        private const val TRACKING_CHANNEL_NAME = "icue_face_sdk/tracking"

        private fun newScope() = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    }
}
