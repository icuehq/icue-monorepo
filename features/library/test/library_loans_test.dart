import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryLoan parses a document and counts overdue days', () {
    final loan = LibraryLoan.fromMap('x', {
      'memberType': 'EMPLOYEE',
      'personErpId': 9,
      'dueDate': dayTimestamp('2026-11-01'),
      'renewals': [<String, Object?>{}],
      'policySnapshot': {'maxRenewals': 2},
      'status': 'active',
    });
    expect(loan.memberLabel, 'Employee #9');
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

  test('fineOn skips the grace days, then charges per day or flat, capped', () {
    LibraryLoan loan(String type, {double? cap}) => LibraryLoan.fromMap('x', {
      'dueDate': dayTimestamp('2026-11-01'),
      'status': 'active',
      'policySnapshot': {
        'graceDays': 2,
        'fineType': type,
        'fineAmount': 5,
        'maxFine': cap,
      },
    });
    expect(loan('per_day').fineOn('2026-11-03'), 0);
    expect(loan('per_day').fineOn('2026-11-06'), 15);
    expect(loan('per_day', cap: 10).fineOn('2026-11-11'), 10);
    expect(loan('flat').fineOn('2026-11-04'), 5);
    expect(loan('none').fineOn('2026-11-30'), 0);
  });
}
