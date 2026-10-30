import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final sdk = IcueFaceSdk();
  final imagePaths = <String, String>{};
  late Directory temporaryDirectory;

  setUpAll(() async {
    await sdk.initialize();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'icue_face_sdk_test.',
    );
    for (final assetPath in <String>[
      'assets/images/face_alice_1.png',
      'assets/images/face_alice_2.png',
      'assets/images/face_bob.png',
    ]) {
      final data = await rootBundle.load(assetPath);
      final file = File(
        '${temporaryDirectory.path}/${assetPath.split('/').last}',
      );
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      imagePaths[assetPath] = file.path;
    }
  });

  tearDownAll(() async {
    await sdk.dispose();
    await temporaryDirectory.delete(recursive: true);
  });

  testWidgets('initializes the Android inference runtime', (tester) async {
    final info = await sdk.getInfo();

    expect(info.sdkVersion, isNotEmpty);
    expect(info.modelName, 'mobilefacenet.tflite');
    expect(info.embeddingSize, faceEmbeddingSize);
  });

  testWidgets('preserves same-person recognition ordering', (tester) async {
    final aliceOne = await sdk.extractEmbedding(
      imagePath: imagePaths['assets/images/face_alice_1.png']!,
    );
    final aliceTwo = await sdk.extractEmbedding(
      imagePath: imagePaths['assets/images/face_alice_2.png']!,
    );
    final bob = await sdk.extractEmbedding(
      imagePath: imagePaths['assets/images/face_bob.png']!,
    );

    final selfScore = await sdk.compareEmbeddings(
      first: aliceOne,
      second: aliceOne,
    );
    final samePersonScore = await sdk.compareEmbeddings(
      first: aliceOne,
      second: aliceTwo,
    );
    final differentPersonScore = await sdk.compareEmbeddings(
      first: aliceOne,
      second: bob,
    );

    expect(selfScore, closeTo(1, 0.001));
    expect(samePersonScore, greaterThan(differentPersonScore));
  });

  testWidgets('accepts realistic planar YUV strides', (tester) async {
    const width = 480;
    const height = 360;
    final y = Uint8List(width * height)..fillRange(0, width * height, 16);
    final u = Uint8List(width * height ~/ 4)
      ..fillRange(0, width * height ~/ 4, 128);
    final v = Uint8List(width * height ~/ 4)
      ..fillRange(0, width * height ~/ 4, 128);

    for (final rotation in <int>[0, 90, 180, 270]) {
      for (final mirrorHorizontally in <bool>[false, true]) {
        final faces = await sdk.detectFacesInYuvFrame(
          IcueYuv420Frame(
            yBytes: y,
            uBytes: u,
            vBytes: v,
            width: width,
            height: height,
            yRowStride: width,
            uRowStride: width ~/ 2,
            vRowStride: width ~/ 2,
            uPixelStride: 1,
            vPixelStride: 1,
            rotationDegrees: rotation,
            mirrorHorizontally: mirrorHorizontally,
          ),
        );
        expect(faces, isEmpty);
      }
    }
  });

  testWidgets('reports warm end-to-end embedding latency', (tester) async {
    final imagePath = imagePaths['assets/images/face_alice_1.png']!;
    await sdk.extractEmbedding(imagePath: imagePath);
    final samples = <int>[];

    for (var index = 0; index < 10; index++) {
      final stopwatch = Stopwatch()..start();
      await sdk.extractEmbedding(imagePath: imagePath);
      samples.add(stopwatch.elapsedMicroseconds);
    }
    samples.sort();
    final medianMs = samples[samples.length ~/ 2] / 1000;
    final p95Ms = samples[(samples.length * 0.95).ceil() - 1] / 1000;

    // Printed values are collected from physical low/mid/high-tier devices.
    // A hard threshold would make CI emulator results misleading.
    // ignore: avoid_print
    print('ICUE_BENCHMARK embedding median=${medianMs}ms p95=${p95Ms}ms');
    expect(samples, everyElement(greaterThan(0)));
  });
}
