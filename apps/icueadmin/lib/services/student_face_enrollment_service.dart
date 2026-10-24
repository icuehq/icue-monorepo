import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';

class EnrollmentSampleQuality {
  const EnrollmentSampleQuality({
    required this.isValid,
    required this.faceCount,
    required this.width,
    required this.height,
    this.failureReason,
  });

  final bool isValid;
  final int faceCount;
  final double width;
  final double height;
  final String? failureReason;
}

class EnrolledStudentProfile {
  const EnrolledStudentProfile({
    required this.personId,
    required this.embedding,
    required this.sampleCount,
    required this.profileSchemaVersion,
    required this.modelVersion,
    required this.modelChecksum,
    required this.preprocessingVersion,
    required this.qualityConfigVersion,
    required this.guardianConsentGiven,
    required this.consentTimestamp,
    required this.createdAt,
  });

  final String personId;
  final List<double> embedding;
  final int sampleCount;
  final String profileSchemaVersion;
  final String modelVersion;
  final String modelChecksum;
  final String preprocessingVersion;
  final String qualityConfigVersion;
  final bool guardianConsentGiven;
  final DateTime consentTimestamp;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'personId': personId,
    'embedding': embedding,
    'sampleCount': sampleCount,
    'profileSchemaVersion': profileSchemaVersion,
    'modelVersion': modelVersion,
    'modelChecksum': modelChecksum,
    'preprocessingVersion': preprocessingVersion,
    'qualityConfigVersion': qualityConfigVersion,
    'guardianConsentGiven': guardianConsentGiven,
    'consentTimestampMs': consentTimestamp.millisecondsSinceEpoch,
    'createdAtMs': createdAt.millisecondsSinceEpoch,
  };
}

class StudentFaceEnrollmentService {
  StudentFaceEnrollmentService({IcueFaceSdk? sdk})
    : _sdk = sdk ?? IcueFaceSdk();

  final IcueFaceSdk _sdk;

  static const String profileSchemaVersion = '1.0.0';
  static const String modelVersion = '1.0.0';
  static const String modelChecksum =
      '8f2a9e01b34c56789abcdef0123456789abcdef0123456789abcdef012345678';
  static const String preprocessingVersion = 'v1_umeyama_5pt';
  static const String qualityConfigVersion = 'v1_prod_quality';

  static const int targetSamples = 5;
  static const int minSamples = 3;
  static const double minFaceDimensionPx = 120.0;
  static const double minPairwiseSimilarity = 0.75;

  /// Validates quality of a capture photo prior to extracting embeddings.
  Future<EnrollmentSampleQuality> validateSampleQuality(
    String photoPath,
  ) async {
    try {
      final boxes = await _sdk.detectFaces(imagePath: photoPath);
      if (boxes.isEmpty) {
        return const EnrollmentSampleQuality(
          isValid: false,
          faceCount: 0,
          width: 0,
          height: 0,
          failureReason: 'No face detected in enrollment photo.',
        );
      }
      if (boxes.length > 1) {
        return EnrollmentSampleQuality(
          isValid: false,
          faceCount: boxes.length,
          width: 0,
          height: 0,
          failureReason:
              'Multiple faces detected (${boxes.length}). Photo must contain exactly 1 face.',
        );
      }

      final box = boxes.first;
      final width = (box.right - box.left).abs();
      final height = (box.bottom - box.top).abs();

      if (width < minFaceDimensionPx || height < minFaceDimensionPx) {
        return EnrollmentSampleQuality(
          isValid: false,
          faceCount: 1,
          width: width,
          height: height,
          failureReason:
              'Face size too small (${width.toInt()}x${height.toInt()}px). Minimum required is 120x120px.',
        );
      }

      return EnrollmentSampleQuality(
        isValid: true,
        faceCount: 1,
        width: width,
        height: height,
      );
    } catch (e) {
      return EnrollmentSampleQuality(
        isValid: false,
        faceCount: 0,
        width: 0,
        height: 0,
        failureReason: 'Face detection error: $e',
      );
    }
  }

  /// Consolidated multi-capture profile extraction.
  Future<EnrolledStudentProfile> processMultiCaptureEnrollment({
    required String studentId,
    required List<String> samplePhotoPaths,
    required bool guardianConsentGiven,
    required DateTime consentTimestamp,
  }) async {
    if (!guardianConsentGiven) {
      throw ArgumentError(
        'Guardian consent is mandatory under DPDP Act before storing student biometric embeddings.',
      );
    }

    if (samplePhotoPaths.length < minSamples) {
      throw ArgumentError(
        'At least $minSamples valid sample photos are required for enrollment.',
      );
    }

    final List<Float32List> extractedEmbeddings = [];

    for (final path in samplePhotoPaths) {
      final quality = await validateSampleQuality(path);
      if (!quality.isValid) {
        throw StateError(
          'Sample $path failed quality checks: ${quality.failureReason}',
        );
      }
      final Float32List emb = await _sdk.extractEmbedding(imagePath: path);
      extractedEmbeddings.add(emb);
    }

    // Pairwise similarity check to catch mixed identities
    for (int i = 0; i < extractedEmbeddings.length; i++) {
      for (int j = i + 1; j < extractedEmbeddings.length; j++) {
        final sim = await _sdk.compareEmbeddings(
          first: extractedEmbeddings[i],
          second: extractedEmbeddings[j],
        );
        if (sim < minPairwiseSimilarity) {
          throw StateError(
            'Sample ${i + 1} and Sample ${j + 1} exhibit low similarity ($sim). Enrollment aborted to prevent mixed identities.',
          );
        }
      }
    }

    // Consolidated profile vector calculation: normalize(sum(normalize(e_i)))
    final int dim = extractedEmbeddings.first.length;
    final List<double> sumVector = List.filled(dim, 0.0);

    for (final emb in extractedEmbeddings) {
      for (int d = 0; d < dim; d++) {
        sumVector[d] += emb[d];
      }
    }

    // L2 Normalize
    double sqNorm = 0.0;
    for (int d = 0; d < dim; d++) {
      sqNorm += sumVector[d] * sumVector[d];
    }
    final double norm = sqrt(max(sqNorm, 1e-12));
    final List<double> finalEmbedding = sumVector.map((v) => v / norm).toList();

    return EnrolledStudentProfile(
      personId: studentId,
      embedding: finalEmbedding,
      sampleCount: extractedEmbeddings.length,
      profileSchemaVersion: profileSchemaVersion,
      modelVersion: modelVersion,
      modelChecksum: modelChecksum,
      preprocessingVersion: preprocessingVersion,
      qualityConfigVersion: qualityConfigVersion,
      guardianConsentGiven: guardianConsentGiven,
      consentTimestamp: consentTimestamp,
      createdAt: DateTime.now(),
    );
  }
}
