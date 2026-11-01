import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('PO line due and receive eligibility', () {
    final po = InvPurchaseOrder.fromMap('p', {
      'status': 'partially_received',
      'lines': [
        {
          'itemId': 'i',
          'qtyOrdered': 100,
          'qtyAccepted': 40,
          'qtyRejected': 10,
          'unitPrice': 5,
        },
      ],
    });
    expect(po.lines.single.due, 50);
    expect(po.canReceive, isTrue);
    expect(
      InvPurchaseOrder.fromMap('p', {'status': 'draft'}).canReceive,
      isFalse,
    );
  });

  test(
    'GRN parses inspection result; invoice turns overdue after its due date',
    () {
      final g = InvGrn.fromMap('g', {
        'number': 'GRN/2026-27/000001',
        'inspection': {'result': 'partial'},
        'lines': [
          {'itemId': 'i', 'qtyAccepted': 4, 'qtyRejected': 1},
        ],
      });
      expect(g.result, 'partial');
      expect(g.lines.single.rejected, 1);

      InvInvoice inv(String status, String? due) => InvInvoice.fromMap('i', {
        'paymentStatus': status,
        'dueDate': due,
        'total': 100,
      });
      expect(inv('unpaid', '2026-10-01').statusOn('2026-11-01'), 'overdue');
      expect(
        inv('partially_paid', '2026-10-01').statusOn('2026-11-01'),
        'overdue',
      );
      expect(inv('unpaid', '2026-11-01').statusOn('2026-11-01'), 'unpaid');
      expect(inv('paid', '2026-10-01').statusOn('2026-11-01'), 'paid');
      expect(
        inv('cancelled', '2026-10-01').statusOn('2026-11-01'),
        'cancelled',
      );
      expect(inv('unpaid', null).statusOn('2026-11-01'), 'unpaid');
    },
  );
}
