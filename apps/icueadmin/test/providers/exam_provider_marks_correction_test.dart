import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/exam_marks.dart';
import 'package:icueadmin/models/marks_correction.dart';
import 'package:icueadmin/providers/exam_provider.dart';
import 'package:icueadmin/services/api_client.dart';

class MockApiClient extends Fake implements ApiClient {
  String? lastPostPath;
  dynamic lastPostData;
  dynamic nextResponseData;
  int nextStatusCode = 200;
  Exception? errorToThrow;

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: nextResponseData,
      statusCode: nextStatusCode,
    );
  }

  @override
  void logCrash(
    String from,
    Object error,
    StackTrace? stack, {
    bool fatal = true,
    String? message,
  }) {}
}

void main() {
  late MockApiClient mockApiClient;
  late ExamProvider provider;

  setUp(() {
    mockApiClient = MockApiClient();
    provider = ExamProvider(mockApiClient);
  });

  group('ExamProvider Marks Correction API Tests', () {
    test(
      'requestMarksCorrection posts correct payload and parses response',
      () async {
        mockApiClient.nextResponseData = {
          'success': true,
          'message':
              'Marks correction request submitted successfully for Principal approval',
          'ExamId': 30,
          'StudentId': 41294,
          'CurrentMarks': null,
          'CurrentStatus': 'NA',
          'RequestedMarks': 38,
          'RequestedStatus': 'PRESENT',
          'CorrectionStatus': 'Pending',
          'CorrectionStatusAt': '2026-09-12T06:46:07.262Z',
        };

        final response = await provider.requestMarksCorrection(
          examId: 30,
          studentId: 41294,
          newMarks: 38,
          newStatus: '',
          reason: 'By mistake Absent select',
          showLoading: false,
        );

        expect(
          mockApiClient.lastPostPath,
          equals('/v1.0/requestMarksCorrection'),
        );
        expect(
          mockApiClient.lastPostData,
          equals({
            'ExamId': 30,
            'StudentId': 41294,
            'NewMarks': 38,
            'NewStatus': '',
            'Reason': 'By mistake Absent select',
          }),
        );

        expect(response.success, isTrue);
        expect(response.err, isFalse);
        expect(response.examId, equals(30));
        expect(response.studentId, equals(41294));
        expect(response.requestedMarks, equals(38));
        expect(response.requestedStatus, equals('PRESENT'));
      },
    );

    test('requestMarksCorrection handles error response gracefully', () async {
      mockApiClient.nextResponseData = {
        'err': true,
        'message':
            'A mark correction request is already pending approval for this student',
      };

      final response = await provider.requestMarksCorrection(
        examId: 30,
        studentId: 41294,
        newMarks: 38,
        reason: 'Duplicate request test',
        showLoading: false,
      );

      expect(response.success, isFalse);
      expect(response.err, isTrue);
      expect(
        response.message,
        equals(
          'A mark correction request is already pending approval for this student',
        ),
      );
    });

    test(
      'getMarksCorrectionRequests fetches data and updates provider state',
      () async {
        mockApiClient.nextResponseData = {
          'err': false,
          'message': 'Marks Correction Requests',
          'data': [
            {
              'ExamId': 30,
              'StudentId': 41292,
              'StudentName': 'Sree',
              'RollNo': '123123',
              'AdmissionNumber': '123123',
              'Section': 'A',
              'ClassId': 3890,
              'Standard': 'Standard 10',
              'ExamName': 'assignment test - 1',
              'Subject': 'Telugu',
              'MaximumMarks': 50,
              'PassingMarks': 35,
              'CurrentMarks': 35,
              'CurrentStatus': 'PRESENT',
              'Correction': {
                'Status': 'Pending',
                'Marks': 40,
                'MarkStatus': 'PRESENT',
                'Reason': 'Re-evaluation of question 4',
                'RequestedBy': 'sbranch',
                'RequestedDate': '2026-09-12T06:13:10.716Z',
              },
              'History': [],
            },
            {
              'ExamId': 30,
              'StudentId': 41294,
              'StudentName': 'T Varshitha Reddy',
              'RollNo': 'TNS1234',
              'AdmissionNumber': 'TNS1234',
              'Section': 'A',
              'ClassId': 3890,
              'Standard': 'Standard 10',
              'ExamName': 'assignment test - 1',
              'Subject': 'Telugu',
              'MaximumMarks': 50,
              'PassingMarks': 35,
              'CurrentMarks': 38,
              'CurrentStatus': 'PRESENT',
              'Correction': {
                'Status': 'Pending',
                'StatusAt': '2026-09-12T06:59:34.077Z',
                'Marks': 38,
                'MarkStatus': 'PRESENT',
                'Reason': 'By mistake Absent select',
                'RequestedId': 3,
                'RequestedBy': 'Bsan@icue',
                'RequestedDate': '2026-09-12T06:59:34.077Z',
              },
              'History': [],
            },
          ],
        };

        expect(provider.marksCorrectionRequests, isEmpty);

        final list = await provider.getMarksCorrectionRequests(examId: 30);

        expect(
          mockApiClient.lastPostPath,
          equals('/v1.0/getMarksCorrectionRequests'),
        );
        expect(
          mockApiClient.lastPostData,
          equals({'CorrectionStatus': 'Pending', 'ExamId': 30}),
        );

        expect(list.length, equals(2));
        expect(provider.marksCorrectionRequests.length, equals(2));
        expect(provider.marksCorrectionRequests[0].studentName, equals('Sree'));
        expect(
          provider.marksCorrectionRequests[1].studentName,
          equals('T Varshitha Reddy'),
        );
        expect(provider.loadingMarksCorrections, isFalse);
      },
    );

    test(
      'approveMarksCorrection updates state, removes pending request, and updates student',
      () async {
        // Seed provider with students and pending requests
        provider.students = [
          ExamStudent(
            studentId: 41294,
            name: 'T Varshitha Reddy',
            marks: 0,
            status: 'NA',
            isSaved: true,
          ),
        ];
        provider.marksCorrectionRequests = [
          MarksCorrectionItem(
            examId: 30,
            studentId: 41294,
            studentName: 'T Varshitha Reddy',
            currentMarks: 0,
            currentStatus: 'NA',
          ),
          MarksCorrectionItem(
            examId: 30,
            studentId: 41292,
            studentName: 'Sree',
            currentMarks: 35,
            currentStatus: 'PRESENT',
          ),
        ];

        mockApiClient.nextResponseData = {
          'success': true,
          'message': 'Marks correction request approved successfully',
          'ExamId': 30,
          'StudentId': 41294,
          'Decision': 'Approved',
          'Marks': 38,
          'Status': 'PRESENT',
          'ApprovedBy': 'Bsan@icue',
          'ApprovedDate': '2026-09-12T06:47:36.260Z',
        };

        final response = await provider.approveMarksCorrection(
          examId: 30,
          studentId: 41294,
          decision: 'Approved',
          remarks: 'Marks verified and accepted by Principal',
          showLoading: false,
        );

        expect(
          mockApiClient.lastPostPath,
          equals('/v1.0/approveMarksCorrection'),
        );
        expect(
          mockApiClient.lastPostData,
          equals({
            'ExamId': 30,
            'StudentId': 41294,
            'Decision': 'Approved',
            'Remarks': 'Marks verified and accepted by Principal',
          }),
        );

        expect(response.success, isTrue);
        expect(response.marks, equals(38));
        expect(response.status, equals('PRESENT'));

        // Student 41294 should be updated in local students list
        final student = provider.students.first;
        expect(student.marks, equals(38));
        expect(student.status, equals('PRESENT'));

        // Approved item should be removed from marksCorrectionRequests list
        expect(provider.marksCorrectionRequests.length, equals(1));
        expect(provider.marksCorrectionRequests.first.studentId, equals(41292));
      },
    );

    test('approveMarksCorrection handles no pending request error', () async {
      mockApiClient.nextResponseData = {
        'err': true,
        'message':
            'No pending marks correction request found for this student and exam',
      };

      final response = await provider.approveMarksCorrection(
        examId: 30,
        studentId: 41294,
        decision: 'Approved',
        remarks: 'Marks verified',
        showLoading: false,
      );

      expect(response.success, isFalse);
      expect(response.err, isTrue);
      expect(
        response.message,
        equals(
          'No pending marks correction request found for this student and exam',
        ),
      );
    });

    test('reset and clearMarksCorrectionRequests clear the list', () {
      provider.marksCorrectionRequests = [
        MarksCorrectionItem(examId: 30, studentId: 41292, studentName: 'Sree'),
      ];

      provider.clearMarksCorrectionRequests();
      expect(provider.marksCorrectionRequests, isEmpty);

      provider.marksCorrectionRequests = [
        MarksCorrectionItem(examId: 30, studentId: 41292, studentName: 'Sree'),
      ];

      provider.reset();
      expect(provider.marksCorrectionRequests, isEmpty);
      expect(provider.loadingMarksCorrections, isFalse);
    });
  });
}
