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

  test(
    'CSV parses what toCsv writes, plus CRLF, blank lines and short rows',
    () {
      final text = toCsv(
        ['code', 'name'],
        [
          ['A', 'say "hi", ok'],
          ['B', 'two\nlines'],
        ],
      );
      expect(parseCsv(text), [
        {'code': 'A', 'name': 'say "hi", ok'},
        {'code': 'B', 'name': 'two\nlines'},
      ]);
      expect(parseCsv(' code , name \r\n\r\nX\r\n'), [
        {'code': 'X', 'name': ''},
      ]);
      expect(parseCsv(''), isEmpty);
    },
  );

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
