import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('balance and quantity formatting', () {
    final balance = InventoryBalance.fromMap('s__i__-__-', {
      'storeId': 's',
      'itemId': 'i',
      'quantityAvailable': 7,
      'totalQuantityIssued': 2.5,
      'isBelowReorderLevel': true,
    });
    expect(balance.available, 7);
    expect(balance.issuedTotal, 2.5);
    expect(balance.isBelowReorderLevel, isTrue);
    expect(balance.batchNumber, isNull);
  });

  test('request status drives which actions apply', () {
    InventoryIssueRequest request(String status) =>
        InventoryIssueRequest.fromMap('r', {
          'status': status,
          'lineItems': [
            {
              'itemId': 'i',
              'quantityRequested': 4,
              'quantityApproved': null,
              'quantityIssued': 0,
            },
          ],
        });
    expect(request('pending').isPending, isTrue);
    expect(request('approved').isIssuable, isTrue);
    expect(request('partially_issued').isIssuable, isTrue);
    expect(request('issued').isIssuable, isFalse);
    expect(request('pending').lineItems.single.approved, isNull);
  });

  test('issue line outstanding', () {
    final issueLine = IssueLine.fromMap({
      'quantity': 6,
      'quantityReturned': 4,
      'balanceId': 'b',
    });
    expect(issueLine.outstanding, 2);
  });
}
