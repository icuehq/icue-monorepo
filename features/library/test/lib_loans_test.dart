import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibLoan parses a document and counts overdue days', () {
    final l = LibLoan.fromMap('x', {
      'memberType': 'teacher',
      'personErpId': 9,
      'dueOn': '2026-11-01',
      'renewals': [<String, Object?>{}],
      'policySnapshot': {'maxRenewals': 2},
      'status': 'active',
    });
    expect(l.memberLabel, 'Teacher #9');
    expect(l.canRenew, isTrue);
    expect(l.overdueOn('2026-11-04'), 3);
    expect(l.overdueOn('2026-11-01'), 0);
    expect(
      LibLoan.fromMap('y', {
        'dueOn': '2026-01-01',
        'status': 'returned',
      }).overdueOn('2026-11-01'),
      0,
    );
  });
}
