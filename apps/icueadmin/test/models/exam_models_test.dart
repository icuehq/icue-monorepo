import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/exam_marks.dart';
import 'package:icueadmin/models/exam_results.dart';
import 'package:icueadmin/models/exam_schedule.dart';
import 'package:icueadmin/models/marks.dart';
import 'package:icueadmin/models/prep_exam.dart';
import 'package:icueadmin/pages/exams/exam_helpers.dart';

void main() {
  group('Exam Models Tests', () {
    test('ExamSchedule parses JSON and roundtrips', () {
      final json = {
        'Id': 501,
        'AcademicYear': '2026-2027',
        'ExamName': 'Unit Test 1',
        'ClassId': 10,
        'Section': 'A',
        'SubjectId': 101,
        'Subject': 'Mathematics',
        'ExamType': 'OFFLINE',
        'ExamDate': '2026-04-15',
        'MaximumMarks': 100,
        'PassingMarks': 35,
        'IsPublished': false,
        'Status': 'DRAFT',
      };

      final schedule = ExamSchedule.fromJson(json);

      expect(schedule.id, equals(501));
      expect(schedule.academicYear, equals('2026-2027'));
      expect(schedule.examName, equals('Unit Test 1'));
      expect(schedule.classId, equals(10));
      expect(schedule.section, equals('A'));
      expect(schedule.subjectId, equals(101));
      expect(schedule.subject, equals('Mathematics'));
      expect(schedule.examType, equals('OFFLINE'));
      expect(schedule.examDate, equals('2026-04-15'));
      expect(schedule.maximumMarks, equals(100));
      expect(schedule.passingMarks, equals(35));
      expect(schedule.isPublished, isFalse);
      expect(schedule.status, equals('DRAFT'));

      final outJson = schedule.toJson();
      expect(outJson['Id'], equals(501));
      expect(outJson['ExamName'], equals('Unit Test 1'));
    });

    test(
      'ExamSchedule copyWith updates fields and preserves unmodified fields',
      () {
        final schedule = ExamSchedule(
          id: 501,
          academicYear: '2026-2027',
          examName: 'Unit Test 1',
          classId: 10,
          section: 'A',
          subjectId: 101,
          subject: 'Mathematics',
          examType: 'OFFLINE',
          examDate: '2026-04-15',
          maximumMarks: 100,
          passingMarks: 35,
          standard: 'Grade 10',
          status: 'DRAFT',
        );

        final updated = schedule.copyWith(
          isPublished: true,
          status: 'PUBLISHED',
        );

        expect(updated.id, equals(501));
        expect(updated.academicYear, equals('2026-2027'));
        expect(updated.examName, equals('Unit Test 1'));
        expect(updated.classId, equals(10));
        expect(updated.section, equals('A'));
        expect(updated.subjectId, equals(101));
        expect(updated.subject, equals('Mathematics'));
        expect(updated.standard, equals('Grade 10'));
        expect(updated.isPublished, isTrue);
        expect(updated.status, equals('PUBLISHED'));
      },
    );

    test(
      'ExamStudent and ExamMarksEntry handle numeric marks, ABSENT, and NA status',
      () {
        final studentsJson = [
          {
            'StudentId': 12001,
            'RollNo': '10-A-01',
            'StudentName': 'Aarav Sharma',
            'Marks': 85,
            'Status': 'PRESENT',
          },
          {
            'StudentId': 12002,
            'RollNo': '10-A-02',
            'StudentName': 'Diya Patel',
            'Marks': null,
            'Status': 'ABSENT',
          },
          {
            'StudentId': 12003,
            'RollNo': '10-A-03',
            'StudentName': 'Ishaan Verma',
            'Marks': null,
            'Status': 'NA',
          },
        ];

        final students = studentsJson
            .map((x) => ExamStudent.fromJson(x))
            .toList();

        expect(students[0].studentId, equals(12001));
        expect(students[0].name, equals('Aarav Sharma'));
        expect(students[0].marks, equals(85));
        expect(students[0].status, equals('PRESENT'));

        expect(students[1].studentId, equals(12002));
        expect(students[1].marks, isNull);
        expect(students[1].status, equals('ABSENT'));

        expect(students[2].studentId, equals(12003));
        expect(students[2].marks, isNull);
        expect(students[2].status, equals('NA'));

        // Test ExamMarksEntry mapping
        final entryPresent = ExamMarksEntry(studentId: 12001, marks: 85);
        expect(
          entryPresent.toJson(),
          equals({'StudentId': 12001, 'Marks': 85}),
        );

        final entryAbsent = ExamMarksEntry(studentId: 12002, status: 'ABSENT');
        expect(
          entryAbsent.toJson(),
          equals({'StudentId': 12002, 'Status': 'ABSENT'}),
        );

        final entryNa = ExamMarksEntry(studentId: 12003, status: 'NA');
        expect(entryNa.toJson(), equals({'StudentId': 12003, 'Status': 'NA'}));
      },
    );

    test('ExamStudent parses from getExamStudents and getExamMarks APIs', () {
      final studentApiJson = {
        'Id': 789,
        'ClassId': 6160,
        'Name': 'Chakri',
        'RollNo': 'C01',
        'Section': 'A',
        'AdmissionNumber': 'ADM-2026-001',
        'Marks': 20,
        'Status': 'PRESENT',
        'Remarks': 'pass',
      };

      final student = ExamStudent.fromJson(studentApiJson);
      expect(student.studentId, equals(789));
      expect(student.classId, equals(6160));
      expect(student.name, equals('Chakri'));
      expect(student.rollNo, equals('C01'));
      expect(student.section, equals('A'));
      expect(student.admissionNumber, equals('ADM-2026-001'));
      expect(student.marks, equals(20));
      expect(student.status, equals('PRESENT'));
      expect(student.remarks, equals('pass'));
      expect(student.isSaved, isTrue);

      final copy = student.copyWith(
        marks: 25,
        remarks: 'excellent',
        isSaved: false,
      );
      expect(copy.marks, equals(25));
      expect(copy.remarks, equals('excellent'));
      expect(copy.isSaved, isFalse);
    });

    test('ExamResult parses calculated results from Postman response', () {
      final resultsJson = [
        {
          'StudentId': 12001,
          'RollNo': '10-A-01',
          'StudentName': 'Aarav Sharma',
          'TotalMarks': 82,
          'MaximumMarks': 100,
          'Percentage': 82.0,
          'Grade': 'A',
          'Rank': 1,
          'Result': 'PASS',
          'Subjects': [
            {
              'SubjectId': 101,
              'Subject': 'Mathematics',
              'Marks': 82,
              'MaximumMarks': 100,
              'PassingMarks': 35,
              'Status': 'PRESENT',
              'Result': 'PASS',
            },
          ],
        },
      ];

      final results = resultsJson.map((x) => ExamResult.fromJson(x)).toList();

      expect(results.length, equals(1));
      final res = results.first;
      expect(res.studentId, equals(12001));
      expect(res.studentName, equals('Aarav Sharma'));
      expect(res.rollNo, equals('10-A-01'));
      expect(res.totalMarks, equals(82));
      expect(res.maximumMarks, equals(100));
      expect(res.percentage, equals(82.0));
      expect(res.grade, equals('A'));
      expect(res.rank, equals(1));
      expect(res.result, equals('PASS'));

      expect(res.subjectMarks, isNotNull);
      expect(res.subjectMarks!.length, equals(1));
      final sub = res.subjectMarks!.first;
      expect(sub.subjectId, equals(101));
      expect(sub.subject, equals('Mathematics'));
      expect(sub.marks, equals(82));
      expect(sub.maximumMarks, equals(100));
      expect(sub.passingMarks, equals(35));
      expect(sub.result, equals('PASS'));
    });

    test(
      'ExamHelpers.getAvailableAcademicYears generates from current down to 2016',
      () {
        final currentYear = ExamHelpers.getCurrentAcademicYear();
        final years = ExamHelpers.getAvailableAcademicYears();

        expect(years.first, equals('All years'));
        expect(years.contains(currentYear), isTrue);
        expect(years.contains('2026-2027'), isTrue);
        expect(years.contains('2025-2026'), isTrue);
        expect(years.contains('2024-2025'), isTrue);
        expect(years.contains('2023-2024'), isTrue);
        expect(years.contains('2022-2023'), isTrue);
        expect(years.contains('2021-2022'), isTrue);
        expect(years.contains('2020-2021'), isTrue);
        expect(years.contains('2019-2020'), isTrue);
        expect(years.contains('2018-2019'), isTrue);
        expect(years.contains('2017-2018'), isTrue);
        expect(years.last, equals('2016-2017'));
      },
    );

    test('PrepExam parses response from /v1.0/getPrepExams', () {
      final jsonList = [
        {
          'OrganizationId': 19,
          'ZoneId': 13,
          'BranchId': 17,
          'AcademicYear': '2026-2027',
          'ExamName': 'Quarterly Exam 1',
          'ExamType': 'Quarterly',
          'MaximumMarks': 100,
          'PassingMarks': 36,
          'StartDate': '2026-09-14',
          'EndDate': '2026-09-18',
          'IsActive': false,
          'Status': 'Inactive',
          'CreatedBy': 'tnxsivani',
          'CreatedDate': '2026-09-11T13:59:14.028Z',
          'Id': 10,
          'UpdatedBy': 'tnxsivani',
          'UpdatedDate': '2026-09-11T14:00:40.316Z',
        },
        {
          'OrganizationId': 19,
          'ZoneId': 13,
          'BranchId': 17,
          'AcademicYear': '2026-2027',
          'ExamName': 'Unit Test 1',
          'ExamType': 'Monthly Tests',
          'MaximumMarks': 30,
          'PassingMarks': 10,
          'StartDate': '2026-09-07',
          'EndDate': '2026-09-12',
          'IsActive': true,
          'Status': 'Active',
          'CreatedBy': 'tnxsivani',
          'CreatedDate': '2026-09-11T13:55:55.233Z',
          'Id': 8,
        },
      ];

      final prepExams = jsonList.map((x) => PrepExam.fromJson(x)).toList();

      expect(prepExams.length, equals(2));
      expect(prepExams[0].id, equals(10));
      expect(prepExams[0].examName, equals('Quarterly Exam 1'));
      expect(prepExams[0].examType, equals('Quarterly'));
      expect(prepExams[0].maximumMarks, equals(100));
      expect(prepExams[0].passingMarks, equals(36));
      expect(prepExams[0].isActive, isFalse);
      expect(prepExams[0].status, equals('Inactive'));

      expect(prepExams[1].id, equals(8));
      expect(prepExams[1].examName, equals('Unit Test 1'));
      expect(prepExams[1].examType, equals('Monthly Tests'));
      expect(prepExams[1].maximumMarks, equals(30));
      expect(prepExams[1].passingMarks, equals(10));
      expect(prepExams[1].isActive, isTrue);
      expect(prepExams[1].status, equals('Active'));

      final outJson = prepExams[0].toJson();
      expect(outJson['Id'], equals(10));
      expect(outJson['ExamName'], equals('Quarterly Exam 1'));
    });

    test(
      'ExamSchedule parses getExamSchedules API response and filters only Status: Published',
      () {
        final apiResponse = [
          {
            'OrganizationId': 19,
            'ZoneId': 13,
            'BranchId': 17,
            'AcademicYear': '2026-2027',
            'ClassId': 6160,
            'Section': 'A',
            'SubjectId': 1,
            'Subject': 'Telugu',
            'Standard': 'Grade 1',
            'ExamName': 'Unit Test 1',
            'ExamType': 'Monthly Tests',
            'ExamDate': '2026-09-07',
            'MaximumMarks': 30,
            'PassingMarks': 10,
            'Status': 'Published',
            'IsActive': true,
            'Id': 14,
          },
          {
            'OrganizationId': 19,
            'ZoneId': 13,
            'BranchId': 17,
            'AcademicYear': '2026-2027',
            'ClassId': 6160,
            'Section': 'A',
            'SubjectId': 5,
            'Subject': 'Maths',
            'Standard': 'Grade 1',
            'ExamName': 'Unit Test 1',
            'ExamType': 'Monthly Tests',
            'ExamDate': '2026-09-10',
            'MaximumMarks': 30,
            'PassingMarks': 10,
            'Status': 'Draft',
            'IsActive': true,
            'Id': 17,
          },
        ];

        final allSchedules = apiResponse
            .map((x) => ExamSchedule.fromJson(x))
            .toList();
        expect(allSchedules.length, equals(2));

        // First item is Published
        expect(allSchedules[0].id, equals(14));
        expect(allSchedules[0].subject, equals('Telugu'));
        expect(allSchedules[0].standard, equals('Grade 1'));
        expect(allSchedules[0].status, equals('Published'));
        expect(allSchedules[0].isPublished, isTrue);

        // Second item is Draft
        expect(allSchedules[1].id, equals(17));
        expect(allSchedules[1].subject, equals('Maths'));
        expect(allSchedules[1].status, equals('Draft'));
        expect(allSchedules[1].isPublished, isFalse);

        // Only Published data
        final publishedOnly = allSchedules
            .where(
              (s) => s.status?.toLowerCase() == 'published' || s.isPublished,
            )
            .toList();
        expect(publishedOnly.length, equals(1));
        expect(publishedOnly[0].id, equals(14));
        expect(publishedOnly[0].subject, equals('Telugu'));
      },
    );

    test(
      'saveExamMarks contract: request payload format and response structure',
      () {
        final student = ExamStudent(
          studentId: 32943,
          name: 'John Doe',
          marks: 21,
          remarks: 'pass',
        );

        final upperStatus = student.status.trim().toUpperCase();
        final entry = <String, dynamic>{'StudentId': student.studentId};
        if (upperStatus == 'ABSENT' || upperStatus == 'NA') {
          entry['Status'] = upperStatus;
        } else {
          entry['Marks'] = student.marks ?? 0;
          entry['Status'] = '';
        }
        entry['Remarks'] = student.remarks?.trim() ?? '';

        final requestPayload = {
          'ExamId': 15,
          'Marks': [entry],
          'Source': 'web',
          'AppName': 'WebPortal',
          'source': 'Web',
          'InitiatedDate': '9/15/2026',
          'InitiatedTime': '9:41:13 AM',
        };

        expect(requestPayload['ExamId'], equals(15));
        expect(requestPayload['Source'], equals('web'));
        expect(requestPayload['AppName'], equals('WebPortal'));
        expect(requestPayload['source'], equals('Web'));
        expect(requestPayload['InitiatedDate'], equals('9/15/2026'));
        expect(requestPayload['InitiatedTime'], equals('9:41:13 AM'));

        final marksList = requestPayload['Marks'] as List<Map<String, dynamic>>;
        expect(marksList.length, equals(1));
        expect(marksList[0]['StudentId'], equals(32943));
        expect(marksList[0]['Marks'], equals(21));
        expect(marksList[0]['Status'], equals(''));
        expect(marksList[0]['Remarks'], equals('pass'));

        // Response parsing
        final responseJson = {'saved': 1, 'ExamId': 15};
        final isSaved = responseJson['saved'] == 1;
        expect(isSaved, isTrue);
        expect(responseJson['ExamId'], equals(15));
      },
    );

    test('ExamMarks handles decimal scores and string conversions safely', () {
      final json = {
        'StudentId': '32001',
        'ExamId': '55',
        'Marks': '42.5',
        'Status': 'Active',
        'Remarks': 'Good',
      };

      final marks = ExamMarks.fromJson(json);
      expect(marks.studentId, equals(32001));
      expect(marks.examId, equals(55));
      expect(marks.marks, equals(42.5));
      expect(marks.status, equals('Active'));
      expect(marks.remarks, equals('Good'));

      final out = marks.toJson();
      expect(out['StudentId'], equals(32001));
      expect(out['Marks'], equals(42.5));
    });

    test('ExamStudent correctly distinguishes pending vs saved students', () {
      // Pending student: Active status from getExamStudents but no marks yet
      final pendingJson = {
        'Id': 101,
        'Name': 'Rahul',
        'Status': 'Active',
        'Marks': null,
      };
      final pendingStudent = ExamStudent.fromJson(pendingJson);
      expect(pendingStudent.isSaved, isFalse);
      expect(pendingStudent.marks, isNull);
      expect(pendingStudent.status, equals('PRESENT'));

      // Saved student: has marks
      final savedJson = {
        'Id': 102,
        'Name': 'Priya',
        'Status': 'PRESENT',
        'Marks': 28.5,
      };
      final savedStudent = ExamStudent.fromJson(savedJson);
      expect(savedStudent.isSaved, isTrue);
      expect(savedStudent.marks, equals(28.5));

      // Saved student: ABSENT
      final absentJson = {'Id': 103, 'Name': 'Ankit', 'Status': 'ABSENT'};
      final absentStudent = ExamStudent.fromJson(absentJson);
      expect(absentStudent.isSaved, isTrue);
      expect(absentStudent.status, equals('ABSENT'));

      // Saved student: NA
      final naJson = {'Id': 104, 'Name': 'Sara', 'Status': 'NA'};
      final naStudent = ExamStudent.fromJson(naJson);
      expect(naStudent.isSaved, isTrue);
      expect(naStudent.status, equals('NA'));
    });

    test(
      'ExamResult and SubjectMark validate isPassed, isFailed, and displayPercentage',
      () {
        final passResult = ExamResult(
          studentId: 1,
          studentName: 'Student 1',
          result: 'PASSED',
          percentage: 85.5,
        );
        expect(passResult.isPassed, isTrue);
        expect(passResult.isFailed, isFalse);
        expect(passResult.displayPercentage, equals('85.50%'));

        final failResult = ExamResult(
          studentId: 2,
          studentName: 'Student 2',
          result: 'FAIL',
          percentage: 32.0,
        );
        expect(failResult.isPassed, isFalse);
        expect(failResult.isFailed, isTrue);
        expect(failResult.displayPercentage, equals('32%'));

        final naResult = ExamResult(
          studentId: 3,
          studentName: 'Student 3',
          result: 'N/A',
        );
        expect(naResult.isPassed, isFalse);
        expect(naResult.isFailed, isFalse);

        // SubjectMark pass check with marks >= passingMarks
        final subPass = SubjectMark(
          subjectId: 1,
          subject: 'Math',
          marks: 40,
          passingMarks: 35,
        );
        expect(subPass.isPassed, isTrue);

        final subFail = SubjectMark(
          subjectId: 1,
          subject: 'Math',
          marks: 30,
          passingMarks: 35,
        );
        expect(subFail.isPassed, isFalse);
      },
    );

    test(
      'ExamStudent handles hasExistingMarks and isCorrectionPending correctly',
      () {
        // Case 1: Student with existing marks
        final studentWithMarks = ExamStudent.fromJson({
          'StudentId': 101,
          'StudentName': 'Alice',
          'Marks': 45,
          'Status': 'PRESENT',
        });
        expect(studentWithMarks.hasExistingMarks, isTrue);
        expect(studentWithMarks.isCorrectionPending, isFalse);

        // Case 2: Student marked as ABSENT
        final studentAbsent = ExamStudent.fromJson({
          'StudentId': 102,
          'StudentName': 'Bob',
          'Marks': null,
          'Status': 'ABSENT',
        });
        expect(studentAbsent.hasExistingMarks, isTrue);

        // Case 3: Fresh student with no marks
        final freshStudent = ExamStudent.fromJson({
          'StudentId': 103,
          'StudentName': 'Charlie',
          'Marks': null,
          'Status': 'Active',
        });
        expect(freshStudent.hasExistingMarks, isFalse);
        expect(freshStudent.isCorrectionPending, isFalse);

        // Case 4: Student with pending correction object
        final pendingStudent = ExamStudent.fromJson({
          'StudentId': 104,
          'StudentName': 'Diana',
          'Marks': 30,
          'Status': 'PRESENT',
          'Correction': {
            'Status': 'Pending',
            'Marks': 38,
            'MarkStatus': 'PRESENT',
            'Reason': 'Review needed',
          },
        });
        expect(pendingStudent.hasExistingMarks, isTrue);
        expect(pendingStudent.isCorrectionPending, isTrue);
        expect(pendingStudent.correction, isNotNull);
        expect(pendingStudent.correction?.marks, equals(38));

        // Test copyWith
        final updated = pendingStudent.copyWith(
          isCorrectionPending: false,
          hasExistingMarks: false,
        );
        expect(updated.isCorrectionPending, isFalse);
        expect(updated.hasExistingMarks, isFalse);
      },
    );
  });
}
