import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  InventoryPurchaseRequest pr(String status, {double ordered = 0}) =>
      InventoryPurchaseRequest.fromMap('p', {
        'status': status,
        'lineItems': [
          {
            'itemId': 'i',
            'quantity': 4,
            'estimatedPrice': 2.5,
            'quantityOrdered': ordered,
          },
        ],
        'history': [
          {'action': 'submit', 'comment': null},
        ],
      });

  test('status drives edit, approve and cancel', () {
    expect(pr('draft').isEditable, isTrue);
    expect(pr('revision_requested').isEditable, isTrue);
    expect(pr('pending').isEditable, isFalse);
    expect(pr('pending').isPending, isTrue);
    expect(pr('approved').isCancellable, isTrue);
    expect(pr('approved', ordered: 1).isCancellable, isFalse);
    expect(pr('rejected').isCancellable, isFalse);
    expect(pr('cancelled').isCancellable, isFalse);
  });

  test('parses lines, history and vendors', () {
    final purchaseRequest = pr('draft');
    expect(purchaseRequest.lineItems.single.estimatedPrice, 2.5);
    expect(purchaseRequest.history.single.action, 'submit');
    final vendor = InventoryVendor.fromMap('v', {
      'code': 'V1',
      'status': 'inactive',
    });
    expect(vendor.active, isFalse);
    expect(vendor.categoryIds, isEmpty);
  });
}
