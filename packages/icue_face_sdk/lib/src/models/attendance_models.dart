import 'camera_lens.dart';
import 'face_bounding_box.dart';

/// Represents the attendance scanning mode.
enum AttendanceMode { liveStream, multiPhoto, batchImages }

/// Holds attendance matching details for an individual student.
class AttendanceRecord {
  const AttendanceRecord({
    required this.personId,
    required this.confidenceScore,
    this.boundingBox,
    required this.timestamp,
    this.sourceImagePath,
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
    );
  }

  final String personId;
  final double confidenceScore;
  final FaceBoundingBox? boundingBox;
  final DateTime timestamp;
  final String? sourceImagePath;

  Map<String, Object?> toMap() => {
    'personId': personId,
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
          confidenceScore == other.confidenceScore &&
          boundingBox == other.boundingBox &&
          sourceImagePath == other.sourceImagePath;

  @override
  int get hashCode =>
      Object.hash(personId, confidenceScore, boundingBox, sourceImagePath);
}

/// Contains full results of a whole-class attendance session.
class AttendanceResult {
  const AttendanceResult({
    required this.present,
    required this.absentPersonIds,
    required this.unrecognizedFaceCount,
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
      unrecognizedFaceCount: map['unrecognizedFaceCount'] as int? ?? 0,
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
  }) : assert(
         threshold >= 0.0 && threshold <= 1.0,
         'Threshold must be between 0.0 and 1.0',
       ),
       assert(maxFacesPerFrame > 0, 'maxFacesPerFrame must be greater than 0'),
       assert(defaultZoom >= 1.0, 'defaultZoom must be >= 1.0');

  final double threshold;
  final int maxFacesPerFrame;
  final CameraLens lens;
  final bool autoFinishWhenComplete;
  final double defaultZoom;
  final bool showMatchingPercentage;
  final bool showDetectedLabel;
  final bool showUnrecognizedLabel;
  final String unrecognizedLabel;
}
