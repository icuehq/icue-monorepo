import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'icue_face_sdk_platform_interface.dart';
import 'src/icue_face_sdk_exception.dart';
import 'src/models/attendance_models.dart';
import 'src/models/camera_lens.dart';
import 'src/models/face_bounding_box.dart';
import 'src/models/face_profile.dart';
import 'src/models/face_recognition_result.dart';
import 'src/models/face_sdk_config.dart';
import 'src/models/face_sdk_info.dart';
import 'src/models/face_tracking_result.dart';
import 'src/models/icue_yuv420_frame.dart';
import 'src/models/recognition_mode.dart';

class MethodChannelIcueFaceSdk extends IcueFaceSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('icue_face_sdk');

  @visibleForTesting
  final trackingEventChannel = const EventChannel('icue_face_sdk/tracking');

  Stream<FaceTrackingResult>? _trackingResults;

  @override
  Future<void> initialize(FaceSdkConfig config) =>
      _invoke<void>('initialize', config.toMap());

  @override
  Future<FaceSdkInfo> getInfo() async {
    final result = await _invoke<Map<Object?, Object?>>('getInfo');
    return FaceSdkInfo.fromMap(result!);
  }

  @override
  Future<Float32List> extractEmbedding({
    required String imagePath,
    required bool isFrontCamera,
  }) async => _asFloat32List(
    await _invoke<Object>('extractEmbedding', <String, Object>{
      'imagePath': imagePath,
      'isFrontCamera': isFrontCamera,
    }),
  );

  @override
  Future<List<FaceRecognitionResult>> recognize({
    required String imagePath,
    required List<FaceProfile> profiles,
    required RecognitionMode mode,
    required int maxFaces,
    required double threshold,
    required bool isFrontCamera,
  }) async => _recognitionResults(
    await _invoke<List<Object?>>('recognize', <String, Object>{
      'imagePath': imagePath,
      'profiles': profiles.map((profile) => profile.toMap()).toList(),
      'mode': mode.nativeValue,
      'maxFaces': maxFaces,
      'threshold': threshold,
      'isFrontCamera': isFrontCamera,
    }),
  );

  @override
  Future<double> compareEmbeddings({
    required List<double> first,
    required List<double> second,
  }) async {
    final result = await _invoke<num>('compareEmbeddings', <String, Object>{
      'first': Float32List.fromList(first),
      'second': Float32List.fromList(second),
    });
    return result!.toDouble();
  }

  @override
  Future<List<FaceBoundingBox>> detectFaces({
    required String imagePath,
    required bool isFrontCamera,
  }) async => _boundingBoxes(
    await _invoke<List<Object?>>('detectFaces', <String, Object>{
      'imagePath': imagePath,
      'isFrontCamera': isFrontCamera,
    }),
  );

  @override
  Future<Float32List> extractEmbeddingFromNv21({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    required int rotation,
    required bool isFrontCamera,
  }) async => _asFloat32List(
    await _invoke<Object>('extractEmbeddingFromNv21', <String, Object>{
      'nv21Bytes': nv21Bytes,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isFrontCamera': isFrontCamera,
    }),
  );

  @override
  Future<List<FaceBoundingBox>> detectFacesInFrame({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    required int rotation,
    required bool isFrontCamera,
  }) async => _boundingBoxes(
    await _invoke<List<Object?>>('detectFacesInFrame', <String, Object>{
      'nv21Bytes': nv21Bytes,
      'width': width,
      'height': height,
      'rotation': rotation,
      'isFrontCamera': isFrontCamera,
    }),
  );

  @override
  Future<List<FaceRecognitionResult>> recognizeInFrame({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    required int rotation,
    required List<FaceProfile> profiles,
    required RecognitionMode mode,
    required int maxFaces,
    required double threshold,
    required bool isFrontCamera,
  }) async => _recognitionResults(
    await _invoke<List<Object?>>('recognizeInFrame', <String, Object>{
      'nv21Bytes': nv21Bytes,
      'width': width,
      'height': height,
      'rotation': rotation,
      'profiles': profiles.map((profile) => profile.toMap()).toList(),
      'mode': mode.nativeValue,
      'maxFaces': maxFaces,
      'threshold': threshold,
      'isFrontCamera': isFrontCamera,
    }),
  );

  @override
  Future<List<FaceBoundingBox>> detectFacesInYuvFrame(
    IcueYuv420Frame frame,
  ) async => _boundingBoxes(
    await _invoke<List<Object?>>('detectFacesInYuvFrame', frame.toMap()),
  );

  @override
  Future<List<FaceRecognitionResult>> recognizeInYuvFrame({
    required IcueYuv420Frame frame,
    required List<FaceProfile> profiles,
    required RecognitionMode mode,
    required int maxFaces,
    required double threshold,
  }) async {
    final arguments = frame.toMap()
      ..addAll(<String, Object>{
        'profiles': profiles.map((profile) => profile.toMap()).toList(),
        'mode': mode.nativeValue,
        'maxFaces': maxFaces,
        'threshold': threshold,
      });
    return _recognitionResults(
      await _invoke<List<Object?>>('recognizeInYuvFrame', arguments),
    );
  }

  @override
  Future<Float32List?> captureEmbeddingWithCamera({
    required CameraLens lens,
  }) async {
    final value = await _invoke<Object>(
      'captureEmbeddingWithCamera',
      <String, Object>{'lens': lens.nativeValue},
    );
    return value == null ? null : _asFloat32List(value);
  }

  @override
  Stream<FaceTrackingResult>
  get faceTrackingResults => _trackingResults ??= trackingEventChannel
      .receiveBroadcastStream()
      .where(
        (event) =>
            event is Map &&
            (event['type'] == 'faces' || event['type'] == 'stopped'),
      )
      .map((event) {
        final map = Map<Object?, Object?>.from(event! as Map);
        return map['type'] == 'stopped'
            ? FaceTrackingResult.stopped()
            : FaceTrackingResult.fromMap(map);
      })
      .transform(
        StreamTransformer<FaceTrackingResult, FaceTrackingResult>.fromHandlers(
          handleError: (error, stackTrace, sink) {
            if (error is PlatformException) {
              sink.addError(
                IcueFaceSdkException(
                  error.code,
                  error.message ?? 'Native face tracking failed',
                  error.details,
                ),
                stackTrace,
              );
            } else {
              sink.addError(error, stackTrace);
            }
          },
        ),
      );

  @override
  Future<void> startFaceTracking({
    required List<FaceProfile> profiles,
    required CameraLens lens,
    required int maxFaces,
    required double threshold,
    required bool showMatchingPercentage,
    required bool showDetectedLabel,
    required bool showUnrecognizedLabel,
    required String unrecognizedLabel,
  }) => _invoke<void>('startFaceTracking', <String, Object>{
    'profiles': profiles.map((profile) => profile.toMap()).toList(),
    'lens': lens.nativeValue,
    'mode': RecognitionMode.multi.nativeValue,
    'maxFaces': maxFaces,
    'threshold': threshold,
    'showMatchingPercentage': showMatchingPercentage,
    'showDetectedLabel': showDetectedLabel,
    'showUnrecognizedLabel': showUnrecognizedLabel,
    'unrecognizedLabel': unrecognizedLabel,
  });

  @override
  Future<void> stopFaceTracking() => _invoke<void>('stopFaceTracking');

  @override
  Future<AttendanceResult?> startLiveAttendance({
    required List<FaceProfile> roster,
    required AttendanceConfig config,
  }) async {
    final result = await _invoke<Map<Object?, Object?>>(
      'startLiveAttendance',
      <String, Object>{
        'roster': roster.map((profile) => profile.toMap()).toList(),
        'threshold': config.threshold,
        'maxFaces': config.maxFacesPerFrame,
        'lens': config.lens.nativeValue,
        'autoFinish': config.autoFinishWhenComplete,
        'defaultZoom': config.defaultZoom,
        'showMatchingPercentage': config.showMatchingPercentage,
        'showDetectedLabel': config.showDetectedLabel,
        'showUnrecognizedLabel': config.showUnrecognizedLabel,
        'unrecognizedLabel': config.unrecognizedLabel,
      },
    );
    return result == null ? null : AttendanceResult.fromMap(result);
  }

  @override
  Future<AttendanceResult?> startMultiPhotoAttendance({
    required List<FaceProfile> roster,
    required AttendanceConfig config,
  }) async {
    final result = await _invoke<Map<Object?, Object?>>(
      'startMultiPhotoAttendance',
      <String, Object>{
        'roster': roster.map((profile) => profile.toMap()).toList(),
        'threshold': config.threshold,
        'maxFaces': config.maxFacesPerFrame,
        'lens': config.lens.nativeValue,
        'autoFinish': config.autoFinishWhenComplete,
        'defaultZoom': config.defaultZoom,
        'showMatchingPercentage': config.showMatchingPercentage,
        'showDetectedLabel': config.showDetectedLabel,
        'showUnrecognizedLabel': config.showUnrecognizedLabel,
        'unrecognizedLabel': config.unrecognizedLabel,
      },
    );
    return result == null ? null : AttendanceResult.fromMap(result);
  }

  @override
  Future<AttendanceResult> processAttendanceFromImages({
    required List<String> imagePaths,
    required List<FaceProfile> roster,
    required double threshold,
  }) async {
    final result = await _invoke<Map<Object?, Object?>>(
      'processAttendanceFromImages',
      <String, Object>{
        'imagePaths': imagePaths,
        'roster': roster.map((profile) => profile.toMap()).toList(),
        'threshold': threshold,
      },
    );
    return AttendanceResult.fromMap(result!);
  }

  @override
  Future<void> dispose() => _invoke<void>('dispose');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw IcueFaceSdkException(
        error.code,
        error.message ?? 'Native face SDK call failed',
        error.details,
      );
    }
  }

  Float32List _asFloat32List(Object? value) {
    if (value is Float32List) return value;
    if (value is List) {
      final result = Float32List(value.length);
      for (var i = 0; i < value.length; i++) {
        result[i] = (value[i] as num).toDouble();
      }
      return result;
    }
    throw const FormatException('Expected a Float32List embedding');
  }

  List<FaceBoundingBox> _boundingBoxes(List<Object?>? values) =>
      (values ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(FaceBoundingBox.fromMap)
          .toList(growable: false);

  List<FaceRecognitionResult> _recognitionResults(List<Object?>? values) =>
      (values ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(FaceRecognitionResult.fromMap)
          .toList(growable: false);
}
