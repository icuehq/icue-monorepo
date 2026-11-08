import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryFine parses fine document, calculations, waivers, payments, and statuses', () {
    final fine = LibraryFine.fromMap('f1', {
      'fineNumber': 'FIN/2026-27/000001',
      'personErpId': 501,
      'memberType': 'student',
      'libraryId': 'lib1',
      'campusId': 31,
      'type': 'overdue',
      'amount': 25.0,
      'waived': 5.0,
      'paid': 10.0,
      'outstanding': 10.0,
      'status': 'partially_paid',
      'fineCalculation': {'overdueDays': 5, 'graceDays': 0, 'fineRate': 5},
      'waivers': [
        {
          'amount': 5.0,
          'reason': 'Principal discretionary',
          'performedBy': '31',
          'performedAt': dayTimestamp('2026-11-01'),
        },
      ],
      'payments': [
        {
          'amount': 10.0,
          'reference': 'RCP-999',
          'date': dayTimestamp('2026-11-01'),
          'performedBy': '31',
        },
      ],
    });

    expect(fine.fineNumber, 'FIN/2026-27/000001');
    expect(fine.memberLabel, 'Student #501');
    expect(fine.amount, 25.0);
    expect(fine.waived, 5.0);
    expect(fine.paid, 10.0);
    expect(fine.outstanding, 10.0);
    expect(fine.isOutstanding, isTrue);
    expect(fine.waivers, hasLength(1));
    expect(fine.waivers.first.reason, 'Principal discretionary');
    expect(fine.payments, hasLength(1));
    expect(fine.payments.first.reference, 'RCP-999');
    expect(fineTypeLabel(fine.type), 'Overdue');
  });
}
