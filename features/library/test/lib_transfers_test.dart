import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibTransfer parses lines and lists pending copies', () {
    final t = LibTransfer.fromMap('t1', {
      'number': 'LTR/2026-27/000001',
      'fromLibraryId': 'a',
      'toLibraryId': 'b',
      'campusId': 31,
      'toCampusId': 32,
      'status': 'partially_received',
      'lines': [
        {'copyId': 'ACC-000001', 'accessionNo': 'ACC-000001', 'received': true},
        {
          'copyId': 'ACC-000002',
          'accessionNo': 'ACC-000002',
          'received': false,
        },
      ],
    });
    expect(t.pending.map((l) => l.copyId), ['ACC-000002']);
    expect(transferStatusLabel(t.status), 'Partly received');
  });

  test('LibVerification computes copies not yet scanned', () {
    final v = LibVerification.fromMap('v1', {
      'status': 'counting',
      'expected': ['ACC-000001', 'ACC-000002'],
      'scanned': ['ACC-000001'],
    });
    expect(v.isCounting, isTrue);
    expect(v.notYetScanned, ['ACC-000002']);
  });
}
