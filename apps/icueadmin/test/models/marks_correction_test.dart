import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/marks_correction.dart';

void main() {
  group('Marks Correction Models Tests', () {
    test('RequestMarksCorrectionResponse parses success JSON correctly', () {
      final json = {
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

      final response = RequestMarksCorrectionResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.err, isFalse);
      expect(
        response.message,
        equals(
          'Marks correction request submitted successfully for Principal approval',
        ),
      );
      expect(response.examId, equals(30));
      expect(response.studentId, equals(41294));
      expect(response.currentMarks, isNull);
      expect(response.currentStatus, equals('NA'));
      expect(response.requestedMarks, equals(38));
      expect(response.requestedStatus, equals('PRESENT'));
      expect(response.correctionStatus, equals('Pending'));
      expect(
        response.correctionStatusAt,
        equals(DateTime.parse('2026-09-12T06:46:07.262Z')),
      );

      final outJson = response.toJson();
      expect(outJson['success'], isTrue);
      expect(outJson['err'], isFalse);
      expect(outJson['ExamId'], equals(30));
      expect(outJson['StudentId'], equals(41294));
      expect(outJson['CurrentMarks'], isNull);
      expect(outJson['CurrentStatus'], equals('NA'));
      expect(outJson['RequestedMarks'], equals(38));
      expect(outJson['RequestedStatus'], equals('PRESENT'));
      expect(outJson['CorrectionStatus'], equals('Pending'));
      expect(outJson['CorrectionStatusAt'], equals('2026-09-12T06:46:07.262Z'));
    });

    test('RequestMarksCorrectionResponse parses error JSON correctly', () {
      final json = {
        'err': true,
        'message':
            'A mark correction request is already pending approval for this student',
      };

      final response = RequestMarksCorrectionResponse.fromJson(json);

      expect(response.success, isFalse);
      expect(response.err, isTrue);
      expect(
        response.message,
        equals(
          'A mark correction request is already pending approval for this student',
        ),
      );
      expect(response.examId, isNull);
      expect(response.studentId, isNull);

      final outJson = response.toJson();
      expect(outJson['success'], isFalse);
      expect(outJson['err'], isTrue);
      expect(outJson['message'], equals(response.message));
    });

    test('RequestMarksCorrectionResponse.error creates valid error object', () {
      final response = RequestMarksCorrectionResponse.error('Network failure');
      expect(response.success, isFalse);
      expect(response.err, isTrue);
      expect(response.message, equals('Network failure'));
    });

    test(
      'GetMarksCorrectionRequestsResponse parses full dataset correctly',
      () {
        final json = {
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
              'History': [
                {
                  'OldMarks': null,
                  'OldStatus': 'NA',
                  'CorrectionMarks': 38,
                  'CorrectionMarkStatus': 'PRESENT',
                  'Reason': 'By mistake Absent select',
                  'RequestedId': 3,
                  'RequestedBy': 'Bsan@icue',
                  'RequestedDate': '2026-09-12T06:46:07.262Z',
                  'Decision': 'Approved',
                  'ApprovedId': 3,
                  'ApprovedBy': 'Bsan@icue',
                  'ApprovedDate': '2026-09-12T06:47:36.260Z',
                  'Remarks': 'Marks verified and accepted by Principal',
                },
              ],
            },
          ],
        };

        final response = GetMarksCorrectionRequestsResponse.fromJson(json);

        expect(response.err, isFalse);
        expect(response.message, equals('Marks Correction Requests'));
        expect(response.data.length, equals(2));

        // First student
        final item1 = response.data[0];
        expect(item1.examId, equals(30));
        expect(item1.studentId, equals(41292));
        expect(item1.studentName, equals('Sree'));
        expect(item1.rollNo, equals('123123'));
        expect(item1.admissionNumber, equals('123123'));
        expect(item1.section, equals('A'));
        expect(item1.classId, equals(3890));
        expect(item1.standard, equals('Standard 10'));
        expect(item1.examName, equals('assignment test - 1'));
        expect(item1.subject, equals('Telugu'));
        expect(item1.maximumMarks, equals(50));
        expect(item1.passingMarks, equals(35));
        expect(item1.currentMarks, equals(35));
        expect(item1.currentStatus, equals('PRESENT'));
        expect(item1.correction, isNotNull);
        expect(item1.correction!.status, equals('Pending'));
        expect(item1.correction!.marks, equals(40));
        expect(item1.correction!.markStatus, equals('PRESENT'));
        expect(item1.correction!.reason, equals('Re-evaluation of question 4'));
        expect(item1.correction!.requestedBy, equals('sbranch'));
        expect(
          item1.correction!.requestedDate,
          equals(DateTime.parse('2026-09-12T06:13:10.716Z')),
        );
        expect(item1.history, isEmpty);

        // Second student
        final item2 = response.data[1];
        expect(item2.examId, equals(30));
        expect(item2.studentId, equals(41294));
        expect(item2.studentName, equals('T Varshitha Reddy'));
        expect(item2.rollNo, equals('TNS1234'));
        expect(item2.correction, isNotNull);
        expect(item2.correction!.status, equals('Pending'));
        expect(
          item2.correction!.statusAt,
          equals(DateTime.parse('2026-09-12T06:59:34.077Z')),
        );
        expect(item2.correction!.requestedId, equals(3));
        expect(item2.correction!.requestedBy, equals('Bsan@icue'));

        expect(item2.history.length, equals(1));
        final h = item2.history[0];
        expect(h.oldMarks, isNull);
        expect(h.oldStatus, equals('NA'));
        expect(h.correctionMarks, equals(38));
        expect(h.correctionMarkStatus, equals('PRESENT'));
        expect(h.reason, equals('By mistake Absent select'));
        expect(h.requestedId, equals(3));
        expect(h.requestedBy, equals('Bsan@icue'));
        expect(
          h.requestedDate,
          equals(DateTime.parse('2026-09-12T06:46:07.262Z')),
        );
        expect(h.decision, equals('Approved'));
        expect(h.approvedId, equals(3));
        expect(h.approvedBy, equals('Bsan@icue'));
        expect(
          h.approvedDate,
          equals(DateTime.parse('2026-09-12T06:47:36.260Z')),
        );
        expect(h.remarks, equals('Marks verified and accepted by Principal'));

        // Roundtrip test
        final outJson = response.toJson();
        expect(outJson['err'], isFalse);
        expect(outJson['data'], isList);
        expect((outJson['data'] as List).length, equals(2));
      },
    );

    test('MarksCorrectionItem copyWith works correctly', () {
      final item = MarksCorrectionItem(
        examId: 30,
        studentId: 41292,
        studentName: 'Sree',
        currentMarks: 35,
        currentStatus: 'PRESENT',
      );

      final copy = item.copyWith(currentMarks: 40, studentName: 'Sree Updated');

      expect(copy.examId, equals(30));
      expect(copy.studentId, equals(41292));
      expect(copy.currentMarks, equals(40));
      expect(copy.studentName, equals('Sree Updated'));
      expect(copy.currentStatus, equals('PRESENT'));
    });

    test('ApproveMarksCorrectionResponse parses success JSON correctly', () {
      final json = {
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

      final response = ApproveMarksCorrectionResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.err, isFalse);
      expect(
        response.message,
        equals('Marks correction request approved successfully'),
      );
      expect(response.examId, equals(30));
      expect(response.studentId, equals(41294));
      expect(response.decision, equals('Approved'));
      expect(response.marks, equals(38));
      expect(response.status, equals('PRESENT'));
      expect(response.approvedBy, equals('Bsan@icue'));
      expect(
        response.approvedDate,
        equals(DateTime.parse('2026-09-12T06:47:36.260Z')),
      );

      final outJson = response.toJson();
      expect(outJson['success'], isTrue);
      expect(outJson['err'], isFalse);
      expect(outJson['ExamId'], equals(30));
      expect(outJson['StudentId'], equals(41294));
      expect(outJson['Decision'], equals('Approved'));
      expect(outJson['Marks'], equals(38));
      expect(outJson['Status'], equals('PRESENT'));
      expect(outJson['ApprovedBy'], equals('Bsan@icue'));
      expect(outJson['ApprovedDate'], equals('2026-09-12T06:47:36.260Z'));
    });

    test('ApproveMarksCorrectionResponse parses error JSON correctly', () {
      final json = {
        'err': true,
        'message':
            'No pending marks correction request found for this student and exam',
      };

      final response = ApproveMarksCorrectionResponse.fromJson(json);

      expect(response.success, isFalse);
      expect(response.err, isTrue);
      expect(
        response.message,
        equals(
          'No pending marks correction request found for this student and exam',
        ),
      );
      expect(response.examId, isNull);
      expect(response.decision, isNull);

      final outJson = response.toJson();
      expect(outJson['success'], isFalse);
      expect(outJson['err'], isTrue);
      expect(outJson['message'], equals(response.message));
    });

    test('ApproveMarksCorrectionResponse.error creates valid error object', () {
      final response = ApproveMarksCorrectionResponse.error('Server error');
      expect(response.success, isFalse);
      expect(response.err, isTrue);
      expect(response.message, equals('Server error'));
    });
  });
}
