import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryLoan parses a document and counts overdue days', () {
    final loan = LibraryLoan.fromMap('x', {
      'memberType': 'teacher',
      'personErpId': 9,
      'dueDate': dayTimestamp('2026-11-01'),
      'renewals': [<String, Object?>{}],
      'policySnapshot': {'maxRenewals': 2},
      'status': 'active',
    });
    expect(loan.memberLabel, 'Teacher #9');
    expect(loan.canRenew, isTrue);
    expect(loan.overdueOn('2026-11-04'), 3);
    expect(loan.overdueOn('2026-11-01'), 0);
    expect(
      LibraryLoan.fromMap('y', {
        'dueDate': dayTimestamp('2026-01-01'),
        'status': 'returned',
      }).overdueOn('2026-11-01'),
      0,
    );
  });
}
