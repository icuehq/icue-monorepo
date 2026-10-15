# iCue Face SDK — Consumer Integration Guide: Attendance & Transport Scanning

This guide provides end-to-end instructions for consumer applications (e.g., School Admin, Bus Attendant, Teacher Portal) to implement facial recognition scanning using `icue_face_sdk`.

---

## Table of Contents
1. [Overview](#1-overview)
2. [Key Concepts & Behavioral Contract](#2-key-concepts--behavioral-contract)
3. [Step-by-Step Implementation](#3-step-by-step-implementation)
   - [Step 1: Initialize the Face SDK](#step-1-initialize-the-face-sdk)
   - [Step 2: Prepare Roster Face Profiles](#step-2-prepare-roster-face-profiles)
   - [Step 3: Configure Attendance Settings (`AttendanceConfig`)](#step-3-configure-attendance-settings-attendanceconfig)
   - [Step 4: Launch Live Camera Sweep](#step-4-launch-live-camera-sweep)
   - [Step 5: Process Results: Success Students vs. Unknown Students](#step-5-process-results-success-students-vs-unknown-students)
   - [Step 6: Display the Unknown Student Alert Dialog](#step-6-display-the-unknown-student-alert-dialog)
4. [Alternative Scan Modes (Multi-Photo & Single-Photo)](#4-alternative-scan-modes)
5. [Complete Working Example](#5-complete-working-example)
6. [API Reference](#6-api-reference)
7. [Best Practices & Troubleshooting](#7-best-practices--troubleshooting)

---

## 1. Overview

The `icue_face_sdk` provides on-device biometric face detection, face tracking, and MobileFaceNet recognition for Flutter iOS and Android apps. 

All neural network inference runs 100% locally on the device (via LiteRT / TFLite and ML Kit). Images and biometric embeddings never leave the device.

### Supported Use Cases
- 🚌 **Bus Transport Attendance (`AttendanceType.TRANSPORT`)**: Scans students boarding a school bus. Verifies if students belong to this bus route and alerts if an unknown/cross-bus student attempts to board.
- 🏫 **Classroom Attendance (`AttendanceType.ATTENDANCE`)**: Scans students entering a classroom or assembly, automatically marking them present and flagging unrecognized visitors.

---

## 2. Key Concepts & Behavioral Contract

### The SDK vs. Consumer App Responsibility
```
┌───────────────────────────────────────────────┐
│              iCue Face SDK                    │
│  - Full-screen native CameraX / AVFoundation  │
│  - Real-time face tracking & cyber reticle    │
│  - 2.2s temporal stabilization window         │
│  - Bright green overlay on student match      │
│  - Snapshot capture on unknown student        │
│  - Auto-navigation back to app on unknown     │
└───────────────────────┬───────────────────────┘
                        │ returns AttendanceResult
┌───────────────────────▼───────────────────────┐
│               Consumer App                    │
│  - Success students: update roster silently   │
│  - Unknown student: display modal alert       │
│  - Render captured photo & match details      │
│  - Business actions (Notify dispatch / Flag)  │
└───────────────────────────────────────────────┘
```

### 1. Face Tracking & Temporal Stabilization
In live camera feeds, faces require a fraction of a second to align, adjust to lighting, and produce a high-confidence biometric match.
- **Scanning Feedback**: When a face is detected, the camera draws an animated reticle with laser scanning lines and the status label **`"SCANNING... HOLD STILL"`**.
- **Immediate Match**: As soon as a valid student aligns (typically within 100–300ms), the reticle turns **bright green**, displays the student's name/ID with match score (e.g., `EMILY PARKER • 92%`), and marks them present. The camera remains open and tracking continues.
- **Stabilization Window**: If a face is continuously observed for **≥ 2.2 seconds (over 12+ frames)** without matching any roster profile, the SDK concludes the person is truly unknown.

### 2. Auto-Navigation on Unknown Face Detection
- When an unknown person is confirmed after the 2.2-second stabilization window:
  1. The SDK saves an on-device JPEG snapshot of the camera frame.
  2. The SDK populates `UnrecognizedFaceRecord` with `sourceImagePath`, confidence score, timestamp, and bounding box.
  3. The native camera activity **automatically finishes and navigates back** to your Flutter screen.
  4. Your app receives the `AttendanceResult` and pops up your alert dialog.

### 3. Success-Only Students (No Dialog)
- When all scanned faces match enrolled students, the camera stays open until the user taps **✓ FINISH ATTENDANCE** (or all students in the roster are accounted for).
- When returning to the app with only recognized students (`unrecognizedFaceCount == 0`), **no dialog is displayed**. The app simply updates attendance records.

---

## 3. Step-by-Step Implementation

### Step 1: Initialize the Face SDK

Initialize the SDK once in your application service or screen `initState()`:

```dart
import 'package:icue_face_sdk/icue_face_sdk.dart';

final _faceSdk = IcueFaceSdk();

@override
void initState() {
  super.initState();
  _initSdk();
}

Future<void> _initSdk() async {
  await _faceSdk.initialize(
    config: const FaceSdkConfig(
      accelerator: FaceSdkAccelerator.cpu,
      numThreads: 4,
    ),
  );
}

@override
void dispose() {
  _faceSdk.dispose();
  super.dispose();
}
```

---

### Step 2: Prepare Roster Face Profiles

To match students, provide a list of `FaceProfile` objects. Each profile contains the student's unique ID, their 192-float biometric embedding (enrolled earlier), and optional display fields:

```dart
final rosterProfiles = <FaceProfile>[
  FaceProfile(
    personId: 'STU-1001',
    embedding: studentOneEmbedding, // List<double> of 192 floats
    name: 'Emily Parker',
    label: 'Grade 5 - Bus A',
  ),
  FaceProfile(
    personId: 'STU-1002',
    embedding: studentTwoEmbedding,
    name: 'David Chen',
    label: 'Grade 5 - Bus A',
  ),
];
```

> **Note**: If `name` or `label` are omitted, the SDK falls back to displaying `personId`.

---

### Step 3: Configure Attendance Settings (`AttendanceConfig`)

Customize the camera interface, label sizes, detection labels, and mode:

```dart
final config = AttendanceConfig(
  // 1. Context Type: TRANSPORT (default) or ATTENDANCE
  type: AttendanceType.TRANSPORT,

  // 2. Control overlay font size for student name/ID
  fontSize: 13.0,

  // 3. Control which label field is displayed over detected faces:
  //    DetectedLabelField.NAME -> Emily Parker
  //    DetectedLabelField.ID   -> STU-1001
  //    DetectedLabelField.LABEL -> Grade 5 - Bus A
  //    DetectedLabelField.NAME_AND_ID -> Emily Parker (STU-1001)
  detectedLabelField: DetectedLabelField.NAME,

  // 4. Custom warning text when an unknown student is detected
  unrecognizedLabel: 'NOT IN THIS BUS',

  // 5. Visual toggles
  showDetectedLabel: true,
  showMatchingPercentage: true,
  showUnrecognizedLabel: true,

  // 6. Camera hardware settings
  lens: CameraLens.back,
  threshold: 0.68, // Default cosine-similarity threshold
);
```

---

### Step 4: Launch Live Camera Sweep

Call `startLiveAttendance` passing the student roster and config. The SDK handles camera permissions, opens the full-screen viewfinder, and tracks faces:

```dart
Future<void> scanLiveAttendance() async {
  try {
    final result = await _faceSdk.startLiveAttendance(
      roster: rosterProfiles,
      config: config,
    );

    if (result != null) {
      _handleAttendanceResult(result);
    }
  } on IcueFaceSdkException catch (e) {
    debugPrint('Face SDK Error: ${e.code} - ${e.message}');
  }
}
```

---

### Step 5: Process Results: Success Students vs. Unknown Students

When the camera session finishes and control returns to Flutter:
1. Extract recognized students from `result.present`.
2. Inspect `result.hasUnrecognizedFaces` (or `result.unrecognizedFaceCount > 0`).
3. If unknown faces exist, display your alert dialog.
4. If only success students exist, **do not display any dialog**.

```dart
void _handleAttendanceResult(AttendanceResult result) {
  // 1. Process recognized students
  final presentIds = result.present.map((r) => r.personId).toSet();
  debugPrint('Recognized ${presentIds.length} student(s) as present');

  // 2. Handle Unknown Students
  if (result.hasUnrecognizedFaces || result.unrecognizedFaceCount > 0) {
    // Show alert dialog because an unknown student was detected
    _showUnrecognizedStudentAlert(result);
  } else {
    // Success only: Do NOT show any dialog. Just confirm in UI.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance recorded: ${presentIds.length} student(s) marked present.'),
        backgroundColor: const Color(0xFF00E676),
      ),
    );
  }
}
```

---

### Step 6: Display the Unknown Student Alert Dialog

When `result.unrecognizedFaceCount > 0`, display a modal dialog with the captured photo (`sourceImagePath`) and student details:

```dart
import 'dart:io';

void _showUnrecognizedStudentAlert(AttendanceResult result) {
  final firstUnknown = result.unrecognizedFaces.isNotEmpty
      ? result.unrecognizedFaces.first
      : null;

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF130F26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB300), size: 28),
          SizedBox(width: 10),
          Text(
            'Bus Transport Alert',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This student does not belong to this Bus.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Display the captured snapshot thumbnail if available
          if (firstUnknown?.sourceImagePath != null &&
              File(firstUnknown!.sourceImagePath!).existsSync()) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(firstUnknown.sourceImagePath!),
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],

          Text(
            'Confidence Score: ${((firstUnknown?.confidenceScore ?? 0) * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            'Detected at: ${firstUnknown?.timestamp.toLocal().toString().split('.').first}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('DISMISS', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300)),
          onPressed: () {
            Navigator.of(ctx).pop();
            // Trigger dispatch notification or exception logging
            _notifyTransportDispatch(result);
          },
          child: const Text('NOTIFY DISPATCH', style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}
```

---

## 4. Alternative Scan Modes

In addition to live camera sweeping, `icue_face_sdk` supports photo-based scanning:

### Multi-Photo Group Attendance
Allows capturing multiple still photos of a crowd or classroom:
```dart
final result = await _faceSdk.startMultiPhotoAttendance(
  roster: rosterProfiles,
  config: AttendanceConfig(
    type: AttendanceType.TRANSPORT,
    fontSize: 12.0,
  ),
);
```

### Single Photo Recognition
Analyzes an image from gallery or file path:
```dart
final recognitions = await _faceSdk.recognize(
  imagePath: pickedFile.path,
  profiles: rosterProfiles,
  mode: RecognitionMode.multi,
  threshold: 0.68,
);
```

---

## 5. Complete Working Example

Below is a self-contained Flutter widget demonstrating the complete pattern:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';

class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  final _faceSdk = IcueFaceSdk();
  final List<FaceProfile> _roster = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupSdk();
  }

  Future<void> _setupSdk() async {
    await _faceSdk.initialize(
      config: const FaceSdkConfig(
        accelerator: FaceSdkAccelerator.cpu,
        numThreads: 4,
      ),
    );
    // Populate your enrolled student roster from local database or API
    _roster.addAll(await _loadEnrolledRoster());
    setState(() => _isInitialized = true);
  }

  Future<List<FaceProfile>> _loadEnrolledRoster() async {
    // Return registered students with their 192-float embeddings
    return [];
  }

  Future<void> _startSweep() async {
    if (!_isInitialized) return;

    final result = await _faceSdk.startLiveAttendance(
      roster: _roster,
      config: const AttendanceConfig(
        type: AttendanceType.TRANSPORT,
        fontSize: 13.0,
        detectedLabelField: DetectedLabelField.NAME,
        unrecognizedLabel: 'NOT IN THIS BUS',
      ),
    );

    if (result != null) {
      _processResult(result);
    }
  }

  void _processResult(AttendanceResult result) {
    if (result.hasUnrecognizedFaces || result.unrecognizedFaceCount > 0) {
      _showUnknownStudentDialog(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All ${result.present.length} student(s) verified!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showUnknownStudentDialog(AttendanceResult result) {
    final firstUnknown = result.unrecognizedFaces.firstOrNull;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Transport Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This student does not belong to this Bus.'),
            const SizedBox(height: 10),
            if (firstUnknown?.sourceImagePath != null &&
                File(firstUnknown!.sourceImagePath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(firstUnknown.sourceImagePath!),
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _faceSdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bus Attendance Scanner')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _startSweep,
          icon: const Icon(Icons.camera_alt),
          label: const Text('START LIVE SCANNER'),
        ),
      ),
    );
  }
}
```

---

## 6. API Reference

### `AttendanceConfig`

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `type` | `AttendanceType` | `AttendanceType.TRANSPORT` | Operational context: `TRANSPORT` or `ATTENDANCE`. |
| `fontSize` | `double?` | `12.0` | Font size (in sp/dp) for student Name/ID on camera overlay. |
| `detectedLabelField` | `DetectedLabelField` | `DetectedLabelField.ID` | Field displayed over recognized faces: `ID`, `NAME`, `LABEL`, or `NAME_AND_ID`. |
| `unrecognizedLabel` | `String` | `'UNREGISTERED STUDENT'` | Warning label displayed over faces that fail to match. |
| `threshold` | `double` | `0.68` | Cosine similarity threshold (0.0 to 1.0) for biometric match. |
| `lens` | `CameraLens` | `CameraLens.back` | Default camera sensor (`back` or `front`). |
| `autoFinishWhenComplete` | `bool` | `false` | Automatically closes camera once 100% of roster is present. |
| `showDetectedLabel` | `bool` | `true` | Shows student label banner over detected faces. |
| `showMatchingPercentage` | `bool` | `true` | Displays match similarity % (e.g. `92%`) on overlay. |
| `showUnrecognizedLabel` | `bool` | `true` | Displays warning text on unrecognized faces. |

---

### `AttendanceResult`

| Property | Type | Description |
| :--- | :--- | :--- |
| `present` | `List<AttendanceRecord>` | List of recognized students marked present with scores and timestamps. |
| `absentPersonIds` | `List<String>` | List of enrolled student IDs from the roster who were not detected. |
| `unrecognizedFaceCount`| `int` | Total count of unknown faces detected. |
| `unrecognizedFaces` | `List<UnrecognizedFaceRecord>`| Detailed records of unknown student faces. |
| `hasUnrecognizedFaces` | `bool` | Helper property returning `true` if `unrecognizedFaceCount > 0`. |
| `mode` | `AttendanceMode` | Scan mode: `liveStream`, `multiPhoto`, or `batchImages`. |
| `sessionStartTime` | `DateTime` | Timestamp when camera session started. |
| `sessionEndTime` | `DateTime` | Timestamp when camera session concluded. |

---

### `UnrecognizedFaceRecord`

| Property | Type | Description |
| :--- | :--- | :--- |
| `confidenceScore` | `double` | Highest matching score against roster (e.g. nearest enrolled face). |
| `sourceImagePath` | `String?` | On-device file path to the captured snapshot JPEG of the unknown face. |
| `boundingBox` | `FaceBoundingBox?` | Bounding box coordinates of the face in the camera frame. |
| `timestamp` | `DateTime` | Timestamp when the face was detected. |

---

## 7. Best Practices & Troubleshooting

1. **Camera Distance & Lighting**:
   - Optimal face detection occurs when the student's face occupies 15% to 60% of the frame height.
   - Avoid strong backlighting (e.g., student standing directly in front of the sun or bright bus windows).
2. **Threshold Tuning**:
   - `0.68` is the optimal default for MobileFaceNet normalized 192-d embeddings.
   - Raising threshold (e.g., `0.72`) increases strictness against impostors.
   - Lowering threshold (e.g., `0.63`) accommodates wider lighting variation.
3. **Biometric Privacy**:
   - Biometric embeddings and captured snapshot JPEGs are stored only in local app cache.
   - Delete temporary snapshot images (`sourceImagePath`) once manual review or dispatch alerts are handled.
