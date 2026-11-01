import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibPolicy and LibMember parse documents', () {
    final p = LibPolicy.fromMap('l1_primary', {
      'name': 'Primary',
      'libraryId': 'l1',
      'memberCategory': 'primary',
      'maxBooks': 1,
      'loanDays': 7,
      'maxRenewals': 2,
      'maxFine': 50,
      'status': 'inactive',
    });
    expect(p.summary, '1 book · 7 days · 2 renewals');
    expect(p.maxFine, 50.0);
    expect(p.fineType, 'none');
    expect(p.active, isFalse);

    final m = LibMember.fromMap('teacher_9', {
      'memberType': 'teacher',
      'erpId': 9,
      'libraryIds': ['l1'],
    });
    expect(m.label, 'Teacher #9');
    expect(m.active, isTrue);
    expect(m.libraryIds, ['l1']);
  });
}
