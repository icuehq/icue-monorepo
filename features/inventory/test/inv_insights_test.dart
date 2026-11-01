import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('CSV quotes only cells that need it', () {
    expect(
      toCsv(
        ['A', 'B'],
        [
          ['x,y', 'say "hi"'],
          ['1', ''],
        ],
      ),
      'A,B\n"x,y","say ""hi"""\n1,',
    );
  });

  test('verification line difference is counted minus expected', () {
    const l = VerificationLine(
      balanceId: 'b',
      itemId: 'i',
      expected: 10,
      counted: 8,
    );
    expect(l.diff, -2);
    expect(
      const VerificationLine(balanceId: 'b', itemId: 'i', expected: 10).diff,
      isNull,
    );
    final v = InvVerification.fromMap('v', {
      'status': 'submitted',
      'diffCount': 2,
    });
    expect(v.submitted, isTrue);
    expect(v.counting, isFalse);
  });

  test(
    'every report has a unique key and columns; string dates are day-only',
    () {
      expect(
        inventoryReports.map((r) => r.key).toSet().length,
        inventoryReports.length,
      );
      expect(inventoryReports.length, 17);
      expect(inventoryReports.every((r) => r.cols.isNotEmpty), isTrue);
      expect(dayOf('2026-11-01T10:00'), '2026-11-01');
      expect(dayOf(null), '');
    },
  );
}
