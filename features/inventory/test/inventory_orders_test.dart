import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('quotation and PO lines parse quantity / quantityOrdered; PO status helpers', () {
    final quotation = InventoryQuotation.fromMap('q', {
      'purchaseRequestId': 'pr',
      'selected': true,
      'total': 590,
      'lineItems': [
        {'itemId': 'i', 'quantity': 100, 'unitPrice': 4},
      ],
    });
    expect(quotation.lineItems.single.quantity, 100);
    expect(quotation.selected, isTrue);

    final purchaseOrder = InventoryPurchaseOrder.fromMap('p', {
      'status': 'acknowledged',
      'purchaseRequestIds': ['pr'],
      'lineItems': [
        {
          'itemId': 'i',
          'quantityOrdered': 60,
          'quantityReceived': 10,
          'unitPrice': 5,
        },
      ],
    });
    expect(purchaseOrder.purchaseRequestId, 'pr');
    expect(purchaseOrder.lineItems.single.quantity, 60);
    expect(purchaseOrder.lineItems.single.quantityReceived, 10);
    expect([
      purchaseOrder.canRevise,
      purchaseOrder.canCancel,
      purchaseOrder.canClose,
    ], everyElement(isTrue));
    expect(
      InventoryPurchaseOrder.fromMap('p', {'status': 'closed'}).canCancel,
      isFalse,
    );
  });
}
