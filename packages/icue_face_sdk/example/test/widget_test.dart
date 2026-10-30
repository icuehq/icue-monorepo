import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:icue_face_sdk/icue_face_sdk_platform_interface.dart';
import 'package:icue_face_sdk_example/local_face_store.dart';
import 'package:icue_face_sdk_example/main.dart';

class _FakeFaceSdkPlatform extends IcueFaceSdkPlatform {
  @override
  Future<void> initialize(FaceSdkConfig config) async {}

  @override
  Future<FaceSdkInfo> getInfo() async => const FaceSdkInfo(
    sdkVersion: 'test',
    modelName: 'test.tflite',
    embeddingSize: faceEmbeddingSize,
  );

  @override
  Stream<FaceTrackingResult> get faceTrackingResults => const Stream.empty();

  @override
  Future<Float32List?> captureEmbeddingWithCamera({
    required CameraLens lens,
  }) async => Float32List(faceEmbeddingSize);

  @override
  Future<void> dispose() async {}
}

class _MemoryFaceStore implements FaceStore {
  @override
  Future<List<FaceEnrollment>> load() async => const <FaceEnrollment>[];

  @override
  Future<List<FaceEnrollment>> remove(
    List<FaceEnrollment> current,
    String name,
  ) async => current;

  @override
  Future<List<FaceEnrollment>> upsert(
    List<FaceEnrollment> current,
    FaceEnrollment enrollment,
  ) async => <FaceEnrollment>[...current, enrollment];
}

void main() {
  testWidgets('renders the complete enrollment and recognition shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MyApp(
        sdk: IcueFaceSdk(platform: _FakeFaceSdkPlatform()),
        store: _MemoryFaceStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iCue School Attendance'), findsOneWidget);
    expect(find.text('OPEN STUDENT ENROLLMENT'), findsOneWidget);
    expect(
      find.text(
        'No student profiles enrolled on this device. Tap above to enroll a student.',
      ),
      findsOneWidget,
    );
  });

  test('face enrollment creates a validated SDK profile', () {
    final enrollment = FaceEnrollment(
      name: ' Alex ',
      embedding: List<double>.filled(faceEmbeddingSize, 0.1),
    );

    expect(enrollment.name, 'Alex');
    expect(enrollment.toProfile().personId, 'Alex');
    expect(enrollment.toJson()['embedding'], hasLength(faceEmbeddingSize));
  });

  testWidgets('names and saves a captured embedding', (tester) async {
    await tester.pumpWidget(
      MyApp(
        sdk: IcueFaceSdk(platform: _FakeFaceSdkPlatform()),
        store: _MemoryFaceStore(),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.tap(find.text('OPEN STUDENT ENROLLMENT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Enroll Student Profile'), findsOneWidget);
    expect(find.text('Save Student'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Alex');
    await tester.tap(find.text('Save Student'));
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
