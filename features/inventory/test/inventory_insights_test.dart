import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('verification line difference is counted minus expected', () {
    const verificationLine = VerificationLine(
      balanceId: 'b',
      itemId: 'i',
      expected: 10,
      counted: 8,
    );
    expect(verificationLine.difference, -2);
    expect(
      const VerificationLine(
        balanceId: 'b',
        itemId: 'i',
        expected: 10,
      ).difference,
      isNull,
    );
    final verification = InventoryVerification.fromMap('v', {
      'status': 'submitted',
      'differenceCount': 2,
    });
    expect(verification.submitted, isTrue);
    expect(verification.counting, isFalse);
  });

  test('every report has a unique key and columns', () {
    expect(
      inventoryReports.map((reportDef) => reportDef.key).toSet().length,
      inventoryReports.length,
    );
    expect(inventoryReports.length, 16);
    expect(
      inventoryReports.every((reportDef) => reportDef.cols.isNotEmpty),
      isTrue,
    );
  });
}
