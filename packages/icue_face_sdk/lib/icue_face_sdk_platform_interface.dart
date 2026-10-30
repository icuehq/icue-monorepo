import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'icue_face_sdk_method_channel.dart';
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

abstract class IcueFaceSdkPlatform extends PlatformInterface {
  IcueFaceSdkPlatform() : super(token: _token);

  static final Object _token = Object();
  static IcueFaceSdkPlatform _instance = MethodChannelIcueFaceSdk();

  static IcueFaceSdkPlatform get instance => _instance;

  static set instance(IcueFaceSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(FaceSdkConfig config) =>
      throw UnimplementedError('initialize() has not been implemented.');

  Future<FaceSdkInfo> getInfo() =>
      throw UnimplementedError('getInfo() has not been implemented.');

  Future<Float32List> extractEmbedding({
    required String imagePath,
    required bool isFrontCamera,
  }) =>
      throw UnimplementedError('extractEmbedding() has not been implemented.');

  Future<List<FaceRecognitionResult>> recognize({
    required String imagePath,
    required List<FaceProfile> profiles,
    required RecognitionMode mode,
    required int maxFaces,
    required double threshold,
    required bool isFrontCamera,
  }) => throw UnimplementedError('recognize() has not been implemented.');

  Future<double> compareEmbeddings({
    required List<double> first,
    required List<double> second,
  }) =>
      throw UnimplementedError('compareEmbeddings() has not been implemented.');

  Future<List<FaceBoundingBox>> detectFaces({
    required String imagePath,
    required bool isFrontCamera,
  }) => throw UnimplementedError('detectFaces() has not been implemented.');

  Future<Float32List> extractEmbeddingFromNv21({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    required int rotation,
    required bool isFrontCamera,
  }) => throw UnimplementedError(
    'extractEmbeddingFromNv21() has not been implemented.',
  );

  Future<List<FaceBoundingBox>> detectFacesInFrame({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    required int rotation,
    required bool isFrontCamera,
  }) => throw UnimplementedError(
    'detectFacesInFrame() has not been implemented.',
  );

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
  }) =>
      throw UnimplementedError('recognizeInFrame() has not been implemented.');

  Future<List<FaceBoundingBox>> detectFacesInYuvFrame(IcueYuv420Frame frame) =>
      throw UnimplementedError(
        'detectFacesInYuvFrame() has not been implemented.',
      );

  Future<List<FaceRecognitionResult>> recognizeInYuvFrame({
    required IcueYuv420Frame frame,
    required List<FaceProfile> profiles,
    required RecognitionMode mode,
    required int maxFaces,
    required double threshold,
  }) => throw UnimplementedError(
    'recognizeInYuvFrame() has not been implemented.',
  );

  Future<Float32List?> captureEmbeddingWithCamera({required CameraLens lens}) =>
      throw UnimplementedError(
        'captureEmbeddingWithCamera() has not been implemented.',
      );

  Stream<FaceTrackingResult> get faceTrackingResults =>
      throw UnimplementedError('faceTrackingResults has not been implemented.');

  Future<void> startFaceTracking({
    required List<FaceProfile> profiles,
    required CameraLens lens,
    required int maxFaces,
    required double threshold,
    required bool showMatchingPercentage,
    required bool showDetectedLabel,
    required bool showUnrecognizedLabel,
    required String unrecognizedLabel,
  }) =>
      throw UnimplementedError('startFaceTracking() has not been implemented.');

  Future<void> stopFaceTracking() =>
      throw UnimplementedError('stopFaceTracking() has not been implemented.');

  Future<AttendanceResult?> startLiveAttendance({
    required List<FaceProfile> roster,
    required AttendanceConfig config,
  }) => throw UnimplementedError(
    'startLiveAttendance() has not been implemented.',
  );

  Future<AttendanceResult?> startMultiPhotoAttendance({
    required List<FaceProfile> roster,
    required AttendanceConfig config,
  }) => throw UnimplementedError(
    'startMultiPhotoAttendance() has not been implemented.',
  );

  Future<AttendanceResult> processAttendanceFromImages({
    required List<String> imagePaths,
    required List<FaceProfile> roster,
    required double threshold,
  }) => throw UnimplementedError(
    'processAttendanceFromImages() has not been implemented.',
  );

  Future<void> dispose() =>
      throw UnimplementedError('dispose() has not been implemented.');
}
