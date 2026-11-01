import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('quotation and PO lines parse qty / qtyOrdered; PO status helpers', () {
    final q = InvQuotation.fromMap('q', {
      'prId': 'pr',
      'selected': true,
      'total': 590,
      'lines': [
        {'itemId': 'i', 'qty': 100, 'unitPrice': 4},
      ],
    });
    expect(q.lines.single.qty, 100);
    expect(q.selected, isTrue);

    final po = InvPurchaseOrder.fromMap('p', {
      'status': 'acknowledged',
      'prIds': ['pr'],
      'lines': [
        {'itemId': 'i', 'qtyOrdered': 60, 'qtyReceived': 10, 'unitPrice': 5},
      ],
    });
    expect(po.prId, 'pr');
    expect(po.lines.single.qty, 60);
    expect(po.lines.single.qtyReceived, 10);
    expect([po.canRevise, po.canCancel, po.canClose], everyElement(isTrue));
    expect(
      InvPurchaseOrder.fromMap('p', {'status': 'closed'}).canCancel,
      isFalse,
    );
  });
}
