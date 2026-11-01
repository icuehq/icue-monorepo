import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibFine parses fine document, calculations, waivals, payments, and statuses', () {
    final fine = LibFine.fromMap('f1', {
      'fineNumber': 'FIN/2026-27/000001',
      'memberId': 'student_501',
      'memberType': 'student',
      'personErpId': 501,
      'libraryId': 'lib1',
      'campusId': 31,
      'type': 'overdue',
      'amount': 25.0,
      'waived': 5.0,
      'paid': 10.0,
      'outstanding': 10.0,
      'status': 'partially_paid',
      'calc': {'overdueDays': 5, 'graceDays': 0, 'fineRate': 5},
      'waivals': [
        {
          'amount': 5.0,
          'reason': 'Principal discretionary',
          'by': 'u_admin',
          'at': '2026-11-01',
        },
      ],
      'payments': [
        {
          'amount': 10.0,
          'reference': 'RCP-999',
          'date': '2026-11-01',
          'by': 'u_staff',
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
    expect(fine.waivals, hasLength(1));
    expect(fine.waivals.first.reason, 'Principal discretionary');
    expect(fine.payments, hasLength(1));
    expect(fine.payments.first.reference, 'RCP-999');
    expect(fineStatusLabel(fine.status), 'Partially paid');
    expect(fineTypeLabel(fine.type), 'Overdue');
  });
}
