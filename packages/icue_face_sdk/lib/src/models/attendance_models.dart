// ignore_for_file: constant_identifier_names

import 'camera_lens.dart';
import 'face_bounding_box.dart';
import 'face_profile.dart';
import 'face_recognition_result.dart';

/// Represents the attendance scanning mode.
enum AttendanceMode { liveStream, multiPhoto, batchImages }

/// Defines the operation context type for facial recognition scanning.
enum AttendanceType {
  ATTENDANCE,
  TRANSPORT;

  static const AttendanceType attendance = AttendanceType.ATTENDANCE;
  static const AttendanceType transport = AttendanceType.TRANSPORT;

  String get nativeValue => name;

  static AttendanceType fromString(String? value) {
    if (value == null) return AttendanceType.TRANSPORT;
    final upper = value.trim().toUpperCase();
    if (upper == 'ATTENDANCE') return AttendanceType.ATTENDANCE;
    return AttendanceType.TRANSPORT;
  }
}

/// Field to display over detected faces in the camera overlay.
enum DetectedLabelField {
  /// Displays the student/person ID (default).
  ID,

  /// Displays the student/person name if provided in [FaceProfile.name],
  /// falling back to [FaceProfile.label] or [FaceProfile.personId].
  NAME,

  /// Displays the custom label if provided in [FaceProfile.label],
  /// falling back to [FaceProfile.name] or [FaceProfile.personId].
  LABEL,

  /// Displays both Name and ID in the format "Name (ID)".
  NAME_AND_ID;

  static DetectedLabelField fromString(String? value) {
    switch (value?.trim().toUpperCase()) {
      case 'NAME':
        return DetectedLabelField.NAME;
      case 'LABEL':
        return DetectedLabelField.LABEL;
      case 'NAME_AND_ID':
      case 'NAMEANDID':
      case 'BOTH':
        return DetectedLabelField.NAME_AND_ID;
      case 'ID':
      default:
        return DetectedLabelField.ID;
    }
  }
}

typedef DetectedLabelType = DetectedLabelField;

/// Holds attendance matching details for an individual student.
class AttendanceRecord {
  const AttendanceRecord({
    required this.personId,
    required this.confidenceScore,
    this.boundingBox,
    required this.timestamp,
    this.sourceImagePath,
    this.name,
    this.label,
  });

  factory AttendanceRecord.fromMap(Map<Object?, Object?> map) {
    final rawBox = map['boundingBox'] as Map<Object?, Object?>?;
    final rawTimestamp = map['timestampMillis'] as int?;
    final rawScore = map['score'] ?? map['confidenceScore'];
    final scoreNum = rawScore is num ? rawScore.toDouble() : 0.0;
    return AttendanceRecord(
      personId: (map['personId'] as String?) ?? '',
      confidenceScore: scoreNum,
      boundingBox: rawBox != null ? FaceBoundingBox.fromMap(rawBox) : null,
      timestamp: rawTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp)
          : DateTime.now(),
      sourceImagePath: map['sourceImagePath'] as String?,
      name: map['name'] as String?,
      label: map['label'] as String?,
    );
  }

  final String personId;
  final String? name;
  final String? label;
  final double confidenceScore;
  final FaceBoundingBox? boundingBox;
  final DateTime timestamp;
  final String? sourceImagePath;

  /// Returns the display label: [label] ?? [name] ?? [personId].
  String get effectiveLabel => label ?? name ?? personId;

  Map<String, Object?> toMap() => {
    'personId': personId,
    if (name != null) 'name': name,
    if (label != null) 'label': label,
    'score': confidenceScore,
    'boundingBox': boundingBox?.toMap(),
    'timestampMillis': timestamp.millisecondsSinceEpoch,
    'sourceImagePath': sourceImagePath,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecord &&
          runtimeType == other.runtimeType &&
          personId == other.personId &&
          name == other.name &&
          label == other.label &&
          confidenceScore == other.confidenceScore &&
          boundingBox == other.boundingBox &&
          sourceImagePath == other.sourceImagePath;

  @override
  int get hashCode =>
      Object.hash(personId, name, label, confidenceScore, boundingBox, sourceImagePath);
}

/// Represents a detected face that was not recognized against the roster (an unknown/unregistered student).
class UnrecognizedFaceRecord {
  const UnrecognizedFaceRecord({
    double? confidenceScore,
    double? score,
    required this.timestamp,
    this.boundingBox,
    this.sourceImagePath,
  }) : confidenceScore = confidenceScore ?? score ?? 0.0;

  factory UnrecognizedFaceRecord.fromMap(Map<Object?, Object?> map) {
    final rawBox = map['boundingBox'] as Map<Object?, Object?>?;
    final rawTimestamp = (map['timestampMillis'] as num?)?.toInt();
    final rawScore = map['score'] ?? map['confidenceScore'];
    final scoreNum = rawScore is num ? rawScore.toDouble() : 0.0;
    return UnrecognizedFaceRecord(
      confidenceScore: scoreNum,
      boundingBox: rawBox != null ? FaceBoundingBox.fromMap(rawBox) : null,
      timestamp: rawTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp)
          : DateTime.now(),
      sourceImagePath: map['sourceImagePath'] as String?,
    );
  }

  /// Highest matching score against the roster (e.g. cosine similarity to nearest enrolled face, or 0.0).
  final double confidenceScore;

  /// Alias for [confidenceScore].
  double get score => confidenceScore;

  /// Bounding box coordinates of the unknown student face in the camera frame.
  final FaceBoundingBox? boundingBox;

  /// Timestamp when the face was detected.
  final DateTime timestamp;

  /// Optional file path of the source image/photo if saved.
  final String? sourceImagePath;

  Map<String, Object?> toMap() => <String, Object?>{
    'score': confidenceScore,
    'confidenceScore': confidenceScore,
    if (boundingBox != null) 'boundingBox': boundingBox!.toMap(),
    'timestampMillis': timestamp.millisecondsSinceEpoch,
    if (sourceImagePath != null) 'sourceImagePath': sourceImagePath,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnrecognizedFaceRecord &&
          runtimeType == other.runtimeType &&
          confidenceScore == other.confidenceScore &&
          boundingBox == other.boundingBox &&
          sourceImagePath == other.sourceImagePath;

  @override
  int get hashCode =>
      Object.hash(confidenceScore, boundingBox, sourceImagePath);
}

/// Contains full results of a whole-class attendance session.
class AttendanceResult {
  const AttendanceResult({
    required this.present,
    required this.absentPersonIds,
    required this.unrecognizedFaceCount,
    this.unrecognizedFaces = const <UnrecognizedFaceRecord>[],
    required this.totalRosterCount,
    required this.sessionStartTime,
    required this.sessionEndTime,
    required this.mode,
    this.photosProcessed = 0,
    this.capturedImagePaths = const <String>[],
  });

  factory AttendanceResult.fromMap(Map<Object?, Object?> map) {
    final rawPresent = (map['present'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>();
    final rawAbsent = (map['absentPersonIds'] as List<Object?>? ?? const [])
        .cast<String>();
    final rawCapturedImages =
        (map['capturedImagePaths'] as List<Object?>? ?? const [])
            .cast<String>();
    final rawUnrecognized =
        (map['unrecognizedFaces'] as List<Object?>? ?? const [])
            .cast<Map<Object?, Object?>>();
    final parsedUnrecognized = rawUnrecognized
        .map(UnrecognizedFaceRecord.fromMap)
        .toList(growable: false);
    final count = map['unrecognizedFaceCount'] as int? ??
        (parsedUnrecognized.isNotEmpty ? parsedUnrecognized.length : 0);

    final modeStr = map['mode'] as String? ?? 'liveStream';
    final AttendanceMode modeEnum;
    switch (modeStr) {
      case 'multiPhoto':
        modeEnum = AttendanceMode.multiPhoto;
        break;
      case 'batchImages':
        modeEnum = AttendanceMode.batchImages;
        break;
      case 'liveStream':
      default:
        modeEnum = AttendanceMode.liveStream;
        break;
    }

    final startMs =
        (map['sessionStartTimeMs'] as int?) ??
        (map['sessionStartTimeMillis'] as int?) ??
        DateTime.now().millisecondsSinceEpoch;
    final endMs =
        (map['sessionEndTimeMs'] as int?) ??
        (map['sessionEndTimeMillis'] as int?) ??
        DateTime.now().millisecondsSinceEpoch;

    return AttendanceResult(
      present: rawPresent.map(AttendanceRecord.fromMap).toList(growable: false),
      absentPersonIds: rawAbsent,
      unrecognizedFaceCount: count,
      unrecognizedFaces: parsedUnrecognized,
      totalRosterCount:
          map['totalRosterCount'] as int? ??
          (rawPresent.length + rawAbsent.length),
      sessionStartTime: DateTime.fromMillisecondsSinceEpoch(startMs),
      sessionEndTime: DateTime.fromMillisecondsSinceEpoch(endMs),
      mode: modeEnum,
      photosProcessed: map['photosProcessed'] as int? ?? 0,
      capturedImagePaths: rawCapturedImages,
    );
  }

  final List<AttendanceRecord> present;
  final List<String> absentPersonIds;
  final int unrecognizedFaceCount;

  /// Detailed records of all unrecognized/unknown student faces detected during the session.
  final List<UnrecognizedFaceRecord> unrecognizedFaces;

  /// Alias for [unrecognizedFaces].
  List<UnrecognizedFaceRecord> get unrecognized => unrecognizedFaces;

  /// Alias for [unrecognizedFaces].
  List<UnrecognizedFaceRecord> get unrecognizedStudents => unrecognizedFaces;

  /// True if any unrecognized student faces were detected.
  bool get hasUnrecognizedFaces =>
      unrecognizedFaces.isNotEmpty || unrecognizedFaceCount > 0;

  final int totalRosterCount;
  final DateTime sessionStartTime;
  final DateTime sessionEndTime;
  final AttendanceMode mode;
  final int photosProcessed;
  final List<String> capturedImagePaths;

  double get attendancePercentage =>
      totalRosterCount == 0 ? 0.0 : (present.length / totalRosterCount) * 100;

  Map<String, Object?> toMap() => {
    'present': present.map((e) => e.toMap()).toList(growable: false),
    'absentPersonIds': absentPersonIds,
    'unrecognizedFaceCount': unrecognizedFaceCount,
    'unrecognizedFaces':
        unrecognizedFaces.map((e) => e.toMap()).toList(growable: false),
    'totalRosterCount': totalRosterCount,
    'sessionStartTimeMs': sessionStartTime.millisecondsSinceEpoch,
    'sessionEndTimeMs': sessionEndTime.millisecondsSinceEpoch,
    'mode': mode.name,
    'photosProcessed': photosProcessed,
    'capturedImagePaths': capturedImagePaths,
  };
}

/// Configuration options for class attendance scanning.
class AttendanceConfig {
  const AttendanceConfig({
    this.threshold = 0.68,
    this.maxFacesPerFrame = 20,
    this.lens = CameraLens.back,
    this.autoFinishWhenComplete = false,
    this.defaultZoom = 1.0,
    this.showMatchingPercentage = true,
    this.showDetectedLabel = true,
    this.showUnrecognizedLabel = true,
    this.unrecognizedLabel = 'UNREGISTERED STUDENT',
    this.type = AttendanceType.TRANSPORT,
    this.fontSize,
    this.nameFontSize,
    DetectedLabelField? detectedLabelField,
    DetectedLabelField? labelField,
    DetectedLabelField? labelType,
    this.onUnrecognizedFace,
  }) : detectedLabelField =
           detectedLabelField ?? labelField ?? labelType ?? DetectedLabelField.ID,
       assert(
         threshold >= 0.0 && threshold <= 1.0,
         'Threshold must be between 0.0 and 1.0',
       ),
       assert(maxFacesPerFrame > 0, 'maxFacesPerFrame must be greater than 0'),
       assert(defaultZoom >= 1.0, 'defaultZoom must be >= 1.0'),
       assert(
         fontSize == null || fontSize > 0,
         'fontSize must be greater than 0',
       ),
       assert(
         nameFontSize == null || nameFontSize > 0,
         'nameFontSize must be greater than 0',
       );

  final double threshold;
  final int maxFacesPerFrame;
  final CameraLens lens;
  final bool autoFinishWhenComplete;
  final double defaultZoom;
  final bool showMatchingPercentage;
  final bool showDetectedLabel;
  final bool showUnrecognizedLabel;
  final String unrecognizedLabel;

  /// Optional real-time callback invoked whenever an unknown/unregistered face
  /// is detected in the live camera feed during the attendance session.
  final void Function(List<FaceRecognitionResult> unrecognizedFaces)?
      onUnrecognizedFace;

  /// The scanning context type: [AttendanceType.ATTENDANCE] or [AttendanceType.TRANSPORT].
  /// Defaults to [AttendanceType.TRANSPORT].
  final AttendanceType type;

  /// Font size for the student Name/ID label displayed over detected faces.
  final double? fontSize;

  /// Font size for the student Name/ID label displayed over detected faces (alias for [fontSize]).
  final double? nameFontSize;

  /// Returns the resolved font size for student Name/ID labels (default: 12.0).
  double get effectiveFontSize => nameFontSize ?? fontSize ?? 12.0;

  /// Which field to display in the label badge when a face is detected:
  /// [DetectedLabelField.ID] (default), [DetectedLabelField.NAME],
  /// [DetectedLabelField.LABEL], or [DetectedLabelField.NAME_AND_ID].
  final DetectedLabelField detectedLabelField;

  /// Alias for [detectedLabelField].
  DetectedLabelField get labelField => detectedLabelField;

  /// Alias for [detectedLabelField].
  DetectedLabelField get labelType => detectedLabelField;

  AttendanceConfig copyWith({
    double? threshold,
    int? maxFacesPerFrame,
    CameraLens? lens,
    bool? autoFinishWhenComplete,
    double? defaultZoom,
    bool? showMatchingPercentage,
    bool? showDetectedLabel,
    bool? showUnrecognizedLabel,
    String? unrecognizedLabel,
    AttendanceType? type,
    double? fontSize,
    double? nameFontSize,
    DetectedLabelField? detectedLabelField,
    DetectedLabelField? labelField,
    DetectedLabelField? labelType,
    void Function(List<FaceRecognitionResult> unrecognizedFaces)?
        onUnrecognizedFace,
  }) {
    return AttendanceConfig(
      threshold: threshold ?? this.threshold,
      maxFacesPerFrame: maxFacesPerFrame ?? this.maxFacesPerFrame,
      lens: lens ?? this.lens,
      autoFinishWhenComplete:
          autoFinishWhenComplete ?? this.autoFinishWhenComplete,
      defaultZoom: defaultZoom ?? this.defaultZoom,
      showMatchingPercentage:
          showMatchingPercentage ?? this.showMatchingPercentage,
      showDetectedLabel: showDetectedLabel ?? this.showDetectedLabel,
      showUnrecognizedLabel:
          showUnrecognizedLabel ?? this.showUnrecognizedLabel,
      unrecognizedLabel: unrecognizedLabel ?? this.unrecognizedLabel,
      type: type ?? this.type,
      fontSize: fontSize ?? this.fontSize,
      nameFontSize: nameFontSize ?? this.nameFontSize,
      detectedLabelField: labelField ?? labelType ?? detectedLabelField ?? this.detectedLabelField,
      onUnrecognizedFace: onUnrecognizedFace ?? this.onUnrecognizedFace,
    );
  }
}
