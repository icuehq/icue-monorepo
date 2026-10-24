import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:icue_face_sdk/icue_face_sdk_method_channel.dart';
import 'package:icue_face_sdk/icue_face_sdk_platform_interface.dart';

class FakeIcueFaceSdkPlatform extends IcueFaceSdkPlatform {
  FaceSdkConfig? initializedWith;
  bool disposed = false;
  CameraLens? captureLens;
  CameraLens? trackingLens;
  bool trackingStopped = false;

  @override
  Future<void> initialize(FaceSdkConfig config) async {
    initializedWith = config;
  }

  @override
  Future<FaceSdkInfo> getInfo() async => const FaceSdkInfo(
    sdkVersion: 'test',
    modelName: 'mobilefacenet.tflite',
    embeddingSize: faceEmbeddingSize,
  );

  @override
  Future<Float32List> extractEmbedding({
    required String imagePath,
    required bool isFrontCamera,
  }) async => Float32List(faceEmbeddingSize);

  @override
  Future<Float32List?> captureEmbeddingWithCamera({
    required CameraLens lens,
  }) async {
    captureLens = lens;
    return Float32List(faceEmbeddingSize);
  }

  @override
  Stream<FaceTrackingResult> get faceTrackingResults => const Stream.empty();

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
    AttendanceType type = AttendanceType.TRANSPORT,
    double? fontSize,
    double? nameFontSize,
    DetectedLabelField detectedLabelField = DetectedLabelField.ID,
    DetectedLabelField? labelField,
    DetectedLabelField? labelType,
  }) async {
    trackingLens = lens;
  }

  @override
  Future<void> stopFaceTracking() async {
    trackingStopped = true;
  }

  @override
  Future<AttendanceResult?> startLiveAttendance({
    required List<FaceProfile> roster,
    required AttendanceConfig config,
  }) async {
    return AttendanceResult(
      present: [
        AttendanceRecord(
          personId: 'Student1',
          confidenceScore: 0.92,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      ],
      absentPersonIds: const ['Student2'],
      unrecognizedFaceCount: 1,
      totalRosterCount: 2,
      sessionStartTime: DateTime.fromMillisecondsSinceEpoch(1000),
      sessionEndTime: DateTime.fromMillisecondsSinceEpoch(2000),
      mode: AttendanceMode.liveStream,
    );
  }

  @override
  Future<AttendanceResult?> startMultiPhotoAttendance({
    required List<FaceProfile> roster,
    required AttendanceConfig config,
  }) async {
    return AttendanceResult(
      present: [
        AttendanceRecord(
          personId: 'Student1',
          confidenceScore: 0.88,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          sourceImagePath: '/path/photo1.jpg',
        ),
      ],
      absentPersonIds: const ['Student2'],
      unrecognizedFaceCount: 0,
      totalRosterCount: 2,
      sessionStartTime: DateTime.fromMillisecondsSinceEpoch(1000),
      sessionEndTime: DateTime.fromMillisecondsSinceEpoch(3000),
      mode: AttendanceMode.multiPhoto,
      photosProcessed: 2,
      capturedImagePaths: const ['/path/photo1.jpg', '/path/photo2.jpg'],
    );
  }

  @override
  Future<AttendanceResult> processAttendanceFromImages({
    required List<String> imagePaths,
    required List<FaceProfile> roster,
    required double threshold,
  }) async {
    return AttendanceResult(
      present: [
        AttendanceRecord(
          personId: 'Student1',
          confidenceScore: 0.95,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          sourceImagePath: imagePaths.first,
        ),
      ],
      absentPersonIds: const ['Student2'],
      unrecognizedFaceCount: 0,
      totalRosterCount: 2,
      sessionStartTime: DateTime.fromMillisecondsSinceEpoch(1000),
      sessionEndTime: DateTime.fromMillisecondsSinceEpoch(2500),
      mode: AttendanceMode.batchImages,
      photosProcessed: imagePaths.length,
      capturedImagePaths: imagePaths,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('$MethodChannelIcueFaceSdk is the default instance', () {
    expect(
      IcueFaceSdkPlatform.instance,
      isInstanceOf<MethodChannelIcueFaceSdk>(),
    );
  });

  test('delegates lifecycle and typed embedding calls', () async {
    final platform = FakeIcueFaceSdkPlatform();
    final sdk = IcueFaceSdk(platform: platform);

    await sdk.initialize(
      config: const FaceSdkConfig(
        accelerator: FaceSdkAccelerator.npu,
        numThreads: 2,
      ),
    );
    final info = await sdk.getInfo();
    final embedding = await sdk.extractEmbedding(imagePath: '/face.jpg');
    await sdk.dispose();

    expect(platform.initializedWith?.numThreads, 2);
    expect(platform.initializedWith?.accelerator, FaceSdkAccelerator.npu);
    expect(info.embeddingSize, faceEmbeddingSize);
    expect(embedding, hasLength(faceEmbeddingSize));
    expect(platform.disposed, isTrue);
  });

  test('FaceProfile validates its biometric template', () {
    expect(
      () => FaceProfile(personId: 'person', embedding: const <double>[1]),
      throwsArgumentError,
    );
    expect(
      () => FaceProfile(
        personId: '',
        embedding: List<double>.filled(faceEmbeddingSize, 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => FaceProfile(
        personId: 'person',
        embedding: List<double>.filled(faceEmbeddingSize, double.nan),
      ),
      throwsArgumentError,
    );
    expect(
      () => FaceProfile(
        personId: 'person',
        embedding: List<double>.filled(faceEmbeddingSize, double.infinity),
      ),
      throwsArgumentError,
    );
  });

  test('FaceSdkConfig asserts on invalid numThreads', () {
    expect(() => FaceSdkConfig(numThreads: 0), throwsA(isA<AssertionError>()));
    expect(() => FaceSdkConfig(numThreads: 9), throwsA(isA<AssertionError>()));
  });

  test('models implement operator == and hashCode correctly', () {
    final config1 = const FaceSdkConfig(
      accelerator: FaceSdkAccelerator.gpu,
      numThreads: 4,
    );
    final config2 = const FaceSdkConfig(
      accelerator: FaceSdkAccelerator.gpu,
      numThreads: 4,
    );
    expect(config1, equals(config2));
    expect(config1.hashCode, equals(config2.hashCode));

    final box1 = const FaceBoundingBox(
      left: 0,
      top: 0,
      right: 10,
      bottom: 10,
      trackingId: 1,
    );
    final box2 = const FaceBoundingBox(
      left: 0,
      top: 0,
      right: 10,
      bottom: 10,
      trackingId: 1,
    );
    expect(box1, equals(box2));
    expect(box1.hashCode, equals(box2.hashCode));

    final profile1 = FaceProfile(
      personId: 'A',
      embedding: List<double>.filled(faceEmbeddingSize, 0.5),
    );
    final profile2 = FaceProfile(
      personId: 'A',
      embedding: List<double>.filled(faceEmbeddingSize, 0.5),
    );
    expect(profile1, equals(profile2));
    expect(profile1.hashCode, equals(profile2.hashCode));

    final result1 = FaceRecognitionResult(
      personId: 'A',
      score: 0.9,
      matched: true,
      boundingBox: box1,
    );
    final result2 = FaceRecognitionResult(
      personId: 'A',
      score: 0.9,
      matched: true,
      boundingBox: box2,
    );
    expect(result1, equals(result2));
    expect(result1.hashCode, equals(result2.hashCode));

    final info1 = const FaceSdkInfo(
      sdkVersion: '0.2.0',
      modelName: 'm.tflite',
      embeddingSize: 192,
    );
    final info2 = const FaceSdkInfo(
      sdkVersion: '0.2.0',
      modelName: 'm.tflite',
      embeddingSize: 192,
    );
    expect(info1, equals(info2));
    expect(info1.hashCode, equals(info2.hashCode));
  });

  test('delegates SDK-owned camera capture and tracking', () async {
    final platform = FakeIcueFaceSdkPlatform();
    final sdk = IcueFaceSdk(platform: platform);

    final embedding = await sdk.captureEmbeddingWithCamera(
      lens: CameraLens.back,
    );
    await sdk.startFaceTracking();
    await sdk.stopFaceTracking();

    expect(embedding, hasLength(faceEmbeddingSize));
    expect(platform.captureLens, CameraLens.back);
    expect(platform.trackingLens, CameraLens.front);
    expect(platform.trackingStopped, isTrue);
  });

  test('parses live tracking frame metadata', () {
    final result = FaceTrackingResult.fromMap(<Object?, Object?>{
      'faces': <Object?>[
        <String, double>{'left': 2, 'top': 3, 'right': 12, 'bottom': 23},
      ],
      'recognitions': <Object?>[
        <String, Object?>{
          'personId': 'Alex',
          'score': 0.91,
          'matched': true,
          'boundingBox': <String, double>{
            'left': 2,
            'top': 3,
            'right': 12,
            'bottom': 23,
          },
        },
      ],
      'frameWidth': 720,
      'frameHeight': 1280,
      'timestampMillis': 1000,
    });

    expect(result.faces.single.width, 10);
    expect(result.recognitions.single.personId, 'Alex');
    expect(result.recognitions.single.matched, isTrue);
    expect(result.frameWidth, 720);
    expect(result.frameHeight, 1280);
    expect(result.timestamp.millisecondsSinceEpoch, 1000);
    expect(result.stopped, isFalse);
    expect(FaceTrackingResult.stopped().stopped, isTrue);
  });

  test('parses and delegates live and multi-photo class attendance', () async {
    final platform = FakeIcueFaceSdkPlatform();
    final sdk = IcueFaceSdk(platform: platform);

    final roster = [
      FaceProfile(
        personId: 'Student1',
        embedding: List<double>.filled(faceEmbeddingSize, 0.1),
      ),
      FaceProfile(
        personId: 'Student2',
        embedding: List<double>.filled(faceEmbeddingSize, 0.2),
      ),
    ];

    final liveResult = await sdk.startLiveAttendance(roster: roster);
    expect(liveResult, isNotNull);
    expect(liveResult!.present.length, 1);
    expect(liveResult.present.first.personId, 'Student1');
    expect(liveResult.absentPersonIds, ['Student2']);
    expect(liveResult.attendancePercentage, 50.0);

    final multiPhotoResult = await sdk.startMultiPhotoAttendance(
      roster: roster,
    );
    expect(multiPhotoResult, isNotNull);
    expect(multiPhotoResult!.mode, AttendanceMode.multiPhoto);
    expect(multiPhotoResult.photosProcessed, 2);
    expect(multiPhotoResult.capturedImagePaths, hasLength(2));

    final batchResult = await sdk.processAttendanceFromImages(
      imagePaths: ['/img1.jpg', '/img2.jpg'],
      roster: roster,
    );
    expect(batchResult.mode, AttendanceMode.batchImages);
    expect(batchResult.photosProcessed, 2);
    expect(batchResult.capturedImagePaths, ['/img1.jpg', '/img2.jpg']);
  });

  test('AttendanceType has ATTENDANCE and TRANSPORT with TRANSPORT as default in AttendanceConfig', () {
    expect(AttendanceType.values, containsAll([AttendanceType.ATTENDANCE, AttendanceType.TRANSPORT]));
    expect(AttendanceType.ATTENDANCE.name, 'ATTENDANCE');
    expect(AttendanceType.TRANSPORT.name, 'TRANSPORT');
    expect(AttendanceType.fromString('attendance'), AttendanceType.ATTENDANCE);
    expect(AttendanceType.fromString('transport'), AttendanceType.TRANSPORT);
    expect(AttendanceType.fromString(null), AttendanceType.TRANSPORT);

    const defaultConfig = AttendanceConfig();
    expect(defaultConfig.type, AttendanceType.TRANSPORT);
    expect(defaultConfig.effectiveFontSize, 12.0);

    const customConfig = AttendanceConfig(
      type: AttendanceType.ATTENDANCE,
      fontSize: 16.0,
    );
    expect(customConfig.type, AttendanceType.ATTENDANCE);
    expect(customConfig.effectiveFontSize, 16.0);

    final updated = customConfig.copyWith(nameFontSize: 20.0);
    expect(updated.effectiveFontSize, 20.0);
  });

  test('DetectedLabelField enum supports values, string parsing, and aliases', () {
    expect(
      DetectedLabelField.values,
      containsAll([
        DetectedLabelField.ID,
        DetectedLabelField.NAME,
        DetectedLabelField.LABEL,
        DetectedLabelField.NAME_AND_ID,
      ]),
    );

    expect(DetectedLabelField.fromString('id'), DetectedLabelField.ID);
    expect(DetectedLabelField.fromString('NAME'), DetectedLabelField.NAME);
    expect(DetectedLabelField.fromString('label'), DetectedLabelField.LABEL);
    expect(DetectedLabelField.fromString('name_and_id'), DetectedLabelField.NAME_AND_ID);
    expect(DetectedLabelField.fromString('both'), DetectedLabelField.NAME_AND_ID);
    expect(DetectedLabelField.fromString('BOTH'), DetectedLabelField.NAME_AND_ID);
    expect(DetectedLabelField.fromString('unknown'), DetectedLabelField.ID);
    expect(DetectedLabelField.fromString(null), DetectedLabelField.ID);

    // DetectedLabelType is a typedef for DetectedLabelField
    expect(DetectedLabelType.values, DetectedLabelField.values);
  });

  test('FaceProfile supports name, label, and effectiveLabel with fallback', () {
    final fullProfile = FaceProfile(
      personId: 'STU001',
      embedding: List<double>.filled(faceEmbeddingSize, 0.1),
      name: 'John Doe',
      label: 'Bus Leader',
    );
    expect(fullProfile.name, 'John Doe');
    expect(fullProfile.label, 'Bus Leader');
    expect(fullProfile.effectiveLabel, 'Bus Leader');

    final nameOnlyProfile = FaceProfile(
      personId: 'STU002',
      embedding: List<double>.filled(faceEmbeddingSize, 0.1),
      name: 'Jane Smith',
    );
    expect(nameOnlyProfile.name, 'Jane Smith');
    expect(nameOnlyProfile.label, isNull);
    expect(nameOnlyProfile.effectiveLabel, 'Jane Smith');

    final idOnlyProfile = FaceProfile(
      personId: 'STU003',
      embedding: List<double>.filled(faceEmbeddingSize, 0.1),
    );
    expect(idOnlyProfile.name, isNull);
    expect(idOnlyProfile.label, isNull);
    expect(idOnlyProfile.effectiveLabel, 'STU003');

    final map = fullProfile.toMap();
    expect(map['personId'], 'STU001');
    expect(map['name'], 'John Doe');
    expect(map['label'], 'Bus Leader');

    final copy = fullProfile.copyWith(name: 'Johnny');
    expect(copy.name, 'Johnny');
    expect(copy.label, 'Bus Leader');
  });

  test('FaceRecognitionResult supports name, label, and effectiveLabel', () {
    final result = FaceRecognitionResult.fromMap({
      'personId': 'STU001',
      'name': 'John Doe',
      'label': 'Bus Leader',
      'score': 0.95,
      'matched': true,
      'boundingBox': {
        'left': 10.0,
        'top': 10.0,
        'right': 50.0,
        'bottom': 50.0,
      },
    });

    expect(result.name, 'John Doe');
    expect(result.label, 'Bus Leader');
    expect(result.effectiveLabel, 'Bus Leader');

    final toMap = result.toMap();
    expect(toMap['name'], 'John Doe');
    expect(toMap['label'], 'Bus Leader');
  });

  test('AttendanceRecord supports name and label in serialization', () {
    final record = AttendanceRecord(
      personId: 'STU001',
      name: 'John Doe',
      label: 'Bus Leader',
      confidenceScore: 0.95,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(record.name, 'John Doe');
    expect(record.label, 'Bus Leader');

    final map = record.toMap();
    expect(map['name'], 'John Doe');
    expect(map['label'], 'Bus Leader');

    final reconstructed = AttendanceRecord.fromMap(map);
    expect(reconstructed.name, 'John Doe');
    expect(reconstructed.label, 'Bus Leader');
  });

  test('AttendanceConfig supports detectedLabelField and aliases', () {
    const defaultConfig = AttendanceConfig();
    expect(defaultConfig.detectedLabelField, DetectedLabelField.ID);
    expect(defaultConfig.labelField, DetectedLabelField.ID);
    expect(defaultConfig.labelType, DetectedLabelField.ID);

    const nameConfig = AttendanceConfig(
      detectedLabelField: DetectedLabelField.NAME,
    );
    expect(nameConfig.detectedLabelField, DetectedLabelField.NAME);

    const aliasConfig = AttendanceConfig(
      labelField: DetectedLabelField.LABEL,
    );
    expect(aliasConfig.detectedLabelField, DetectedLabelField.LABEL);

    const typeConfig = AttendanceConfig(
      labelType: DetectedLabelField.NAME_AND_ID,
    );
    expect(typeConfig.detectedLabelField, DetectedLabelField.NAME_AND_ID);

    final updated = defaultConfig.copyWith(
      detectedLabelField: DetectedLabelField.NAME,
    );
    expect(updated.detectedLabelField, DetectedLabelField.NAME);
  });

  test('UnrecognizedFaceRecord serializes and deserializes properly', () {
    final record = UnrecognizedFaceRecord(
      score: 0.35,
      boundingBox: const FaceBoundingBox(left: 10, top: 20, right: 50, bottom: 60),
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      sourceImagePath: '/path/to/img.jpg',
    );

    expect(record.score, 0.35);
    expect(record.confidenceScore, 0.35);
    expect(record.sourceImagePath, '/path/to/img.jpg');
    expect(record.boundingBox?.left, 10);

    final map = record.toMap();
    expect(map['score'], 0.35);
    expect(map['confidenceScore'], 0.35);
    expect(map['sourceImagePath'], '/path/to/img.jpg');

    final reconstructed = UnrecognizedFaceRecord.fromMap(map);
    expect(reconstructed.score, 0.35);
    expect(reconstructed.confidenceScore, 0.35);
    expect(reconstructed.sourceImagePath, '/path/to/img.jpg');
    expect(reconstructed.boundingBox?.left, 10);
  });

  test('AttendanceResult exposes unrecognizedFaces and aliases', () {
    final result = AttendanceResult(
      present: [],
      absentPersonIds: [],
      unrecognizedFaceCount: 1,
      totalRosterCount: 5,
      sessionStartTime: DateTime.now(),
      sessionEndTime: DateTime.now(),
      mode: AttendanceMode.liveStream,
      capturedImagePaths: [],
      unrecognizedFaces: [
        UnrecognizedFaceRecord(
          score: 0.4,
          boundingBox: const FaceBoundingBox(left: 0, top: 0, right: 10, bottom: 10),
          timestamp: DateTime.now(),
        ),
      ],
    );

    expect(result.unrecognizedFaces, hasLength(1));
    expect(result.unrecognized, hasLength(1));
    expect(result.unrecognizedStudents, hasLength(1));
    expect(result.hasUnrecognizedFaces, isTrue);
    expect(result.unrecognizedFaceCount, 1);
  });

  test('FaceTrackingResult exposes unrecognizedFaces and counts', () {
    final result = FaceTrackingResult(
      faces: const [
        FaceBoundingBox(left: 0, top: 0, right: 10, bottom: 10),
        FaceBoundingBox(left: 15, top: 15, right: 25, bottom: 25),
      ],
      recognitions: const [
        FaceRecognitionResult(
          personId: 'STU01',
          name: 'Student 1',
          score: 0.9,
          matched: true,
          boundingBox: FaceBoundingBox(left: 0, top: 0, right: 10, bottom: 10),
        ),
        FaceRecognitionResult(
          personId: null,
          score: 0.3,
          matched: false,
          boundingBox: FaceBoundingBox(left: 15, top: 15, right: 25, bottom: 25),
        ),
      ],
      frameWidth: 100,
      frameHeight: 100,
      timestamp: DateTime.now(),
    );

    expect(result.hasUnrecognizedFaces, isTrue);
    expect(result.unrecognizedFaceCount, 1);
    expect(result.unrecognizedFaces, hasLength(1));
    expect(result.unrecognizedRecognitions.single.matched, isFalse);
  });
}
