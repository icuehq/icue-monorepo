import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/home_assignment.dart';

void main() {
  group('HomeAssignment Models Test', () {
    final sampleGetHomeAssignmentsJson = {
      'metadata': {'total': 15, 'page': 1, 'pagesize': 10},
      'data': [
        {
          'Section': 'A',
          'Standard': 'Grade 8',
          'NumberOfStudents': 14,
          'HomeWorkDate': '09/12/2026',
          'Subject': 'Science',
          'Work': 'Complete chapter 4 questions',
          'SubmissionDate': '09/12/2026',
          'Images': ['57045335-bc9b-4f04-b78c-f56eaac91d74'],
        },
      ],
      'err': false,
      'message': 'success',
    };

    test('parses HomeAssignmentResponse with data correctly', () {
      final response = HomeAssignmentResponse.fromJson(
        sampleGetHomeAssignmentsJson,
      );

      expect(response.err, isFalse);
      expect(response.message, equals('success'));
      expect(response.metadata, isNotNull);
      expect(response.metadata.total, equals(15));
      expect(response.metadata.page, equals(1));
      expect(response.metadata.pagesize, equals(10));

      expect(response.data.length, equals(1));
      final item = response.data.first;
      expect(item.standard, equals('Grade 8'));
      expect(item.section, equals('A'));
      expect(item.numberOfStudents, equals(14));
      expect(item.homeWorkDate, equals('09/12/2026'));
      expect(item.subject, equals('Science'));
      expect(item.work, equals('Complete chapter 4 questions'));
      expect(item.submissionDate, equals('09/12/2026'));
      expect(item.images, equals(['57045335-bc9b-4f04-b78c-f56eaac91d74']));
    });

    test('parses empty HomeAssignmentResponse correctly', () {
      final emptyJson = {
        'metadata': {'total': 0, 'page': 1, 'pagesize': 1},
        'data': [],
        'err': false,
        'message': 'success',
      };

      final response = HomeAssignmentResponse.fromJson(emptyJson);
      expect(response.err, isFalse);
      expect(response.message, equals('success'));
      expect(response.data, isEmpty);
      expect(response.metadata.total, equals(0));
    });

    test('roundtrips HomeAssignmentResponse through toJson()', () {
      final response = HomeAssignmentResponse.fromJson(
        sampleGetHomeAssignmentsJson,
      );
      final jsonMap = response.toJson();
      final roundtripped = HomeAssignmentResponse.fromJson(jsonMap);

      expect(roundtripped.err, equals(response.err));
      expect(roundtripped.message, equals(response.message));
      expect(roundtripped.metadata.total, equals(response.metadata.total));
      expect(roundtripped.data.length, equals(response.data.length));
      expect(roundtripped.data.first.work, equals(response.data.first.work));
      expect(
        roundtripped.data.first.images,
        equals(response.data.first.images),
      );
    });

    final sampleDocumentImagesJson = {
      'err': false,
      'message': 'succes',
      'Images': [
        {
          'DocumentId': '6f74ce47-ca5f-454e-8153-b7600b2d8368',
          'ImageUrl':
              'https://vroomdms.s3.ap-south-1.amazonaws.com/HomeWorks/6f74ce47-ca5f....',
        },
        {
          'DocumentId': 'cd356e47-fc0b-4d97-9bbd-4f3fd25d0298',
          'ImageUrl':
              'https://vroomdms.s3.ap-south-1.amazonaws.com/HomeWorks/cd356e47-fc0b....',
        },
      ],
    };

    test('parses DocumentImagesResponse correctly', () {
      final response = DocumentImagesResponse.fromJson(
        sampleDocumentImagesJson,
      );

      expect(response.err, isFalse);
      expect(response.message, equals('succes'));
      expect(response.images.length, equals(2));

      final first = response.images.first;
      expect(first.documentId, equals('6f74ce47-ca5f-454e-8153-b7600b2d8368'));
      expect(
        first.imageUrl,
        equals(
          'https://vroomdms.s3.ap-south-1.amazonaws.com/HomeWorks/6f74ce47-ca5f....',
        ),
      );

      final second = response.images[1];
      expect(second.documentId, equals('cd356e47-fc0b-4d97-9bbd-4f3fd25d0298'));
    });

    test('roundtrips DocumentImagesResponse through toJson()', () {
      final response = DocumentImagesResponse.fromJson(
        sampleDocumentImagesJson,
      );
      final jsonMap = response.toJson();
      final roundtripped = DocumentImagesResponse.fromJson(jsonMap);

      expect(roundtripped.err, equals(response.err));
      expect(roundtripped.message, equals(response.message));
      expect(roundtripped.images.length, equals(response.images.length));
      expect(
        roundtripped.images.first.documentId,
        equals(response.images.first.documentId),
      );
    });
  });
}
