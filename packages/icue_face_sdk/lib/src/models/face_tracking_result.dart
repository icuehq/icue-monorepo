import 'package:flutter/foundation.dart';

import 'face_bounding_box.dart';
import 'face_recognition_result.dart';

class FaceTrackingResult {
  const FaceTrackingResult({
    required this.faces,
    this.recognitions = const <FaceRecognitionResult>[],
    required this.frameWidth,
    required this.frameHeight,
    required this.timestamp,
    this.stopped = false,
  });

  FaceTrackingResult.stopped()
    : faces = const <FaceBoundingBox>[],
      recognitions = const <FaceRecognitionResult>[],
      frameWidth = 0,
      frameHeight = 0,
      timestamp = DateTime.fromMillisecondsSinceEpoch(0),
      stopped = true;

  factory FaceTrackingResult.fromMap(Map<Object?, Object?> map) {
    final rawFaces = map['faces'] as List<Object?>? ?? const <Object?>[];
    final rawRecognitions =
        map['recognitions'] as List<Object?>? ?? const <Object?>[];
    return FaceTrackingResult(
      faces: rawFaces
          .whereType<Map<Object?, Object?>>()
          .map(FaceBoundingBox.fromMap)
          .toList(growable: false),
      recognitions: rawRecognitions
          .whereType<Map<Object?, Object?>>()
          .map(FaceRecognitionResult.fromMap)
          .toList(growable: false),
      frameWidth: (map['frameWidth'] as num? ?? 0).toInt(),
      frameHeight: (map['frameHeight'] as num? ?? 0).toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestampMillis'] as num? ?? 0).toInt(),
      ),
    );
  }

  final List<FaceBoundingBox> faces;
  final List<FaceRecognitionResult> recognitions;
  final int frameWidth;
  final int frameHeight;
  final DateTime timestamp;
  final bool stopped;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceTrackingResult &&
          listEquals(other.faces, faces) &&
          listEquals(other.recognitions, recognitions) &&
          other.frameWidth == frameWidth &&
          other.frameHeight == frameHeight &&
          other.timestamp == timestamp &&
          other.stopped == stopped;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(faces),
    Object.hashAll(recognitions),
    frameWidth,
    frameHeight,
    timestamp,
    stopped,
  );
}
