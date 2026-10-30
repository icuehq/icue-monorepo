import 'dart:typed_data';

import 'icue_face_sdk_platform_interface.dart';
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
import 'src/models/sdk_constants.dart';

export 'src/icue_face_sdk_exception.dart';
export 'src/models/attendance_models.dart';
export 'src/models/camera_lens.dart';
export 'src/models/face_bounding_box.dart';
export 'src/models/face_profile.dart';
export 'src/models/face_recognition_result.dart';
export 'src/models/face_sdk_accelerator.dart';
export 'src/models/face_sdk_config.dart';
export 'src/models/face_sdk_info.dart';
export 'src/models/face_tracking_result.dart';
export 'src/models/icue_yuv420_frame.dart';
export 'src/models/recognition_mode.dart';
export 'src/models/sdk_constants.dart';

class IcueFaceSdk {
  IcueFaceSdk({IcueFaceSdkPlatform? platform})
    : _platform = platform ?? IcueFaceSdkPlatform.instance;

  final IcueFaceSdkPlatform _platform;

  /// Initializes the face recognition engine with the specified [config].
  Future<void> initialize({FaceSdkConfig config = const FaceSdkConfig()}) =>
      _platform.initialize(config);

  /// Returns metadata about the underlying SDK runtime and model.
  Future<FaceSdkInfo> getInfo() => _platform.getInfo();

  /// Extracts a 192-float face embedding vector from an image file at [imagePath].
  ///
  /// Set [isFrontCamera] to true if the source image was taken with a front-facing camera.
  Future<Float32List> extractEmbedding({
    required String imagePath,
    bool isFrontCamera = false,
  }) => _platform.extractEmbedding(
    imagePath: imagePath,
    isFrontCamera: isFrontCamera,
  );

  /// Performs face recognition on an image file at [imagePath] against a list of stored [profiles].
  Future<List<FaceRecognitionResult>> recognize({
    required String imagePath,
    required List<FaceProfile> profiles,
    RecognitionMode mode = RecognitionMode.single,
    int maxFaces = defaultMaximumFaces,
    double threshold = defaultFaceMatchThreshold,
    bool isFrontCamera = false,
  }) => _platform.recognize(
    imagePath: imagePath,
    profiles: profiles,
    mode: mode,
    maxFaces: maxFaces,
    threshold: threshold,
    isFrontCamera: isFrontCamera,
  );

  /// Computes cosine similarity between two face embedding vectors [first] and [second].
  Future<double> compareEmbeddings({
    required List<double> first,
    required List<double> second,
  }) => _platform.compareEmbeddings(first: first, second: second);

  /// Detects bounding boxes for all faces in an image file at [imagePath].
  Future<List<FaceBoundingBox>> detectFaces({
    required String imagePath,
    bool isFrontCamera = false,
  }) =>
      _platform.detectFaces(imagePath: imagePath, isFrontCamera: isFrontCamera);

  /// Extracts a face embedding from packed NV21 frame bytes [nv21Bytes].
  Future<Float32List> extractEmbeddingFromNv21({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    int rotation = 0,
    bool isFrontCamera = false,
  }) => _platform.extractEmbeddingFromNv21(
    nv21Bytes: nv21Bytes,
    width: width,
    height: height,
    rotation: rotation,
    isFrontCamera: isFrontCamera,
  );

  /// Detects faces in packed NV21 frame bytes [nv21Bytes].
  Future<List<FaceBoundingBox>> detectFacesInFrame({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    int rotation = 0,
    bool isFrontCamera = false,
  }) => _platform.detectFacesInFrame(
    nv21Bytes: nv21Bytes,
    width: width,
    height: height,
    rotation: rotation,
    isFrontCamera: isFrontCamera,
  );

  /// Recognizes faces in packed NV21 frame bytes [nv21Bytes] matching against [profiles].
  Future<List<FaceRecognitionResult>> recognizeInFrame({
    required Uint8List nv21Bytes,
    required int width,
    required int height,
    required List<FaceProfile> profiles,
    int rotation = 0,
    RecognitionMode mode = RecognitionMode.single,
    int maxFaces = defaultMaximumFaces,
    double threshold = defaultFaceMatchThreshold,
    bool isFrontCamera = false,
  }) => _platform.recognizeInFrame(
    nv21Bytes: nv21Bytes,
    width: width,
    height: height,
    rotation: rotation,
    profiles: profiles,
    mode: mode,
    maxFaces: maxFaces,
    threshold: threshold,
    isFrontCamera: isFrontCamera,
  );

  /// Detects faces in a planar YUV420 [frame].
  Future<List<FaceBoundingBox>> detectFacesInYuvFrame(IcueYuv420Frame frame) =>
      _platform.detectFacesInYuvFrame(frame);

  /// Recognizes faces in a planar YUV420 [frame] matching against stored [profiles].
  Future<List<FaceRecognitionResult>> recognizeInYuvFrame({
    required IcueYuv420Frame frame,
    required List<FaceProfile> profiles,
    RecognitionMode mode = RecognitionMode.multi,
    int maxFaces = defaultMaximumFaces,
    double threshold = defaultFaceMatchThreshold,
  }) => _platform.recognizeInYuvFrame(
    frame: frame,
    profiles: profiles,
    mode: mode,
    maxFaces: maxFaces,
    threshold: threshold,
  );

  /// Opens the SDK-owned camera UI and returns one face embedding.
  ///
  /// Returns `null` when the user closes the camera without capturing.
  Future<Float32List?> captureEmbeddingWithCamera({
    CameraLens lens = CameraLens.front,
  }) => _platform.captureEmbeddingWithCamera(lens: lens);

  /// Live face locations from the SDK-owned tracking camera.
  Stream<FaceTrackingResult> get faceTrackingResults =>
      _platform.faceTrackingResults;

  /// Opens the SDK-owned camera UI and begins live face tracking.
  ///
  /// When [profiles] is non-empty, every tracking update also contains face
  /// recognition results matched against those profiles.
  Future<void> startFaceTracking({
    List<FaceProfile> profiles = const <FaceProfile>[],
    CameraLens lens = CameraLens.front,
    int maxFaces = defaultMaximumFaces,
    double threshold = defaultFaceMatchThreshold,
    bool showMatchingPercentage = true,
    bool showDetectedLabel = true,
    bool showUnrecognizedLabel = true,
    String unrecognizedLabel = 'UNREGISTERED STUDENT',
  }) => _platform.startFaceTracking(
    profiles: profiles,
    lens: lens,
    maxFaces: maxFaces,
    threshold: threshold,
    showMatchingPercentage: showMatchingPercentage,
    showDetectedLabel: showDetectedLabel,
    showUnrecognizedLabel: showUnrecognizedLabel,
    unrecognizedLabel: unrecognizedLabel,
  );

  /// Closes the SDK-owned live tracking camera, if it is open.
  Future<void> stopFaceTracking() => _platform.stopFaceTracking();

  /// Opens the SDK-owned camera in Live Attendance Mode.
  ///
  /// Sweeps the camera across the classroom while real-time deduplicated
  /// attendance records are updated on screen.
  Future<AttendanceResult?> startLiveAttendance({
    required List<FaceProfile> roster,
    AttendanceConfig config = const AttendanceConfig(),
  }) => _platform.startLiveAttendance(roster: roster, config: config);

  /// Opens the SDK-owned camera in Multi-Group Photo Capture Attendance Mode.
  ///
  /// Allows capturing multiple small group photos of the classroom to cover all students,
  /// deduplicating recognitions across snapshots into a single [AttendanceResult].
  Future<AttendanceResult?> startMultiPhotoAttendance({
    required List<FaceProfile> roster,
    AttendanceConfig config = const AttendanceConfig(),
  }) => _platform.startMultiPhotoAttendance(roster: roster, config: config);

  /// Runs programmatic attendance recognition across multiple image files [imagePaths]
  /// against a given class [roster].
  Future<AttendanceResult> processAttendanceFromImages({
    required List<String> imagePaths,
    required List<FaceProfile> roster,
    double threshold = defaultFaceMatchThreshold,
  }) => _platform.processAttendanceFromImages(
    imagePaths: imagePaths,
    roster: roster,
    threshold: threshold,
  );

  /// Releases native resources and disposes the SDK instance.
  Future<void> dispose() => _platform.dispose();
}
