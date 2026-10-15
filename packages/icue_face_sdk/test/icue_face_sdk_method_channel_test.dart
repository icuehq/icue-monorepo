import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:icue_face_sdk/icue_face_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelIcueFaceSdk();
  const channel = MethodChannel('icue_face_sdk');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' ||
            'dispose' ||
            'startFaceTracking' ||
            'stopFaceTracking' => null,
            'getInfo' => <String, Object>{
              'sdkVersion': '0.1.0',
              'modelName': 'mobilefacenet.tflite',
              'embeddingSize': faceEmbeddingSize,
            },
            'extractEmbedding' => Float32List(faceEmbeddingSize),
            'captureEmbeddingWithCamera' => Float32List(faceEmbeddingSize),
            'detectFaces' => <Object>[
              <String, double>{'left': 1, 'top': 2, 'right': 11, 'bottom': 22},
            ],
            'startLiveAttendance' ||
            'startMultiPhotoAttendance' ||
            'processAttendanceFromImages' => <String, Object?>{
              'present': <Object>[
                <String, Object?>{
                  'personId': 'Student1',
                  'score': 0.95,
                  'boundingBox': <String, double>{
                    'left': 0,
                    'top': 0,
                    'right': 10,
                    'bottom': 10,
                  },
                  'timestampMillis': 1000,
                },
              ],
              'absentPersonIds': <String>['Student2'],
              'unrecognizedFaceCount': 1,
              'unrecognizedFaces': <Object>[
                <String, Object?>{
                  'score': 0.42,
                  'confidenceScore': 0.42,
                  'boundingBox': <String, double>{
                    'left': 20,
                    'top': 20,
                    'right': 60,
                    'bottom': 60,
                  },
                  'timestampMillis': 1500,
                  'sourceImagePath': '/unrecognized.jpg',
                },
              ],
              'totalRosterCount': 2,
              'sessionStartTimeMs': 1000,
              'sessionEndTimeMs': 2000,
              'mode': call.method == 'startMultiPhotoAttendance'
                  ? 'multiPhoto'
                  : 'liveStream',
              'photosProcessed': 1,
            },
            _ => throw PlatformException(code: 'TEST_ERROR', message: 'failed'),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('passes configuration and parses SDK information', () async {
    await platform.initialize(
      const FaceSdkConfig(accelerator: FaceSdkAccelerator.gpu, numThreads: 3),
    );
    final info = await platform.getInfo();

    expect(calls.first.arguments, <String, Object>{
      'accelerator': 'gpu',
      'numThreads': 3,
      'type': 'TRANSPORT',
      'detectedLabelField': 'ID',
    });
    expect(info.sdkVersion, '0.1.0');
    expect(info.embeddingSize, faceEmbeddingSize);
  });

  test('preserves typed embeddings and bounding boxes', () async {
    final embedding = await platform.extractEmbedding(
      imagePath: '/face.jpg',
      isFrontCamera: false,
    );
    final boxes = await platform.detectFaces(
      imagePath: '/face.jpg',
      isFrontCamera: false,
    );

    expect(embedding, isA<Float32List>());
    expect(embedding, hasLength(faceEmbeddingSize));
    expect(boxes.single.width, 10);
    expect(boxes.single.height, 20);
  });

  test('maps PlatformException to IcueFaceSdkException', () async {
    expect(
      () => platform.compareEmbeddings(first: const [1], second: const [1]),
      throwsA(
        isA<IcueFaceSdkException>().having(
          (error) => error.code,
          'code',
          'TEST_ERROR',
        ),
      ),
    );
  });

  test('passes camera lens to capture and tracking calls', () async {
    final profile = FaceProfile(
      personId: 'Alex',
      embedding: List<double>.filled(faceEmbeddingSize, 0),
    );
    final embedding = await platform.captureEmbeddingWithCamera(
      lens: CameraLens.back,
    );
    await platform.startFaceTracking(
      profiles: <FaceProfile>[profile],
      lens: CameraLens.front,
      maxFaces: defaultMaximumFaces,
      threshold: defaultFaceMatchThreshold,
      showMatchingPercentage: true,
      showDetectedLabel: true,
      showUnrecognizedLabel: true,
      unrecognizedLabel: 'UNREGISTERED STUDENT',
    );
    await platform.stopFaceTracking();

    expect(embedding, hasLength(faceEmbeddingSize));
    expect(calls[0].method, 'captureEmbeddingWithCamera');
    expect(calls[0].arguments, <String, Object>{'lens': 'back'});
    expect(calls[1].method, 'startFaceTracking');
    expect(calls[1].arguments, <String, Object>{
      'profiles': <Object>[profile.toMap()],
      'lens': 'front',
      'mode': 'MULTI',
      'maxFaces': defaultMaximumFaces,
      'threshold': defaultFaceMatchThreshold,
      'showMatchingPercentage': true,
      'showDetectedLabel': true,
      'showUnrecognizedLabel': true,
      'unrecognizedLabel': 'UNREGISTERED STUDENT',
      'type': 'TRANSPORT',
      'fontSize': 12.0,
      'nameFontSize': 12.0,
      'detectedLabelField': 'ID',
      'labelField': 'ID',
    });
    expect(calls[2].method, 'stopFaceTracking');
  });

  test(
    'passes attendance parameters and deserializes AttendanceResult',
    () async {
      final profile = FaceProfile(
        personId: 'Student1',
        embedding: List<double>.filled(faceEmbeddingSize, 0),
      );
      final liveRes = await platform.startLiveAttendance(
        roster: [profile],
        config: const AttendanceConfig(),
      );
      final multiRes = await platform.startMultiPhotoAttendance(
        roster: [profile],
        config: const AttendanceConfig(),
      );

      expect(liveRes, isNotNull);
      expect(liveRes!.present.single.personId, 'Student1');
      expect(liveRes.mode, AttendanceMode.liveStream);
      expect(liveRes.unrecognizedFaces, hasLength(1));
      expect(liveRes.unrecognized.single.score, 0.42);
      expect(liveRes.unrecognizedStudents.single.sourceImagePath, '/unrecognized.jpg');
      expect(liveRes.hasUnrecognizedFaces, isTrue);
      expect(liveRes.unrecognizedFaceCount, 1);
      expect(multiRes!.mode, AttendanceMode.multiPhoto);

      final liveCall = calls.firstWhere((c) => c.method == 'startLiveAttendance');
      expect(liveCall.arguments['type'], 'TRANSPORT');
      expect(liveCall.arguments['fontSize'], 12.0);
      expect(liveCall.arguments['nameFontSize'], 12.0);
    },
  );

  test(
    'supports custom type and font size in AttendanceConfig and live attendance',
    () async {
      final profile = FaceProfile(
        personId: 'Student2',
        embedding: List<double>.filled(faceEmbeddingSize, 0),
      );
      await platform.startLiveAttendance(
        roster: [profile],
        config: const AttendanceConfig(
          type: AttendanceType.ATTENDANCE,
          fontSize: 18.0,
        ),
      );
      final customCall = calls.lastWhere((c) => c.method == 'startLiveAttendance');
      expect(customCall.arguments['type'], 'ATTENDANCE');
      expect(customCall.arguments['fontSize'], 18.0);
      expect(customCall.arguments['nameFontSize'], 18.0);
    },
  );

  test(
    'supports custom detectedLabelField in AttendanceConfig and startFaceTracking',
    () async {
      final profile = FaceProfile(
        personId: 'Student3',
        name: 'Jane Smith',
        label: 'VIP',
        embedding: List<double>.filled(faceEmbeddingSize, 0),
      );
      await platform.startLiveAttendance(
        roster: [profile],
        config: const AttendanceConfig(
          detectedLabelField: DetectedLabelField.NAME,
        ),
      );
      final liveCall = calls.lastWhere((c) => c.method == 'startLiveAttendance');
      expect(liveCall.arguments['detectedLabelField'], 'NAME');
      expect(liveCall.arguments['labelField'], 'NAME');

      await platform.startFaceTracking(
        profiles: [profile],
        lens: CameraLens.front,
        maxFaces: 5,
        threshold: 0.68,
        showMatchingPercentage: true,
        showDetectedLabel: true,
        showUnrecognizedLabel: true,
        unrecognizedLabel: 'UNREGISTERED STUDENT',
        detectedLabelField: DetectedLabelField.LABEL,
      );
      final trackingCall = calls.lastWhere((c) => c.method == 'startFaceTracking');
      expect(trackingCall.arguments['detectedLabelField'], 'LABEL');
      expect(trackingCall.arguments['labelField'], 'LABEL');
    },
  );
}
