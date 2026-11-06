import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryPolicy and LibraryMember parse documents; a member shows its name, else its ID', () {
    final policy = LibraryPolicy.fromMap('l1_student', {
      'name': 'Students',
      'libraryId': 'l1',
      'memberType': 'student',
      'maxBooks': 1,
      'loanDays': 7,
      'maxRenewals': 2,
      'maxFine': 50,
      'status': 'inactive',
    });
    expect(policy.summary, '1 book · 7 days · 2 renewals');
    expect(policy.appliesTo, 'Students');
    expect(policy.maxFine, 50.0);
    expect(policy.fineType, 'none');
    expect(policy.active, isFalse);

    final member = LibraryMember.fromMap('teacher_9', {
      'memberType': 'teacher',
      'personErpId': 9,
    });
    expect(member.label, 'Teacher #9');
    expect(member.blocked, isFalse);
    expect(member.activeLoans, 0);

    final named = LibraryMember.fromMap('student_5', {
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
}
