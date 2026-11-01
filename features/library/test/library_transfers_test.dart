import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryTransfer parses lines and lists pending copies', () {
    final transfer = LibraryTransfer.fromMap('t1', {
      'number': 'LTR/2026-27/000001',
      'fromLibraryId': 'a',
      'toLibraryId': 'b',
      'campusId': 31,
      'toCampusId': 32,
      'status': 'partially_received',
      'lineItems': [
        {
          'copyId': 'ACC-000001',
          'accessionNumber': 'ACC-000001',
          'received': true,
        },
        {
          'copyId': 'ACC-000002',
          'accessionNumber': 'ACC-000002',
          'received': false,
        },
      ],
    });
    expect(transfer.pending.map((transferLine) => transferLine.copyId), [
      'ACC-000002',
    ]);
    expect(transferStatusLabel(transfer.status), 'Partly received');
  });

  test('LibraryVerification computes copies not yet scanned', () {
    final verification = LibraryVerification.fromMap('v1', {
      'status': 'counting',
      'expected': ['ACC-000001', 'ACC-000002'],
      'scanned': ['ACC-000001'],
    });
    expect(verification.isCounting, isTrue);
    expect(verification.notYetScanned, ['ACC-000002']);
  });
}
