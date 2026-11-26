package school.icue.face.core.camera

import android.Manifest
import android.animation.ValueAnimator
import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Size
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import android.view.ScaleGestureDetector
import android.widget.SeekBar
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import android.view.GestureDetector
import android.view.MotionEvent
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExtendableBuilder
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.doOnLayout
import androidx.core.view.WindowInsetsControllerCompat
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import school.icue.face.core.FaceSdkErrorCode
import school.icue.face.core.FaceSdkException
import school.icue.face.core.model.IcueBoundingBox
import school.icue.face.core.model.IcueFaceProfile
import school.icue.face.core.model.RecognitionMode
import school.icue.face.core.model.toUnrecognizedFaceMap
import school.icue.face.core.recognition.TrackedIdentityCache
import school.icue.face.core.recognition.UnknownFaceTracker

class IcueFaceCameraActivity : ComponentActivity() {
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val analysisScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val processing = AtomicBoolean(false)
    private lateinit var previewView: PreviewView
    private lateinit var overlay: FaceOverlayView
    private lateinit var statusPill: TextView
    private var countLabel: TextView? = null
    // Attendance Finish button, relabelled with the number of students scanned so far.
    private var finishButton: TextView? = null
    // True while the cancel dialog is open: no frames are analysed, so the count cannot change.
    @Volatile
    private var paused = false
    // Attendance only: beeps when a new student is marked present.
    private var scanTone: ToneGenerator? = null
    private var camera: Camera? = null
    private var scaleGestureDetector: ScaleGestureDetector? = null
    private var zoomSlider: SeekBar? = null
    private var zoomLabel: TextView? = null
    private val zoomPresetButtons = mutableListOf<ZoomPresetButton>()
    private var shutterButton: FrameLayout? = null
    private var flashOverlay: View? = null
    private var sessionId: String? = null
    private var session: CameraSession? = null
    // Labels show a student's name when the caller sent one, else the personId.
    private var namesById: Map<String, String> = emptyMap()
    private var captureRequested = false
    private var completed = false
    private var capturedEmbedding: FloatArray? = null
    private var finalAttendanceResult: Map<String, Any?>? = null
    private val markedPresentMap = java.util.concurrent.ConcurrentHashMap<String, Map<String, Any?>>()
    private val liveAttendanceHitsMap = java.util.concurrent.ConcurrentHashMap<String, Int>()
    private val capturedPhotoPaths = java.util.Collections.synchronizedList(mutableListOf<String>())
    private var unrecognizedCount = 0
    // Live: one entry per confirmed unknown person (from unknownFaces). Multi-photo: every unmatched face.
    private val unrecognizedFaces = java.util.Collections.synchronizedMap(LinkedHashMap<Any, Map<String, Any?>>())
    // Live: which faces are people not on the roster, recognised by embedding.
    private val unknownFaces = UnknownFaceTracker(requiredChecks = REQUIRED_UNRECOGNIZED_CHECKS)
    private var photosCapturedCount = 0
    private var sessionStartTimeMs = 0L
    // Replaced, not cleared, on every camera start: tracking IDs reset with the stream, and a
    // frame still in flight keeps the old instance.
    @Volatile
    private var identityCache = TrackedIdentityCache()
    private var analysisFrameCount = 0
    private var analysisWindowStartMs = System.currentTimeMillis()
    private var frontCamera = true
    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            startCamera()
        } else {
            fail("CAMERA_PERMISSION_DENIED", "Camera permission was denied")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        sessionStartTimeMs = System.currentTimeMillis()
        sessionId = intent.getStringExtra(IcueFaceCamera.EXTRA_SESSION_ID)
        session = CameraSessionRegistry.resolve(sessionId)
        if (session == null) {
            finish()
            return
        }
        if (session is CameraSession.LiveAttendance || session is CameraSession.MultiPhotoAttendance) {
            // Alarm volume: usually high, and still plays when the phone is on silent or vibrate.
            // ponytail: fixed loudness (80 of 100); add a volume option if schools want to tune it.
            scanTone = runCatching { ToneGenerator(AudioManager.STREAM_ALARM, 80) }.getOrNull()
            // Back used to cancel attendance silently; now it only points to the buttons.
            onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    Toast.makeText(this@IcueFaceCameraActivity, "Use Finish or Cancel below", Toast.LENGTH_SHORT).show()
                }
            })
        }
        namesById = when (val activeSession = session) {
            is CameraSession.Tracking -> activeSession.profiles
            is CameraSession.LiveAttendance -> activeSession.roster
            is CameraSession.MultiPhotoAttendance -> activeSession.roster
            else -> emptyList()
        }.mapNotNull { profile -> profile.name?.let { profile.personId to it } }.toMap()
        frontCamera = intent.getStringExtra(IcueFaceCamera.EXTRA_LENS) != IcueCameraLens.BACK.name
        CameraSessionRegistry.attach(this)
        buildContent()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    override fun onDestroy() {
        analysisScope.cancel()
        scanTone?.release()
        scanTone = null
        runCatching {
            ProcessCameraProvider.getInstance(this).get().unbindAll()
        }
        analysisExecutor.shutdown()
        val embedding = capturedEmbedding
        val attendance = finalAttendanceResult
        val activeSession = session
        super.onDestroy()
        when {
            embedding != null && activeSession is CameraSession.Capture ->
                activeSession.callback.onCaptured(embedding)
            attendance != null && activeSession is CameraSession.LiveAttendance ->
                activeSession.callback.onCompleted(attendance)
            attendance != null && activeSession is CameraSession.MultiPhotoAttendance ->
                activeSession.callback.onCompleted(attendance)
            !completed -> notifyStopped()
        }
        CameraSessionRegistry.clear(sessionId)
    }

    private fun buildContent() {
        previewView = PreviewView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        overlay = FaceOverlayView(this) { frontCamera }

        flashOverlay = View(this).apply {
            setBackgroundColor(Color.WHITE)
            alpha = 0f
        }

        statusPill = TextView(this).apply {
            setTextColor(COLOR_TEXT_PRIMARY)
            textSize = 12f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            letterSpacing = 0.06f
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(8), dp(14), dp(8))
            background = roundedPill(0xCC0B1422.toInt(), 0x4400E5FF.toInt())
            text = when (val activeSession = session) {
                is CameraSession.Capture -> "⚠️ Position student face in frame"
                is CameraSession.LiveAttendance -> "LIVE ATTENDANCE • 0/${activeSession.roster.size} PRESENT (0%)"
                is CameraSession.MultiPhotoAttendance -> "MULTI-PHOTO • 0 PHOTO(S) • 0/${activeSession.roster.size} PRESENT"
                else -> "ATTENDANCE • SCANNING CLASSROOM"
            }
            // Live attendance shows its count large in the header instead.
            if (session is CameraSession.LiveAttendance) visibility = View.GONE
        }

        val topScrim = View(this).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0xCC050B14.toInt(), Color.TRANSPARENT),
            )
        }
        val bottomScrim = View(this).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.TRANSPARENT, 0xCC050B14.toInt()),
            )
        }

        val titleBlock = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(TextView(this@IcueFaceCameraActivity).apply {
                text = when (session) {
                    is CameraSession.Capture -> "STUDENT ENROLLMENT"
                    is CameraSession.LiveAttendance -> "TRANSPORT ATTENDANCE"
                    is CameraSession.MultiPhotoAttendance -> "MULTI-GROUP ATTENDANCE"
                    else -> "STUDENT ATTENDANCE SCAN"
                }
                setTextColor(COLOR_ACCENT_CYAN)
                textSize = 13f
                letterSpacing = 0.18f
                // Wraps onto a second line on narrow screens instead of reaching the buttons.
                maxLines = 2
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            })
            addView(TextView(this@IcueFaceCameraActivity).apply {
                text = "iCue School Vision · on-device"
                setTextColor(COLOR_TEXT_SECONDARY)
                textSize = 11f
                setPadding(0, dp(2), 0, 0)
            })
        }

        // Live attendance shows the present count after the title block, centred on it.
        (session as? CameraSession.LiveAttendance)?.let { live ->
            countLabel = TextView(this).apply {
                setTextColor(Color.WHITE)
                textSize = 28f
                typeface = Typeface.create("sans-serif-black", Typeface.BOLD)
            }
            setAttendanceCount(live.roster.size, 0)
        }

        val titleStack = HeaderRow(this).apply {
            addView(titleBlock)
            countLabel?.let { addView(it) }
        }

        val cameraFlipBtn = FrameLayout(this).apply {
            background = roundedRipple(0x66101B2B.toInt(), 0x44FFFFFF, 22f, 0x4400E5FF.toInt())
            contentDescription = "Switch Camera Lens"
            addView(CameraFlipIconView(this@IcueFaceCameraActivity), FrameLayout.LayoutParams(dp(22), dp(22), Gravity.CENTER))
            setOnClickListener {
                frontCamera = !frontCamera
                startCamera()
            }
        }

        val isAttendance = session is CameraSession.LiveAttendance ||
            session is CameraSession.MultiPhotoAttendance

        val closeBtn = TextView(this).apply {
            text = "✕"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            contentDescription = "Close session"
            background = roundedRipple(0x66101B2B.toInt(), 0x44FFFFFF, 22f, 0x33FFFFFF)
            setOnClickListener { finish() }
        }

        val topControls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(cameraFlipBtn, LinearLayout.LayoutParams(dp(42), dp(42)).apply { marginEnd = dp(8) })
            // Attendance has no close button: helpers tapped it thinking it saved the scans.
            // They leave through Cancel or Finish at the bottom instead.
            if (!isAttendance) addView(closeBtn, LinearLayout.LayoutParams(dp(42), dp(42)))
        }

        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(titleStack, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(topControls, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }

        val topPillContainer = FrameLayout(this).apply {
            addView(statusPill, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        }

        var actionButton: View? = null

        if (session is CameraSession.Capture) {
            val outerRing = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setStroke(dp(3), COLOR_ACCENT_GREEN)
                    setColor(Color.TRANSPARENT)
                }
            }
            val innerDot = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(COLOR_ACCENT_GREEN)
                }
            }
            shutterButton = FrameLayout(this).apply {
                contentDescription = "Enroll Student Face"
                addView(outerRing, FrameLayout.LayoutParams(dp(72), dp(72), Gravity.CENTER))
                addView(innerDot, FrameLayout.LayoutParams(dp(54), dp(54), Gravity.CENTER))
                isEnabled = false
                alpha = 0.35f
                setOnClickListener {
                    isEnabled = false
                    alpha = 0.55f
                    captureRequested = true
                    statusPill.text = "Processing student biometric embedding..."
                    triggerCaptureFlash()
                }
            }
            actionButton = shutterButton
        } else if (session is CameraSession.LiveAttendance) {
            val liveSession = session as CameraSession.LiveAttendance
            val finishBtn = TextView(this).apply {
                text = finishLabel(0)
                setTextColor(Color.WHITE)
                textSize = 15f
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                letterSpacing = 0.04f
                gravity = Gravity.CENTER
                setPadding(dp(28), dp(14), dp(28), dp(14))
                background = roundedRipple(0xFF0B7A3E.toInt(), 0x44FFFFFF, 26f, 0xAA00E676.toInt())
                setOnClickListener {
                    completeAttendanceSession("liveStream", liveSession.roster, liveSession.callback)
                }
            }
            finishButton = finishBtn
            actionButton = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(
                    cancelButton { requestCancelAttendance("liveStream", liveSession.roster, liveSession.callback) },
                    LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
                        .apply { marginEnd = dp(16) },
                )
                addView(finishBtn, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            }
        } else if (session is CameraSession.MultiPhotoAttendance) {
            val multiSession = session as CameraSession.MultiPhotoAttendance
            val outerRing = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setStroke(dp(3), COLOR_ACCENT_CYAN)
                    setColor(Color.TRANSPARENT)
                }
            }
            val innerDot = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(COLOR_ACCENT_CYAN)
                }
            }
            shutterButton = FrameLayout(this).apply {
                contentDescription = "Snap Group Photo"
                addView(outerRing, FrameLayout.LayoutParams(dp(64), dp(64), Gravity.CENTER))
                addView(innerDot, FrameLayout.LayoutParams(dp(48), dp(48), Gravity.CENTER))
                setOnClickListener {
                    captureRequested = true
                    statusPill.text = "Analyzing group photo..."
                }
            }
            val finishBtn = TextView(this).apply {
                text = finishLabel(0)
                setTextColor(Color.WHITE)
                textSize = 14f
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                letterSpacing = 0.04f
                gravity = Gravity.CENTER
                setPadding(dp(18), dp(12), dp(18), dp(12))
                background = roundedRipple(0xFF0B7A3E.toInt(), 0x44FFFFFF, 22f, 0xAA00E676.toInt())
                setOnClickListener {
                    completeAttendanceSession("multiPhoto", multiSession.roster, multiSession.callback)
                }
            }
            finishButton = finishBtn
            actionButton = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(
                    cancelButton { requestCancelAttendance("multiPhoto", multiSession.roster, multiSession.callback) },
                    LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
                        .apply { marginEnd = dp(16) },
                )
                addView(shutterButton, LinearLayout.LayoutParams(dp(64), dp(64)).apply { marginEnd = dp(16) })
                addView(finishBtn, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            }
        }

        scaleGestureDetector = ScaleGestureDetector(this,
            object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                override fun onScale(detector: ScaleGestureDetector): Boolean {
                    val cam = camera ?: return true
                    val zoomState = cam.cameraInfo.zoomState.value ?: return true
                    val newRatio = (zoomState.zoomRatio * detector.scaleFactor)
                        .coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
                    cam.cameraControl.setZoomRatio(newRatio)
                    updateZoomUi(newRatio, zoomState.minZoomRatio, zoomState.maxZoomRatio)
                    return true
                }
            }
        )

        val tapToFocus = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapUp(event: MotionEvent): Boolean {
                val cam = camera ?: return true
                val point = previewView.meteringPointFactory.createPoint(event.x, event.y)
                cam.cameraControl.startFocusAndMetering(FocusMeteringAction.Builder(point).build())
                return true
            }
        })

        previewView.setOnTouchListener { _, event ->
            scaleGestureDetector?.onTouchEvent(event)
            tapToFocus.onTouchEvent(event)
            true
        }

        val isAttendanceOrTracking = session is CameraSession.LiveAttendance ||
            session is CameraSession.MultiPhotoAttendance ||
            session is CameraSession.Tracking

        var zoomContainer: LinearLayout? = null
        if (isAttendanceOrTracking) {
            zoomPresetButtons.clear()

            val presetRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }

            listOf(1.0f, 2.0f, 3.0f, 5.0f).forEach { zoomVal ->
                val btn = ZoomPresetButton(this@IcueFaceCameraActivity, zoomVal).apply {
                    setOnClickListener { view ->
                        val cam = camera ?: return@setOnClickListener
                        val zoomState = cam.cameraInfo.zoomState.value ?: return@setOnClickListener
                        val clamped = zoomVal.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
                        cam.cameraControl.setZoomRatio(clamped)
                        updateZoomUi(clamped, zoomState.minZoomRatio, zoomState.maxZoomRatio)
                        view.performHapticFeedback(android.view.HapticFeedbackConstants.KEYBOARD_TAP)
                    }
                }
                zoomPresetButtons.add(btn)
                presetRow.addView(btn, LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    leftMargin = dp(4)
                    rightMargin = dp(4)
                })
            }

            zoomLabel = TextView(this).apply {
                text = "1.0x"
                setTextColor(COLOR_ACCENT_CYAN)
                textSize = 12f
                typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                letterSpacing = 0.04f
                gravity = Gravity.CENTER
                setPadding(dp(6), 0, dp(6), 0)
            }

            zoomSlider = SeekBar(this).apply {
                max = 100
                progress = 0
                progressTintList = ColorStateList.valueOf(COLOR_ACCENT_CYAN)
                thumbTintList = ColorStateList.valueOf(COLOR_ACCENT_CYAN)
                progressBackgroundTintList = ColorStateList.valueOf(0x44FFFFFF)
                setPadding(dp(8), 0, dp(8), 0)
                setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                        if (!fromUser) return
                        val cam = camera ?: return
                        val zoomState = cam.cameraInfo.zoomState.value ?: return
                        val ratio = zoomState.minZoomRatio +
                            (progress / 100f) * (zoomState.maxZoomRatio - zoomState.minZoomRatio)
                        cam.cameraControl.setZoomRatio(ratio)
                        updateZoomUi(ratio, zoomState.minZoomRatio, zoomState.maxZoomRatio)
                    }
                    override fun onStartTrackingTouch(seekBar: SeekBar) {}
                    override fun onStopTrackingTouch(seekBar: SeekBar) {}
                })
            }

            val sliderRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(4), 0, dp(4), 0)
                addView(TextView(this@IcueFaceCameraActivity).apply {
                    text = "🔍"
                    textSize = 11f
                    setPadding(dp(2), 0, dp(2), 0)
                })
                addView(zoomSlider, LinearLayout.LayoutParams(0, dp(28), 1f))
                addView(zoomLabel, LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ))
            }

            zoomContainer = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(14), dp(8), dp(14), dp(8))
                background = roundedPill(0xCC0B1422.toInt(), 0x4400E5FF.toInt())
                addView(presetRow, LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = dp(6)
                })
                addView(sliderRow, LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                ))
            }
        }

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            addView(previewView)
            addView(topScrim, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(180),
                Gravity.TOP,
            ))
            if (session is CameraSession.Capture || session is CameraSession.LiveAttendance || session is CameraSession.MultiPhotoAttendance) {
                addView(bottomScrim, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(160),
                    Gravity.BOTTOM,
                ))
            }
            addView(this@IcueFaceCameraActivity.overlay, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ))
            addView(this@IcueFaceCameraActivity.flashOverlay, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ))
            addView(topBar, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP,
            ).apply {
                leftMargin = dp(20)
                rightMargin = dp(20)
                topMargin = dp(12)
            })
            addView(topPillContainer, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP,
            ).apply {
                topMargin = dp(68)
            })

            zoomContainer?.let { zc ->
                addView(zc, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
                ).apply {
                    leftMargin = dp(24)
                    rightMargin = dp(24)
                    bottomMargin = dp(96)
                })
            }

            actionButton?.let { bar ->
                addView(bar, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
                ).apply {
                    bottomMargin = dp(32)
                })
            }
        }

        WindowInsetsControllerCompat(window, root).apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, windowInsets ->
            val safeInsets = windowInsets.getInsets(
                WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
            )
            (topBar.layoutParams as FrameLayout.LayoutParams).apply {
                leftMargin = safeInsets.left + dp(20)
                topMargin = safeInsets.top + dp(12)
                rightMargin = safeInsets.right + dp(20)
                topBar.layoutParams = this
            }
            (topPillContainer.layoutParams as FrameLayout.LayoutParams).apply {
                topMargin = safeInsets.top + dp(68)
                topPillContainer.layoutParams = this
            }
            zoomContainer?.let { zc ->
                (zc.layoutParams as FrameLayout.LayoutParams).apply {
                    bottomMargin = safeInsets.bottom + dp(104)
                    zc.layoutParams = this
                }
            }
            actionButton?.let { bar ->
                (bar.layoutParams as FrameLayout.LayoutParams).apply {
                    bottomMargin = safeInsets.bottom + dp(32)
                    bar.layoutParams = this
                }
            }
            windowInsets
        }
        setContentView(root)
        ViewCompat.requestApplyInsets(root)
    }

    private fun triggerCaptureFlash() {
        flashOverlay?.apply {
            alpha = 0.85f
            animate()
                .alpha(0f)
                .setDuration(350)
                .start()
        }
    }

    private fun setAttendanceCount(total: Int, present: Int) {
        countLabel?.text = "$present/$total"
        finishButton?.text = finishLabel(present)
    }

    /**
     * One beep and a short buzz when new students are marked present, so a helper on a moving
     * bus knows to move to the next student without reading the screen. Once per frame, however
     * many students that frame added.
     */
    private fun scanFeedback() {
        runCatching { scanTone?.startTone(ToneGenerator.TONE_PROP_BEEP, 200) }
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        // One firm pulse: about 70% strength where the phone supports it (255 is full).
        when {
            vibrator == null -> Unit
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && vibrator.hasAmplitudeControl() ->
                vibrator.vibrate(VibrationEffect.createOneShot(200, 180))
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ->
                vibrator.vibrate(VibrationEffect.createOneShot(150, VibrationEffect.DEFAULT_AMPLITUDE))
            else -> {
                @Suppress("DEPRECATION")
                vibrator.vibrate(150)
            }
        }
    }

    private fun finishLabel(scanned: Int) = if (scanned > 0) "✓ FINISH ($scanned)" else "✓ FINISH"

    private fun studentsText(count: Int) = if (count == 1) "1 student" else "$count students"

    private fun cancelButton(onCancel: () -> Unit) = TextView(this).apply {
        text = "CANCEL"
        setTextColor(COLOR_TEXT_SECONDARY)
        textSize = 13f
        typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
        gravity = Gravity.CENTER
        setPadding(dp(18), dp(12), dp(18), dp(12))
        background = roundedRipple(0x99101B2B.toInt(), 0x44FFFFFF, 22f, 0x33FFFFFF)
        setOnClickListener { onCancel() }
    }

    /**
     * Nothing scanned: close at once. Otherwise ask, so a mistaken tap never loses the scans.
     * "Keep scanning", back, or a tap outside closes the popup and scanning resumes.
     *
     * A custom popup, not the system one: a big count first, then three full-width buttons
     * stacked in order of safety, so the safe choice is the biggest and the first one read.
     */
    private fun requestCancelAttendance(
        modeStr: String,
        roster: List<IcueFaceProfile>,
        callback: IcueFaceCamera.AttendanceCallback,
    ) {
        if (completed) return
        val scanned = markedPresentMap.size
        if (scanned == 0) {
            finish()
            return
        }
        paused = true
        val dialog = Dialog(this)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(28), dp(24), dp(16))
            background = GradientDrawable().apply {
                cornerRadius = dp(28).toFloat()
                setColor(0xFF101B2B.toInt())
                setStroke(dp(1), 0x3300E5FF)
            }
        }
        val wrap = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        card.addView(TextView(this).apply {
            text = "$scanned"
            textSize = 56f
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            setTextColor(COLOR_ACCENT_GREEN)
        }, wrap)
        card.addView(TextView(this).apply {
            text = if (scanned == 1) "student scanned" else "students scanned"
            textSize = 17f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            setTextColor(COLOR_TEXT_PRIMARY)
        }, wrap)
        card.addView(TextView(this).apply {
            text = "Submit their attendance?"
            textSize = 15f
            gravity = Gravity.CENTER
            setTextColor(COLOR_TEXT_SECONDARY)
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(6)
            bottomMargin = dp(20)
        })

        card.addView(popupButton("✓  Submit ${studentsText(scanned)}", 0xFF00A152.toInt(), Color.WHITE, Color.TRANSPARENT) {
            dialog.dismiss()
            completeAttendanceSession(modeStr, roster, callback)
        })
        card.addView(popupButton("Discard all scans", Color.TRANSPARENT, 0xFFFF5252.toInt(), 0xFFFF5252.toInt()) {
            dialog.dismiss()
            finish()
        })
        card.addView(popupButton("Keep scanning", Color.TRANSPARENT, COLOR_ACCENT_CYAN, Color.TRANSPARENT) {
            dialog.dismiss()
        })

        dialog.setContentView(card)
        dialog.setOnDismissListener { paused = false }
        dialog.show()
        dialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            setLayout(minOf(resources.displayMetrics.widthPixels - dp(40), dp(400)), ViewGroup.LayoutParams.WRAP_CONTENT)
        }
    }

    /** A full-width, 56dp popup button: big enough to hit on a moving bus. */
    private fun popupButton(label: String, fill: Int, textColor: Int, stroke: Int, onClick: () -> Unit) =
        TextView(this).apply {
            text = label
            textSize = 17f
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
            setTextColor(textColor)
            background = roundedRipple(fill, 0x33FFFFFF, 16f, stroke)
            setOnClickListener { onClick() }
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)).apply {
                topMargin = dp(10)
            }
        }

    /**
     * Title block with an optional count after it. The title wraps within whatever width the
     * count leaves, so the count never overlaps the header buttons; both are centred
     * vertically on each other.
     */
    private class HeaderRow(context: Context) : LinearLayout(context) {
        private val gap = (12 * resources.displayMetrics.density).toInt()

        override fun onMeasure(widthSpec: Int, heightSpec: Int) {
            val block = getChildAt(0)
            val count = if (childCount > 1) getChildAt(1) else null
            val unspecified = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
            count?.measure(unspecified, unspecified)
            val countWidth = count?.let { it.measuredWidth + gap } ?: 0
            val available = (MeasureSpec.getSize(widthSpec) - countWidth).coerceAtLeast(0)
            block.measure(MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST), unspecified)
            // Fill the width the parent gives, so the header buttons stay at the far end.
            setMeasuredDimension(
                resolveSize(block.measuredWidth + countWidth, widthSpec),
                maxOf(block.measuredHeight, count?.measuredHeight ?: 0),
            )
        }

        override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
            var x = 0
            for (index in 0 until childCount) {
                val child = getChildAt(index)
                val y = (measuredHeight - child.measuredHeight) / 2
                child.layout(x, y, x + child.measuredWidth, y + child.measuredHeight)
                x += child.measuredWidth + gap
            }
        }
    }

    private fun roundedPill(bgColor: Int, strokeColor: Int) = GradientDrawable().apply {
        cornerRadius = dp(20).toFloat()
        setColor(bgColor)
        setStroke(dp(1), strokeColor)
    }

    private fun roundedRipple(
        color: Int,
        rippleColor: Int,
        radiusDp: Float,
        strokeColor: Int,
    ): RippleDrawable {
        val content = GradientDrawable().apply {
            cornerRadius = dp(radiusDp.toInt()).toFloat()
            setColor(color)
            if (strokeColor != Color.TRANSPARENT) setStroke(dp(1), strokeColor)
        }
        val mask = GradientDrawable().apply {
            cornerRadius = dp(radiusDp.toInt()).toFloat()
            setColor(Color.WHITE)
        }
        return RippleDrawable(ColorStateList.valueOf(rippleColor), content, mask)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private companion object {
        val COLOR_ACCENT_CYAN = 0xFF00E5FF.toInt()
        val COLOR_ACCENT_GREEN = 0xFF00E676.toInt()
        val COLOR_TEXT_PRIMARY = 0xFFF1F5F9.toInt()
        val COLOR_TEXT_SECONDARY = 0xFF94A3B8.toInt()
        const val HIGH_RESOLUTION_MIN_HEAP_MEGABYTES = 384
        const val ANALYSIS_RATE_WINDOW_FRAMES = 30
        // A student is marked present only after this many separate model runs agree.
        const val REQUIRED_FRESH_HITS = 2
        // A face is reported as unregistered only after this many model runs found no student.
        const val REQUIRED_UNRECOGNIZED_CHECKS = 3
    }

    private fun startCamera() {
        identityCache = TrackedIdentityCache()
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                val selector = if (frontCamera) {
                    CameraSelector.DEFAULT_FRONT_CAMERA
                } else {
                    CameraSelector.DEFAULT_BACK_CAMERA
                }
                // Sensor-native 4:3: sharper and wider than a cropped 16:9 stream. Each frame is
                // copied and converted to a full-size bitmap, so the size follows the app heap:
                // an uncapped target let the Lava Smart 4 pick 2448x2448 and run out of memory.
                // Preview and analysis share the aspect ratio, because the face overlay maps
                // analysis frames onto the preview; CameraX keeps the preview at its own
                // supported maximum.
                val resolution = ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            analysisTargetSize(),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
                        ),
                    )
                    .build()
                val cameraInfo = selector.filter(provider.availableCameraInfos).firstOrNull()
                val preview = Preview.Builder()
                    .setResolutionSelector(resolution)
                    .also { it.requestHighQualityProcessing(cameraInfo) }
                    .build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    // CameraX converts and rotates in native code (libyuv); the SDK's per-pixel
                    // Kotlin YUV path is too slow for live tracking on low-end phones.
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setOutputImageRotationEnabled(true)
                    .setResolutionSelector(resolution)
                    .also { it.requestHighQualityProcessing(cameraInfo) }
                    .build()
                analysis.setAnalyzer(analysisExecutor, ::analyze)
                // The overlay draws analysis-frame boxes over the preview, so both must show the
                // same field of view. Sharing the preview's viewport gives every analysis frame a
                // crop rect matching what is on screen (see toFrameBitmap). It exists only after layout.
                previewView.doOnLayout {
                    try {
                        val group = UseCaseGroup.Builder()
                            .addUseCase(preview)
                            .addUseCase(analysis)
                            .also { builder -> previewView.viewPort?.let(builder::setViewPort) }
                            .build()
                        provider.unbindAll()
                        camera = provider.bindToLifecycle(this, selector, group)
                        android.util.Log.i(
                            "IcueFaceCamera",
                            "Streams: preview=${preview.resolutionInfo?.resolution} " +
                                "analysis=${analysis.resolutionInfo?.resolution} " +
                                "crop=${analysis.resolutionInfo?.cropRect} " +
                                "heap=${Runtime.getRuntime().maxMemory() / (1024 * 1024)}MB",
                        )
                        applyDefaultZoom()
                    } catch (error: Throwable) {
                        fail("CAMERA_UNAVAILABLE", error.message ?: "Unable to open camera")
                    }
                }
            } catch (error: Throwable) {
                fail("CAMERA_UNAVAILABLE", error.message ?: "Unable to open camera")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    /**
     * 1920x1440 gives distant faces in group attendance more pixels; 1440x1080 keeps budget
     * phones inside their heap.
     */
    // ponytail: heap-size heuristic; profile per-frame allocation if a mid-range phone still runs out.
    private fun analysisTargetSize(): Size {
        val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
        val heapMegabytes = Runtime.getRuntime().maxMemory() / (1024 * 1024)
        return if (!activityManager.isLowRamDevice && heapMegabytes >= HIGH_RESOLUTION_MIN_HEAP_MEGABYTES) {
            Size(1920, 1440)
        } else {
            Size(1440, 1080)
        }
    }

    /**
     * Streams default to FAST noise reduction and sharpening, which is what makes third-party
     * camera feeds look soft next to the stock camera app. Asks for HIGH_QUALITY where the
     * camera supports it; budget sensors may drop a few frames per second as a result.
     */
    @OptIn(ExperimentalCamera2Interop::class)
    private fun ExtendableBuilder<*>.requestHighQualityProcessing(cameraInfo: CameraInfo?) {
        val info = cameraInfo?.let(Camera2CameraInfo::from) ?: return
        val extender = Camera2Interop.Extender(this)
        val noiseModes = info.getCameraCharacteristic(
            CameraCharacteristics.NOISE_REDUCTION_AVAILABLE_NOISE_REDUCTION_MODES,
        )
        if (noiseModes?.contains(CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY) == true) {
            extender.setCaptureRequestOption(
                CaptureRequest.NOISE_REDUCTION_MODE,
                CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY,
            )
        }
        val edgeModes = info.getCameraCharacteristic(CameraCharacteristics.EDGE_AVAILABLE_EDGE_MODES)
        if (edgeModes?.contains(CaptureRequest.EDGE_MODE_HIGH_QUALITY) == true) {
            extender.setCaptureRequestOption(
                CaptureRequest.EDGE_MODE,
                CaptureRequest.EDGE_MODE_HIGH_QUALITY,
            )
        }
    }

    private fun applyDefaultZoom() {
        val cam = camera ?: return
        val isAttendanceMode = session is CameraSession.LiveAttendance ||
            session is CameraSession.MultiPhotoAttendance ||
            session is CameraSession.Tracking

        if (frontCamera) {
            val zoomState = cam.cameraInfo.zoomState.value
            val minZoom = zoomState?.minZoomRatio ?: 1.0f
            val maxZoom = zoomState?.maxZoomRatio ?: 1.0f
            val normalZoom = 1.0f.coerceIn(minZoom, maxZoom)
            cam.cameraControl.setZoomRatio(normalZoom)
            if (isAttendanceMode) {
                updateZoomUi(normalZoom, minZoom, maxZoom)
            }
            return
        }

        if (!isAttendanceMode) return
        val defaultZoom = when (val s = session) {
            is CameraSession.LiveAttendance -> s.defaultZoom
            is CameraSession.MultiPhotoAttendance -> s.defaultZoom
            is CameraSession.Tracking -> s.defaultZoom
            else -> return
        }
        val zoomState = cam.cameraInfo.zoomState.value ?: return
        val clampedZoom = defaultZoom.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
        cam.cameraControl.setZoomRatio(clampedZoom)
        updateZoomUi(clampedZoom, zoomState.minZoomRatio, zoomState.maxZoomRatio)
    }

    private fun updateZoomUi(current: Float, min: Float, max: Float) {
        runOnUiThread {
            zoomLabel?.text = "%.1fx".format(current)
            val progress = if (max > min) {
                ((current - min) / (max - min) * 100).toInt()
            } else 0
            zoomSlider?.progress = progress
            zoomPresetButtons.forEach { btn ->
                btn.isPresetSelected = kotlin.math.abs(btn.zoomValue - current) < 0.15f
            }
        }
    }

    private fun analyze(image: ImageProxy) {
        if (paused || isFinishing || isDestroyed || completed || analysisExecutor.isShutdown || !analysisScope.isActive || !processing.compareAndSet(false, true)) {
            image.close()
            return
        }
        val frame = try {
            image.toFrameBitmap()
        } catch (error: Throwable) {
            processing.set(false)
            image.close()
            if (!isFinishing && !isDestroyed && !completed) {
                fail("CAMERA_FRAME_ERROR", error.message ?: "Unable to read camera frame")
            }
            return
        }
        image.close()
        try {
            if (isFinishing || isDestroyed || completed || !analysisScope.isActive) {
                processing.set(false)
                return
            }
            analysisScope.launch {
                try {
                    if (isFinishing || isDestroyed || completed) return@launch
                    val activeSession = session ?: return@launch
                    if (activeSession.sdk.isClosed) {
                        fail(FaceSdkErrorCode.CLOSED.name, "IcueFaceSdk was closed while the camera was open")
                        return@launch
                    }
                    when (activeSession) {
                        is CameraSession.Capture -> processCapture(activeSession, frame)
                        is CameraSession.Tracking -> processTracking(activeSession, frame)
                        is CameraSession.LiveAttendance -> processLiveAttendance(activeSession, frame)
                        is CameraSession.MultiPhotoAttendance -> processMultiPhotoAttendance(activeSession, frame)
                    }
                } catch (cancellation: CancellationException) {
                    throw cancellation
                } catch (faceSdkEx: FaceSdkException) {
                    if (faceSdkEx.code == FaceSdkErrorCode.CLOSED || isFinishing || isDestroyed || completed) {
                        return@launch
                    }
                    val code = faceSdkEx.code.name
                    fail(code, faceSdkEx.message ?: "Face processing failed")
                } catch (error: Throwable) {
                    if (!isFinishing && !isDestroyed && !completed) {
                        fail("PROCESSING_ERROR", error.message ?: "Face processing failed")
                    }
                } finally {
                    logAnalysisRate()
                    processing.set(false)
                }
            }
        } catch (_: java.util.concurrent.RejectedExecutionException) {
            processing.set(false)
        }
    }

    private suspend fun processCapture(
        activeSession: CameraSession.Capture,
        frame: Bitmap,
    ) {
        if (isFinishing || isDestroyed || completed || activeSession.sdk.isClosed) return
        if (!captureRequested) {
            try {
                val faces = activeSession.sdk.detectFaces(frame)
                if (isFinishing || isDestroyed || completed) return
                showFaces(faces, frame)
            } catch (error: FaceSdkException) {
                if (error.code == FaceSdkErrorCode.CLOSED || isFinishing || isDestroyed || completed) return
                fail(error.code.name, error.message ?: "Face detection failed")
            } catch (error: Throwable) {
                if (isFinishing || isDestroyed || completed) return
                fail("CAPTURE_FAILED", error.message ?: "Face detection failed")
            }
            return
        }
        captureRequested = false
        try {
            val embedding = activeSession.sdk.extractEmbedding(frame)
            if (isFinishing || isDestroyed || completed) return
            capturedEmbedding = embedding.copyOf()
            completed = true
            runOnUiThread {
                statusPill.text = "Student face captured"
                finish()
            }
        } catch (error: FaceSdkException) {
            if (error.code == FaceSdkErrorCode.CLOSED || isFinishing || isDestroyed || completed) return
            if (error.code == FaceSdkErrorCode.NO_FACE ||
                error.code == FaceSdkErrorCode.MULTIPLE_FACES ||
                error.code == FaceSdkErrorCode.POOR_FACE
            ) {
                runOnUiThread {
                    statusPill.text = error.message
                    shutterButton?.apply {
                        isEnabled = false
                        alpha = 0.35f
                    }
                }
            } else {
                fail(error.code.name, error.message ?: "Student enrollment capture failed")
            }
        } catch (error: Throwable) {
            if (isFinishing || isDestroyed || completed) return
            fail("CAPTURE_FAILED", error.message ?: "Student enrollment capture failed")
        }
    }

    private suspend fun processTracking(
        activeSession: CameraSession.Tracking,
        frame: Bitmap,
    ) {
        if (isFinishing || isDestroyed || completed || activeSession.sdk.isClosed) return
        try {
            val recognitions = if (activeSession.profiles.isEmpty()) {
                emptyList()
            } else {
                activeSession.sdk.recognizeTracked(
                    bitmap = frame,
                    profiles = activeSession.profiles,
                    maxFaces = activeSession.maxFaces,
                    threshold = activeSession.threshold,
                    cache = identityCache,
                )
            }
            val faces = if (activeSession.profiles.isEmpty()) {
                activeSession.sdk.detectFaces(frame)
            } else {
                recognitions.map { it.boundingBox }
            }
            if (isFinishing || isDestroyed || completed) return
            val (width, height) = frame.outputDimensions()
            val result = IcueFaceTrackingResult(
                faces = faces,
                recognitions = recognitions,
                frameWidth = width,
                frameHeight = height,
                timestampMillis = System.currentTimeMillis(),
            )
            val matchCount = recognitions.count { it.matched }
            runOnUiThread {
                overlay.update(
                    faces,
                    width,
                    height,
                    recognitions.map { recognition ->
                        formatFaceLabel(
                            matched = recognition.matched,
                            personId = recognition.personId,
                            score = recognition.score,
                            showDetectedLabel = activeSession.showDetectedLabel,
                            showMatchingPercentage = activeSession.showMatchingPercentage,
                            showUnrecognizedLabel = activeSession.showUnrecognizedLabel,
                            unrecognizedLabel = activeSession.unrecognizedLabel
                        )
                    },
                    recognitions.map { if (it.matched) FaceState.MATCHED else FaceState.UNKNOWN },
                )
                statusPill.text = when {
                    activeSession.profiles.isEmpty() -> "ATTENDANCE • TRACKING ${faces.size} STUDENT(S)"
                    faces.isEmpty() -> "ATTENDANCE • SCANNING CLASSROOM"
                    else -> "ATTENDANCE • ${faces.size} STUDENT(S) (${matchCount} RECOGNIZED)"
                }
                statusPill.background = roundedPill(0xCC0B1422.toInt(), 0x6600E5FF.toInt())
                activeSession.listener.onFaces(result)
            }
        } catch (error: Throwable) {
            if (error is FaceSdkException && error.code == FaceSdkErrorCode.CLOSED) return
            if (isFinishing || isDestroyed || completed) return
            val code = (error as? FaceSdkException)?.code?.name ?: "TRACKING_FAILED"
            fail(code, error.message ?: "Attendance tracking failed")
        }
    }

    private suspend fun processLiveAttendance(
        activeSession: CameraSession.LiveAttendance,
        frame: Bitmap,
    ) {
        if (isFinishing || isDestroyed || completed || activeSession.sdk.isClosed) return
        try {
            val recognitions = if (activeSession.roster.isEmpty()) {
                emptyList()
            } else {
                activeSession.sdk.recognizeTracked(
                    bitmap = frame,
                    profiles = activeSession.roster,
                    maxFaces = activeSession.maxFaces,
                    threshold = activeSession.threshold,
                    cache = identityCache,
                )
            }
            if (isFinishing || isDestroyed || completed) return
            var newlyScanned = 0
            recognitions.forEach { recognition ->
                if (recognition.matched && recognition.personId != null) {
                    val pId = recognition.personId!!
                    // Two fresh model runs must agree on the same tracked face. Replayed tracking
                    // results are not new evidence, and a match on another face proves nothing.
                    val hitKey = "${recognition.boundingBox.trackingId}:$pId"
                    val hits = (liveAttendanceHitsMap[hitKey] ?: 0) + if (recognition.reused) 0 else 1
                    liveAttendanceHitsMap[hitKey] = hits
                    val existing = markedPresentMap[pId]
                    val existingScore = (existing?.get("score") as? Number)?.toDouble() ?: 0.0
                    if (hits >= REQUIRED_FRESH_HITS) {
                        // Counted as a student, so any earlier misses on this face were bad frames.
                        recognition.embedding?.let(unknownFaces::forget)
                        if (existing == null) newlyScanned++
                        if (existing == null || recognition.score > existingScore) {
                            markedPresentMap[pId] = mapOf(
                                "personId" to pId,
                                "score" to recognition.score.toDouble(),
                                "boundingBox" to recognition.boundingBox.toChannelValue(),
                                "timestampMillis" to System.currentTimeMillis(),
                            )
                        }
                    } else {
                        // Not confirmed yet: run the model on this face again next frame instead of
                        // replaying this result, so confirmation takes one frame, not ten.
                        identityCache.forget(recognition.boundingBox.trackingId)
                    }
                } else {
                    // Unknown only after repeated fresh checks: a student's first blurry or
                    // half-turned frames, or a face whose eyes were not found (no embedding, so
                    // never compared), must not be reported as an unregistered person.
                    val embedding = recognition.embedding
                    if (!recognition.reused && embedding != null) {
                        unknownFaces.recordMiss(embedding, recognition.toUnrecognizedFaceMap())
                    }
                }
            }
            if (newlyScanned > 0) scanFeedback()
            synchronized(unrecognizedFaces) {
                unrecognizedFaces.clear()
                unknownFaces.confirmed().forEachIndexed { index, details -> unrecognizedFaces[index] = details }
                unrecognizedCount = unrecognizedFaces.size
            }

            val (width, height) = frame.outputDimensions()
            val faces = recognitions.map { it.boundingBox }
            val totalRoster = activeSession.roster.size
            val presentCount = markedPresentMap.size
            // Green tick and name only once the student is counted, so the screen never shows a
            // student as done while the count (and the beep) are still waiting for confirmation.
            val counted = recognitions.map { it.matched && it.personId?.let(markedPresentMap::containsKey) == true }
            // Likewise the "unregistered" label only once the face is confirmed unknown.
            val strangers = recognitions.map { recognition ->
                !recognition.matched && recognition.embedding?.let(unknownFaces::isConfirmed) == true
            }

            runOnUiThread {
                overlay.update(
                    faces,
                    width,
                    height,
                    recognitions.mapIndexed { index, recognition ->
                        if (!counted[index] && !strangers[index]) return@mapIndexed null
                        formatFaceLabel(
                            matched = counted[index],
                            personId = recognition.personId,
                            score = recognition.score,
                            showDetectedLabel = activeSession.showDetectedLabel,
                            showMatchingPercentage = activeSession.showMatchingPercentage,
                            showUnrecognizedLabel = activeSession.showUnrecognizedLabel,
                            unrecognizedLabel = activeSession.unrecognizedLabel
                        )
                    },
                    // Faces not yet decided stay "scanning": the next frames may still count them.
                    recognitions.indices.map { index ->
                        when {
                            counted[index] -> FaceState.MATCHED
                            strangers[index] -> FaceState.UNKNOWN
                            else -> FaceState.SCANNING
                        }
                    },
                )
                setAttendanceCount(totalRoster, presentCount)
            }

            if (activeSession.autoFinish && !paused && totalRoster > 0 && presentCount >= totalRoster) {
                completeAttendanceSession("liveStream", activeSession.roster, activeSession.callback)
            }
        } catch (error: Throwable) {
            if (error is FaceSdkException && error.code == FaceSdkErrorCode.CLOSED) return
            if (isFinishing || isDestroyed || completed) return
            val code = (error as? FaceSdkException)?.code?.name ?: "ATTENDANCE_FAILED"
            fail(code, error.message ?: "Live attendance failed")
        }
    }

    private suspend fun processMultiPhotoAttendance(
        activeSession: CameraSession.MultiPhotoAttendance,
        frame: Bitmap,
    ) {
        if (isFinishing || isDestroyed || completed || activeSession.sdk.isClosed) return
        if (!captureRequested) {
            try {
                val faces = activeSession.sdk.detectFaces(frame)
                if (isFinishing || isDestroyed || completed) return
                val (width, height) = frame.outputDimensions()
                val totalRoster = activeSession.roster.size
                val presentCount = markedPresentMap.size
                runOnUiThread {
                    overlay.update(faces, width, height)
                    statusPill.text = "MULTI-PHOTO • ${photosCapturedCount} PHOTO(S) • $presentCount/$totalRoster PRESENT"
                    statusPill.background = roundedPill(0xCC0B1422.toInt(), 0x6600E5FF.toInt())
                }
            } catch (error: FaceSdkException) {
                if (error.code == FaceSdkErrorCode.CLOSED || isFinishing || isDestroyed || completed) return
                fail(error.code.name, error.message ?: "Face detection failed")
            } catch (error: Throwable) {
                if (isFinishing || isDestroyed || completed) return
                fail("MULTI_PHOTO_FAILED", error.message ?: "Face detection failed")
            }
            return
        }
        captureRequested = false
        try {
            val recognitions = if (activeSession.roster.isEmpty()) {
                emptyList()
            } else {
                activeSession.sdk.recognize(
                    bitmap = frame,
                    profiles = activeSession.roster,
                    mode = RecognitionMode.MULTI,
                    maxFaces = activeSession.maxFaces,
                    threshold = activeSession.threshold,
                )
            }
            if (isFinishing || isDestroyed || completed) return
            var frameUnrecognized = 0
            var newlyScanned = 0
            recognitions.forEach { recognition ->
                if (recognition.matched && recognition.personId != null) {
                    val pId = recognition.personId!!
                    val existing = markedPresentMap[pId]
                    val existingScore = (existing?.get("score") as? Number)?.toDouble() ?: 0.0
                    if (existing == null) newlyScanned++
                    if (existing == null || recognition.score > existingScore) {
                        markedPresentMap[pId] = mapOf(
                            "personId" to pId,
                            "score" to recognition.score.toDouble(),
                            "boundingBox" to recognition.boundingBox.toChannelValue(),
                            "timestampMillis" to System.currentTimeMillis(),
                        )
                    }
                } else {
                    frameUnrecognized++
                    unrecognizedFaces[java.util.UUID.randomUUID()] = recognition.toUnrecognizedFaceMap()
                }
            }
            saveLowQualityJpeg(frame)?.let { path ->
                capturedPhotoPaths.add(path)
            }
            if (newlyScanned > 0) scanFeedback()
            unrecognizedCount += frameUnrecognized
            photosCapturedCount++

            val (width, height) = frame.outputDimensions()
            val faces = recognitions.map { it.boundingBox }
            val totalRoster = activeSession.roster.size
            val presentCount = markedPresentMap.size

            runOnUiThread {
                finishButton?.text = finishLabel(presentCount)
                triggerCaptureFlash()
                overlay.update(
                    faces,
                    width,
                    height,
                    recognitions.map { recognition ->
                        formatFaceLabel(
                            matched = recognition.matched && recognition.personId != null,
                            personId = recognition.personId,
                            score = recognition.score,
                            showDetectedLabel = activeSession.showDetectedLabel,
                            showMatchingPercentage = activeSession.showMatchingPercentage,
                            showUnrecognizedLabel = activeSession.showUnrecognizedLabel,
                            unrecognizedLabel = activeSession.unrecognizedLabel
                        )
                    },
                    recognitions.map {
                        if (it.matched && it.personId != null) FaceState.MATCHED else FaceState.UNKNOWN
                    },
                )
                statusPill.text = "MULTI-PHOTO • ${photosCapturedCount} PHOTO(S) • $presentCount/$totalRoster PRESENT"
                statusPill.background = roundedPill(0xCC0B1422.toInt(), 0x6600E676.toInt())
                shutterButton?.apply {
                    isEnabled = true
                    alpha = 1.0f
                }
            }

            if (activeSession.autoFinish && !paused && totalRoster > 0 && presentCount >= totalRoster) {
                completeAttendanceSession("multiPhoto", activeSession.roster, activeSession.callback)
            }
        } catch (error: Throwable) {
            if (error is FaceSdkException && error.code == FaceSdkErrorCode.CLOSED) return
            if (isFinishing || isDestroyed || completed) return
            val code = (error as? FaceSdkException)?.code?.name ?: "MULTI_PHOTO_FAILED"
            fail(code, error.message ?: "Multi-photo group capture failed")
        }
    }

    private fun saveLowQualityJpeg(frame: Bitmap): String? {
        return try {
            val maxDim = 1024
            val scaledBitmap = if (frame.width > maxDim || frame.height > maxDim) {
                val scale = maxDim.toFloat() / maxOf(frame.width, frame.height)
                val newWidth = (frame.width * scale).toInt()
                val newHeight = (frame.height * scale).toInt()
                Bitmap.createScaledBitmap(frame, newWidth, newHeight, true)
            } else {
                frame
            }
            val photoFile = File(cacheDir, "icue_attendance_${System.currentTimeMillis()}_${photosCapturedCount + 1}.jpg")
            FileOutputStream(photoFile).use { out ->
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 65, out)
            }
            // The frame itself is left to GC, like every analysis frame (see IcueFaceSdk).
            if (scaledBitmap !== frame) scaledBitmap.recycle()
            photoFile.absolutePath
        } catch (_: Throwable) {
            null
        }
    }

    private fun completeAttendanceSession(
        modeStr: String,
        roster: List<IcueFaceProfile>,
        callback: IcueFaceCamera.AttendanceCallback,
    ) {
        if (completed) return
        completed = true
        val endTimeMs = System.currentTimeMillis()
        val presentList = markedPresentMap.values.toList()
        val presentIds = markedPresentMap.keys.toSet()
        val absentIds = roster.map { it.personId }.filter { !presentIds.contains(it) }

        finalAttendanceResult = mapOf(
            "present" to presentList,
            "absentPersonIds" to absentIds,
            "unrecognizedFaceCount" to unrecognizedCount,
            "unrecognizedFaces" to synchronized(unrecognizedFaces) { unrecognizedFaces.values.toList() },
            "totalRosterCount" to roster.size,
            "sessionStartTimeMs" to sessionStartTimeMs,
            "sessionEndTimeMs" to endTimeMs,
            "mode" to modeStr,
            "photosProcessed" to photosCapturedCount,
            "capturedImagePaths" to capturedPhotoPaths.toList(),
        )
        runOnUiThread {
            statusPill.text = "Attendance session complete"
            finish()
        }
    }

    private fun formatFaceLabel(
        matched: Boolean,
        personId: String?,
        score: Float,
        showDetectedLabel: Boolean,
        showMatchingPercentage: Boolean,
        showUnrecognizedLabel: Boolean,
        unrecognizedLabel: String
    ): String {
        return if (matched) {
            val parts = mutableListOf<String>()
            if (showDetectedLabel && personId != null) {
                parts.add(namesById[personId] ?: personId)
            }
            if (showMatchingPercentage) {
                parts.add("${(score * 100).toInt()}%")
            }
            parts.joinToString(" • ")
        } else {
            if (showUnrecognizedLabel) unrecognizedLabel else ""
        }
    }

    private fun IcueBoundingBox.toChannelValue() = mapOf(
        "left" to left,
        "top" to top,
        "right" to right,
        "bottom" to bottom,
        "trackingId" to trackingId,
    )

    private fun showFaces(faces: List<IcueBoundingBox>, frame: Bitmap) {
        val (width, height) = frame.outputDimensions()
        runOnUiThread {
            overlay.update(faces, width, height)
            when (faces.size) {
                0 -> {
                    statusPill.text = "⚠️ Position student face in frame"
                    statusPill.background = roundedPill(0xDD2A1800.toInt(), 0xAAFFB300.toInt())
                    shutterButton?.apply {
                        isEnabled = false
                        alpha = 0.35f
                    }
                }
                1 -> {
                    statusPill.text = "Student face locked • Tap to enroll"
                    statusPill.background = roundedPill(0xDD092418.toInt(), 0xAA00E676.toInt())
                    shutterButton?.apply {
                        isEnabled = true
                        alpha = 1.0f
                    }
                }
                else -> {
                    statusPill.text = "⚠️ Multiple students • Position single student"
                    statusPill.background = roundedPill(0xDD2A1800.toInt(), 0xAAFFB300.toInt())
                    shutterButton?.apply {
                        isEnabled = false
                        alpha = 0.35f
                    }
                }
            }
        }
    }

    private fun fail(code: String, message: String) {
        if (completed || isFinishing) return
        completed = true
        android.util.Log.e("IcueFaceCamera", "Closing camera: $code - $message")
        runOnUiThread {
            when (val activeSession = session) {
                is CameraSession.Capture -> activeSession.callback.onError(code, message)
                is CameraSession.Tracking -> activeSession.listener.onError(code, message)
                is CameraSession.LiveAttendance -> activeSession.callback.onError(code, message)
                is CameraSession.MultiPhotoAttendance -> activeSession.callback.onError(code, message)
                null -> Unit
            }
            finish()
        }
    }

    private fun notifyStopped() {
        when (val activeSession = session) {
            is CameraSession.Capture -> activeSession.callback.onCancelled()
            is CameraSession.Tracking -> activeSession.listener.onStopped()
            is CameraSession.LiveAttendance -> activeSession.callback.onCancelled()
            is CameraSession.MultiPhotoAttendance -> activeSession.callback.onCancelled()
            null -> Unit
        }
    }

    /**
     * CameraX has already converted the frame to upright RGBA in native code; this only copies
     * it into a bitmap. Front-camera frames are not mirrored: enrollment photos are unmirrored,
     * so the model must see the real face. The overlay mirrors its drawing instead.
     */
    private fun ImageProxy.toFrameBitmap(): Bitmap {
        val upright = toBitmap()
        // toBitmap() ignores the viewport crop rect; cut the frame down to what the preview shows.
        val crop = cropRect.takeIf {
            upright.width == width && upright.height == height &&
                (it.width() != width || it.height() != height)
        } ?: return upright
        val output = Bitmap.createBitmap(upright, crop.left, crop.top, crop.width(), crop.height())
        if (output !== upright) upright.recycle()
        return output
    }

    private fun Bitmap.outputDimensions(): Pair<Int, Int> = width to height

    private fun logAnalysisRate() {
        analysisFrameCount++
        val elapsedMs = System.currentTimeMillis() - analysisWindowStartMs
        if (analysisFrameCount < ANALYSIS_RATE_WINDOW_FRAMES) return
        android.util.Log.i(
            "IcueFaceCamera",
            "Tracking: %.1f fps (%d ms per frame)".format(
                analysisFrameCount * 1000f / elapsedMs,
                elapsedMs / analysisFrameCount,
            ),
        )
        analysisFrameCount = 0
        analysisWindowStartMs = System.currentTimeMillis()
    }
}

private class CameraFlipIconView(context: Context) : View(context) {
    private val density = resources.displayMetrics.density
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 2.2f * density
        strokeCap = Paint.Cap.ROUND
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val radius = width * 0.32f

        val oval = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        canvas.drawArc(oval, 200f, 130f, false, strokePaint)
        canvas.drawArc(oval, 20f, 130f, false, strokePaint)

        // Arrowhead 1 (top right)
        val p1 = Path().apply {
            moveTo(cx + radius * 0.95f, cy - radius * 0.75f)
            lineTo(cx + radius * 1.15f, cy - radius * 0.15f)
            lineTo(cx + radius * 0.45f, cy - radius * 0.3f)
            close()
        }
        canvas.drawPath(p1, fillPaint)

        // Arrowhead 2 (bottom left)
        val p2 = Path().apply {
            moveTo(cx - radius * 0.95f, cy + radius * 0.75f)
            lineTo(cx - radius * 1.15f, cy + radius * 0.15f)
            lineTo(cx - radius * 0.45f, cy + radius * 0.3f)
            close()
        }
        canvas.drawPath(p2, fillPaint)
    }
}

private class ZoomPresetButton(context: Context, val zoomValue: Float) : TextView(context) {
    private val density = resources.displayMetrics.density
    private fun dp(value: Int): Int = (value * density).toInt()

    var isPresetSelected: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                updateStyle()
            }
        }

    init {
        text = if (zoomValue == zoomValue.toInt().toFloat()) "${zoomValue.toInt()}x" else "%.1fx".format(zoomValue)
        textSize = 11f
        typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
        gravity = Gravity.CENTER
        setPadding(dp(10), dp(5), dp(10), dp(5))
        updateStyle()
    }

    private fun updateStyle() {
        if (isPresetSelected) {
            setTextColor(0xFF0B1422.toInt())
            background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(0xFF00E5FF.toInt())
            }
        } else {
            setTextColor(0xFFF1F5F9.toInt())
            background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(0x44101B2B.toInt())
                setStroke(dp(1), 0x22FFFFFF.toInt())
            }
        }
    }
}

/** [mirrored] is read on every draw: front-camera previews are mirrored, analysed frames are not. */
private class FaceOverlayView(activity: Activity, private val mirrored: () -> Boolean) : View(activity) {
    private val density = resources.displayMetrics.density

    // Animators
    private var scanProgress = 0f
    private var pulseProgress = 1f
    private val scanAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 1800
        repeatMode = ValueAnimator.REVERSE
        repeatCount = ValueAnimator.INFINITE
        interpolator = AccelerateDecelerateInterpolator()
        addUpdateListener {
            scanProgress = it.animatedValue as Float
            invalidate()
        }
    }
    private val pulseAnimator = ValueAnimator.ofFloat(0.92f, 1.05f).apply {
        duration = 1200
        repeatMode = ValueAnimator.REVERSE
        repeatCount = ValueAnimator.INFINITE
        interpolator = AccelerateDecelerateInterpolator()
        addUpdateListener {
            pulseProgress = it.animatedValue as Float
            invalidate()
        }
    }

    init {
        scanAnimator.start()
        pulseAnimator.start()
    }

    // Paints
    private val reticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x8800E5FF.toInt()
        style = Paint.Style.STROKE
        strokeWidth = 2f * density
        pathEffect = DashPathEffect(floatArrayOf(12f * density, 8f * density), 0f)
    }

    private val reticleTickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF00E5FF.toInt()
        style = Paint.Style.STROKE
        strokeWidth = 3f * density
        strokeCap = Paint.Cap.ROUND
    }

    private val reticleTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xDD00E5FF.toInt()
        textSize = 11f * density
        typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
        textAlign = Paint.Align.CENTER
        letterSpacing = 0.15f
    }

    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x4400E5FF.toInt()
        style = Paint.Style.STROKE
        strokeWidth = 12f * density
        strokeCap = Paint.Cap.ROUND
    }

    private val bracketPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF00E5FF.toInt()
        style = Paint.Style.STROKE
        strokeWidth = 3f * density
        strokeCap = Paint.Cap.ROUND
    }

    private val scanLinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF00E5FF.toInt()
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * density
        strokeCap = Paint.Cap.ROUND
    }

    private val labelBackgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xEE0B1422.toInt()
        style = Paint.Style.FILL
    }

    private val labelStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x6600E5FF.toInt()
        style = Paint.Style.STROKE
        strokeWidth = 1f * density
    }

    private val labelTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 12f * density
        typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
    }

    private val tintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val badgeRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 2f * density
    }
    private val badgeIconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val trailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val badgePath = Path()

    private var faces: List<IcueBoundingBox> = emptyList()
    private var labels: List<String?> = emptyList()
    private var states: List<FaceState> = emptyList()
    private var sourceWidth = 1
    private var sourceHeight = 1

    // When each face entered its current state, keyed by trackingId (or index), for the badge pop-in.
    private val stateSince = HashMap<Any, Pair<FaceState, Long>>()

    fun update(
        newFaces: List<IcueBoundingBox>,
        width: Int,
        height: Int,
        newLabels: List<String?> = emptyList(),
        newStates: List<FaceState> = emptyList(),
    ) {
        faces = newFaces
        labels = newLabels
        states = newStates
        sourceWidth = width.coerceAtLeast(1)
        sourceHeight = height.coerceAtLeast(1)
        val now = System.currentTimeMillis()
        val seen = HashSet<Any>()
        newFaces.forEachIndexed { index, face ->
            val key: Any = face.trackingId ?: index
            seen += key
            val state = newStates.getOrNull(index) ?: FaceState.SCANNING
            if (stateSince[key]?.first != state) stateSince[key] = state to now
        }
        stateSince.keys.retainAll(seen)
        invalidate()
    }

    override fun onDetachedFromWindow() {
        scanAnimator.cancel()
        pulseAnimator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val scale = maxOf(width.toFloat() / sourceWidth, height.toFloat() / sourceHeight)
        val offsetX = (width - sourceWidth * scale) / 2f
        val offsetY = (height - sourceHeight * scale) / 2f

        if (faces.isEmpty()) {
            drawCenterReticle(canvas)
        } else {
            faces.forEachIndexed { index, face ->
                val left = if (mirrored()) sourceWidth - face.right else face.left
                val right = if (mirrored()) sourceWidth - face.left else face.right
                val rect = RectF(
                    offsetX + left * scale,
                    offsetY + face.top * scale,
                    offsetX + right * scale,
                    offsetY + face.bottom * scale,
                )
                val label = labels.getOrNull(index)
                val state = states.getOrNull(index) ?: FaceState.SCANNING
                val mainColor = when (state) {
                    FaceState.MATCHED -> COLOR_MATCHED
                    FaceState.UNKNOWN -> COLOR_UNKNOWN
                    FaceState.SCANNING -> COLOR_SCANNING
                }

                bracketPaint.color = mainColor
                glowPaint.color = (mainColor and 0x00FFFFFF) or 0x33000000
                scanLinePaint.color = mainColor

                if (state != FaceState.SCANNING) {
                    tintPaint.color = (mainColor and 0x00FFFFFF) or 0x1F000000
                    val cornerRadius = 14f * density
                    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, tintPaint)
                }
                drawCyberBrackets(canvas, rect)
                if (state == FaceState.SCANNING) drawLaserScanLine(canvas, rect)
                label?.takeIf { it.isNotBlank() }?.let { text ->
                    drawCyberLabel(canvas, rect, text, mainColor)
                }
                if (state != FaceState.SCANNING) {
                    val sinceMs = stateSince[face.trackingId ?: index]?.second ?: 0L
                    drawStatusBadge(canvas, rect, state, mainColor, sinceMs)
                }
            }
        }
    }

    private fun drawCenterReticle(canvas: Canvas) {
        val centerX = width / 2f
        val centerY = height * 0.42f
        val rx = (width * 0.32f) * pulseProgress
        val ry = (width * 0.42f) * pulseProgress

        val oval = RectF(centerX - rx, centerY - ry, centerX + rx, centerY + ry)
        canvas.drawOval(oval, reticlePaint)

        // Draw crosshair corner marks
        val tickLen = 20f * density
        // Top
        canvas.drawLine(centerX, oval.top - tickLen, centerX, oval.top + tickLen, reticleTickPaint)
        // Bottom
        canvas.drawLine(centerX, oval.bottom - tickLen, centerX, oval.bottom + tickLen, reticleTickPaint)
        // Left
        canvas.drawLine(oval.left - tickLen, centerY, oval.left + tickLen, centerY, reticleTickPaint)
        // Right
        canvas.drawLine(oval.right - tickLen, centerY, oval.right + tickLen, centerY, reticleTickPaint)

        // Scanning beam through center reticle
        val scanY = oval.top + (oval.height() * scanProgress)
        canvas.drawLine(oval.left + 10f * density, scanY, oval.right - 10f * density, scanY, scanLinePaint)

        canvas.drawText("ALIGN STUDENT FACE WITHIN RETICLE", centerX, oval.bottom + 36f * density, reticleTextPaint)
    }

    private fun drawCyberBrackets(canvas: Canvas, rect: RectF) {
        val length = (minOf(rect.width(), rect.height()) * 0.24f)
            .coerceIn(20f * density, 48f * density)

        // Draw ambient glow outer
        canvas.drawRect(rect, glowPaint)

        // Draw corner tech brackets
        // Top-Left
        canvas.drawLine(rect.left, rect.top, rect.left + length, rect.top, bracketPaint)
        canvas.drawLine(rect.left, rect.top, rect.left, rect.top + length, bracketPaint)
        // Top-Right
        canvas.drawLine(rect.right, rect.top, rect.right - length, rect.top, bracketPaint)
        canvas.drawLine(rect.right, rect.top, rect.right, rect.top + length, bracketPaint)
        // Bottom-Left
        canvas.drawLine(rect.left, rect.bottom, rect.left + length, rect.bottom, bracketPaint)
        canvas.drawLine(rect.left, rect.bottom, rect.left, rect.bottom - length, bracketPaint)
        // Bottom-Right
        canvas.drawLine(rect.right, rect.bottom, rect.right - length, rect.bottom, bracketPaint)
        canvas.drawLine(rect.right, rect.bottom, rect.right, rect.bottom - length, bracketPaint)
    }

    private fun drawLaserScanLine(canvas: Canvas, rect: RectF) {
        val scanY = rect.top + (rect.height() * scanProgress)
        val pad = 4f * density
        canvas.drawLine(rect.left + pad, scanY, rect.right - pad, scanY, scanLinePaint)

        // Draw trailing beam gradient above/below scan line
        val trailHeight = 18f * density
        val gradientShader = LinearGradient(
            0f, scanY - trailHeight, 0f, scanY,
            intArrayOf(Color.TRANSPARENT, (scanLinePaint.color and 0x00FFFFFF) or 0x44000000),
            null,
            Shader.TileMode.CLAMP
        )
        trailPaint.shader = gradientShader
        canvas.drawRect(rect.left + pad, scanY - trailHeight, rect.right - pad, scanY, trailPaint)
    }

    /** Circular ✓ (recognized) or ! (unrecognized) badge on the face's top-right corner, with an overshoot pop-in. */
    private fun drawStatusBadge(canvas: Canvas, rect: RectF, state: FaceState, color: Int, sinceMs: Long) {
        val progress = ((System.currentTimeMillis() - sinceMs) / BADGE_POP_MS.toFloat()).coerceIn(0f, 1f)
        // Overshoot ease-out: grows past 1.0, then settles.
        val remaining = progress - 1f
        val pop = 1f + 2.2f * remaining * remaining * remaining + 1.2f * remaining * remaining
        val radius = (minOf(rect.width(), rect.height()) * 0.11f).coerceIn(13f * density, 22f * density) * pop
        if (radius <= 0f) return
        val centerX = rect.right.coerceAtMost(width - radius - 4f * density)
        val centerY = rect.top.coerceAtLeast(radius + 4f * density)

        badgePaint.color = (color and 0x00FFFFFF) or 0x55000000
        canvas.drawCircle(centerX, centerY, radius * 1.35f, badgePaint)
        badgePaint.color = color
        canvas.drawCircle(centerX, centerY, radius, badgePaint)
        canvas.drawCircle(centerX, centerY, radius, badgeRingPaint)

        badgeIconPaint.strokeWidth = radius * 0.22f
        if (state == FaceState.MATCHED) {
            badgePath.reset()
            badgePath.moveTo(centerX - radius * 0.45f, centerY + radius * 0.02f)
            badgePath.lineTo(centerX - radius * 0.12f, centerY + radius * 0.35f)
            badgePath.lineTo(centerX + radius * 0.48f, centerY - radius * 0.32f)
            canvas.drawPath(badgePath, badgeIconPaint)
        } else {
            // ✕: "not on this list", clearer for helpers than an exclamation mark.
            val arm = radius * 0.38f
            canvas.drawLine(centerX - arm, centerY - arm, centerX + arm, centerY + arm, badgeIconPaint)
            canvas.drawLine(centerX - arm, centerY + arm, centerX + arm, centerY - arm, badgeIconPaint)
        }
    }

    private fun drawCyberLabel(canvas: Canvas, faceRect: RectF, label: String, strokeColor: Int) {
        val horizontalPadding = 12f * density
        val verticalPadding = 8f * density
        val displayLabel = ellipsizeLabel(label, width - 16f * density - horizontalPadding * 2)
        val textWidth = labelTextPaint.measureText(displayLabel)
        val metrics = labelTextPaint.fontMetrics
        val labelHeight = metrics.descent - metrics.ascent + verticalPadding * 2
        val labelWidth = textWidth + horizontalPadding * 2
        val left = faceRect.left.coerceIn(8f * density, width - labelWidth - 8f * density)
        val preferredTop = faceRect.top - labelHeight - 12f * density
        val top = if (preferredTop >= 8f * density) preferredTop else faceRect.top + 12f * density
        val labelRect = RectF(left, top, left + labelWidth, top + labelHeight)

        labelStrokePaint.color = (strokeColor and 0x00FFFFFF) or 0x66000000
        canvas.drawRoundRect(labelRect, 10f * density, 10f * density, labelBackgroundPaint)
        canvas.drawRoundRect(labelRect, 10f * density, 10f * density, labelStrokePaint)

        canvas.drawText(
            displayLabel,
            labelRect.left + horizontalPadding,
            labelRect.top + verticalPadding - metrics.ascent,
            labelTextPaint,
        )
    }

    private fun ellipsizeLabel(label: String, availableWidth: Float): String {
        if (labelTextPaint.measureText(label) <= availableWidth) return label
        val ellipsis = "…"
        var end = label.length
        while (end > 0 && labelTextPaint.measureText(label.substring(0, end) + ellipsis) > availableWidth) {
            end--
        }
        return label.substring(0, end) + ellipsis
    }

    private companion object {
        const val COLOR_MATCHED = 0xFF00E676.toInt()
        const val COLOR_UNKNOWN = 0xFFFF2A54.toInt()
        const val COLOR_SCANNING = 0xFF00E5FF.toInt()
        const val BADGE_POP_MS = 320L
    }
}

internal enum class FaceState { SCANNING, MATCHED, UNKNOWN }
