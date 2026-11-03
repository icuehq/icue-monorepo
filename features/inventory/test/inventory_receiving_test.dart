import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('PO line due and receive eligibility', () {
    final purchaseOrder = InventoryPurchaseOrder.fromMap('p', {
      'status': 'partially_received',
      'lineItems': [
        {
          'itemId': 'i',
          'quantityOrdered': 100,
          'quantityAccepted': 40,
          'quantityRejected': 10,
          'unitPrice': 5,
        },
      ],
    });
    expect(purchaseOrder.lineItems.single.due, 60); // rejected units stay due
    expect(purchaseOrder.canReceive, isTrue);
    expect(
      InventoryPurchaseOrder.fromMap('p', {'status': 'draft'}).canReceive,
      isFalse,
    );
  });

  test(
    'GRN parses inspection result; invoice turns overdue after its due date',
    () {
      final goodsReceipt = InventoryGoodsReceipt.fromMap('g', {
        'number': 'GRN/2026-27/000001',
        'inspection': {'result': 'partial'},
        'lineItems': [
          {'itemId': 'i', 'quantityAccepted': 4, 'quantityRejected': 1},
        ],
      });
      expect(goodsReceipt.result, 'partial');
      expect(goodsReceipt.lineItems.single.rejected, 1);

      InventoryInvoice invoice(String status, String? due) =>
          InventoryInvoice.fromMap('i', {
            'paymentStatus': status,
            'dueDate': due,
            'total': 100,
          });
      expect(invoice('unpaid', '2026-10-01').statusOn('2026-11-01'), 'overdue');
      expect(
        invoice('partially_paid', '2026-10-01').statusOn('2026-11-01'),
        'overdue',
      );
      expect(invoice('unpaid', '2026-11-01').statusOn('2026-11-01'), 'unpaid');
      expect(invoice('paid', '2026-10-01').statusOn('2026-11-01'), 'paid');
      expect(
        invoice('cancelled', '2026-10-01').statusOn('2026-11-01'),
        'cancelled',
      );
      expect(invoice('unpaid', null).statusOn('2026-11-01'), 'unpaid');
    },
  );
}
