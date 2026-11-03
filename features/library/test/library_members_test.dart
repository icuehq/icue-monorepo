import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryPolicy and LibraryMember parse documents', () {
    final policy = LibraryPolicy.fromMap('l1_primary', {
      'name': 'Primary',
      'libraryId': 'l1',
      'memberCategory': 'primary',
      'maxBooks': 1,
      'loanDays': 7,
      'maxRenewals': 2,
      'maxFine': 50,
      'status': 'inactive',
    });
    expect(policy.summary, '1 book · 7 days · 2 renewals');
    expect(policy.maxFine, 50.0);
    expect(policy.fineType, 'none');
    expect(policy.active, isFalse);

    final member = LibraryMember.fromMap('teacher_9', {
      'memberType': 'teacher',
      'personErpId': 9,
      'libraryIds': ['l1'],
    });
    expect(member.label, 'Teacher #9');
    expect(member.active, isTrue);
    expect(member.libraryIds, ['l1']);
  });
}
