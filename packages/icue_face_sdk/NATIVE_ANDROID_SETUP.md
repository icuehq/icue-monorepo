# iCue Face SDK - Native Android Setup & Integration Guide

This guide provides step-by-step instructions for integrating the **iCue Face SDK** binary package (`icue-face-core-release.aar`) into any native Android application (Kotlin / Java).

---

## 📋 Prerequisites & Requirements

| Specification | Minimum Requirement |
| :--- | :--- |
| **Android Version** | Android 7.0 (API Level 24) or higher |
| **Compile SDK** | API Level 34 or higher |
| **Java Version** | Java 17 |
| **Kotlin Version** | 1.9.0 or higher |
| **Hardware** | Device with Camera (Front or Rear) |

---

## 📦 Step 1: Copy the AAR File into Your Android Project

1. Obtain the built `icue-face-core-release.aar` file.
2. In your Android project, navigate to the `app` module directory.
3. If a `libs` folder does not exist inside `app/`, create one: `app/libs`.
4. Copy `icue-face-core-release.aar` into `app/libs/`.

Your project structure should look like this:
```
YourAndroidApp/
├── app/
│   ├── libs/
│   │   └── icue-face-core-release.aar
│   ├── src/
│   └── build.gradle.kts  (or build.gradle)
├── settings.gradle.kts
└── build.gradle.kts
```

---

## ⚙️ Step 2: Configure Dependencies

Because raw `.aar` files do not resolve transitive dependencies automatically, you must declare both the local `.aar` file and its required underlying dependencies in your app's build configuration.

### Option A: Using Kotlin DSL (`app/build.gradle.kts`)

Open `app/build.gradle.kts` and add the following inside the `dependencies` block:

```kotlin
dependencies {
    // 1. Include the iCue Face SDK binary
    implementation(files("libs/icue-face-core-release.aar"))

    // 2. Core Android & Lifecycle dependencies
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.activity:activity-ktx:1.12.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")

    // 3. CameraX dependencies (required for built-in camera UI & frame pipeline)
    implementation("androidx.camera:camera-camera2:1.6.1")
    implementation("androidx.camera:camera-lifecycle:1.6.1")
    implementation("androidx.camera:camera-view:1.6.1")

    // 4. ML Kit Face Detection
    implementation("com.google.android.gms:play-services-mlkit-face-detection:17.1.0")

    // 5. LiteRT / TensorFlow Lite Runtime (Model Inference Engine)
    implementation("com.google.ai.edge.litert:litert-api:2.1.6")
    implementation("com.google.ai.edge.litert:litert:2.1.6")
}
```

Ensure your `android` configuration block specifies Java 17 compatibility:

```kotlin
android {
    compileSdk = 36 // or minimum 34

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // Recommended: Prevent Gradle from compressing the embedded model file
    androidResources {
        noCompress += "tflite"
    }
}
```

---

### Option B: Using Groovy DSL (`app/build.gradle`)

If your project uses Groovy `build.gradle`:

```groovy
dependencies {
    // 1. Include the iCue Face SDK binary
    implementation files('libs/icue-face-core-release.aar')

    // 2. Transitive dependencies
    implementation 'androidx.core:core-ktx:1.17.0'
    implementation 'androidx.activity:activity-ktx:1.12.3'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2'
    implementation 'org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2'

    implementation 'androidx.camera:camera-camera2:1.6.1'
    implementation 'androidx.camera:camera-lifecycle:1.6.1'
    implementation 'androidx.camera:camera-view:1.6.1'

    implementation 'com.google.android.gms:play-services-mlkit-face-detection:17.1.0'

    implementation 'com.google.ai.edge.litert:litert-api:2.1.6'
    implementation 'com.google.ai.edge.litert:litert:2.1.6'
}
```

---

## 🔒 Step 3: Android Manifest & Permissions

Open `app/src/main/AndroidManifest.xml` and declare camera permission inside the `<manifest>` tag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Camera permission for face capture & tracking -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />

    <application
        ... >
    </application>

</manifest>
```

---

## 🚀 Step 4: Kotlin Code Usage Guide

### 1. Initialize the SDK
Initialize the SDK once in your Activity, Fragment, or ViewModel lifecycle:

```kotlin
import school.icue.face.core.IcueFaceSdk
import school.icue.face.core.model.FaceSdkConfig
import school.icue.face.core.model.FaceSdkAccelerator

class MainActivity : AppCompatActivity() {

    private lateinit var faceSdk: IcueFaceSdk

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Initialize SDK facade
        faceSdk = IcueFaceSdk(
            context = applicationContext,
            config = FaceSdkConfig(
                accelerator = FaceSdkAccelerator.CPU, // CPU (default), GPU, or NPU
                numThreads = 4                        // Recommended thread count
            )
        )
    }
}
```

---

### 2. Extract Embedding from a Bitmap (Enrollment Flow)
Extract a normalized **192-value `FloatArray` biometric embedding** from a static image (must contain **exactly 1 face**):

```kotlin
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import school.icue.face.core.model.IcueFaceSdkException

fun enrollUser(bitmap: Bitmap) {
    lifecycleScope.launch {
        try {
            // Extract 192-float vector embedding
            val embedding: FloatArray = faceSdk.extractEmbedding(bitmap)
            
            Log.d("FaceSDK", "Embedding extracted successfully. Dimensions: ${embedding.size}")
            // Store embedding securely (e.g. EncryptedSharedPreferences or encrypted database)
            
        } catch (e: IcueFaceSdkException) {
            Log.e("FaceSDK", "Embedding extraction failed: ${e.code} - ${e.message}")
            // Possible error codes: NO_FACES_DETECTED, MULTIPLE_FACES_DETECTED, FRAME_BUSY
        }
    }
}
```

---

### 3. Face Recognition / Verification (Matching Flow)
Compare a face image against stored profiles using cosine-similarity (default matching threshold: `0.68`):

```kotlin
import school.icue.face.core.model.IcueFaceProfile
import school.icue.face.core.model.RecognitionMode
import school.icue.face.core.model.IcueRecognitionResult

fun recognizeStudent(bitmap: Bitmap, savedProfiles: List<IcueFaceProfile>) {
    lifecycleScope.launch {
        try {
            val results: List<IcueRecognitionResult> = faceSdk.recognize(
                bitmap = bitmap,
                profiles = savedProfiles, // Pre-enrolled profiles: list of IcueFaceProfile(personId, embedding)
                mode = RecognitionMode.SINGLE
            )

            for (result in results) {
                if (result.matched) {
                    Log.d("FaceSDK", "Matched Person: ${result.personId} with score: ${result.score}")
                } else {
                    Log.d("FaceSDK", "No matching profile found. Best score: ${result.score}")
                }
            }
        } catch (e: IcueFaceSdkException) {
            Log.e("FaceSDK", "Recognition error: ${e.message}")
        }
    }
}
```

---

### 4. SDK-Owned Camera UI (`IcueFaceCamera`)
The SDK includes a built-in full-screen CameraX preview activity. It handles camera permission verification, auto-detects faces, extracts embeddings, and returns results via a callback:

```kotlin
import school.icue.face.core.camera.IcueFaceCamera
import school.icue.face.core.camera.IcueCameraLens

fun startCameraCapture() {
    IcueFaceCamera.openCapture(
        activity = this,
        sdk = faceSdk,
        lens = IcueCameraLens.FRONT, // IcueCameraLens.FRONT or IcueCameraLens.BACK
        callback = object : IcueFaceCamera.CaptureCallback {
            
            override fun onCaptured(embedding: FloatArray) {
                // Returns 192-float array when exactly 1 face is aligned and captured
                Log.d("FaceSDK", "Camera captured embedding! Vector length: ${embedding.size}")
            }

            override fun onCancelled() {
                // Triggered when user closes or dismisses the camera activity
                Log.d("FaceSDK", "User cancelled camera capture")
            }

            override fun onError(code: String, message: String) {
                // Triggered if camera fails or inference error occurs
                Log.e("FaceSDK", "Camera Error ($code): $message")
            }
        }
    )
}
```

---

### 5. SDK Resource Cleanup
Always close the SDK instance when the owning Activity/ViewModel is destroyed to release LiteRT tensor buffers and ML Kit detectors:

```kotlin
override fun onDestroy() {
    super.onDestroy()
    lifecycleScope.launch {
        faceSdk.close()
    }
}
```

---

## 🛠️ Summary of Key Data Classes

| Class | Description |
| :--- | :--- |
| `IcueFaceSdk` | Main SDK facade. Thread-safe manager for face detection & recognition. |
| `FaceSdkConfig` | Configuration object: `accelerator` (`CPU`, `GPU`, `NPU`), `numThreads` (Int). |
| `IcueFaceProfile` | Enrolled user representation: `personId: String`, `embedding: FloatArray` (192 values). |
| `IcueRecognitionResult` | Output of matching: `personId: String?`, `score: Float`, `matched: Boolean`. |
| `IcueFaceCamera` | Camera entry point for opening built-in capture UI or live frame tracking. |
| `IcueFaceSdkException` | Domain exception class containing error `code: String` and `message: String`. |

---

## 💡 Troubleshooting & Best Practices

1. **`FRAME_BUSY` Exception**:
   - The SDK processes one frame at a time. If an operation is already in progress, drop incoming frames instead of queuing them.
2. **Biometric Security**:
   - Biometric embeddings (192 float values) should be stored in **encrypted storage** (e.g. Android `EncryptedSharedPreferences` or Encrypted Room database). Do not log embeddings or store them in plaintext.
3. **CameraX Conflicts**:
   - Ensure your application uses Compatible CameraX dependencies (`1.6.x` series recommended).
