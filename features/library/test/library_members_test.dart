import 'package:flutter_test/flutter_test.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/services/library_people_service.dart';

class _FakeRouteService implements RouteService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<StudentData?> searchStudentByAdmissionNumber(
    String admissionNumber,
  ) async {
    if (admissionNumber == 'ADM001') {
      return const StudentData(
        id: 10,
        name: 'Student 10',
        admissionNumber: 'ADM001',
      );
    }
    return null;
  }
}

void main() {
  test('LibraryPolicy and LibraryMember parse documents; a member shows its name, else its ID', () {
    final policy = LibraryPolicy.fromMap('l1_student', {
      'name': 'Students',
      'libraryId': 'l1',
      'memberType': 'student',
      'maxBooks': 1,
      'loanDays': 7,
      'maxRenewals': 2,
      'fineType': 'none',
      'maxFine': 50,
      'status': 'inactive',
    });
    expect(policy.summary, '1 book · 7 days · 2 renewals');
    expect(policy.appliesTo, 'Students');
    expect(policy.maxFine, 50.0);
    expect(policy.fineType, 'none');
    expect(policy.active, isFalse);

    final member = LibraryMember.fromMap('9', {
      'memberType': 'teacher',
      'personErpId': 9,
    });
    expect(member.label, 'Teacher #9');
    expect(member.blocked, isFalse);
    expect(member.activeLoans, 0);

    final named = LibraryMember.fromMap('5', {
      'memberType': 'student',
      'personErpId': 5,
      'name': 'Asha Rao',
      'classId': 4,
      'activeLoans': 2,
      'blocked': true,
    });
    expect(named.label, 'Asha Rao');
    expect(named.classId, 4);
    expect(named.blocked, isTrue);
  });

  test(
    'LibraryPeopleService looks up students by admission and staff by ID',
    () async {
      final peopleService = LibraryPeopleService(_FakeRouteService());

      final student = await peopleService.findByAdmissionNumber(
        'student',
        'ADM001',
      );
      expect(student?.personErpId, 10);
      expect(student?.name, 'Student 10');
      expect(student?.memberType, 'student');

      final missingStudent = await peopleService.findByAdmissionNumber(
        'student',
        'UNKNOWN',
      );
      expect(missingStudent, isNull);

      final staff = await peopleService.findByAdmissionNumber('teacher', '42');
      expect(staff?.personErpId, 42);
      expect(staff?.name, 'Staff #42');
      expect(staff?.memberType, 'teacher');

      final invalidStaff = await peopleService.findByAdmissionNumber(
        'teacher',
        'abc',
      );
      expect(invalidStaff, isNull);
    },
  );
}
