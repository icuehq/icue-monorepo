import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/services/purchase_request_writes.dart';

void main() {
  InventoryPurchaseRequest request(String status) =>
      InventoryPurchaseRequest.fromMap('p', {
        'status': status,
        'storeId': 's1',
        'lineItems': [
          {'itemId': 'i', 'quantity': 4, 'received': 1, 'damaged': 1},
        ],
        'history': [
          {'action': 'create', 'comment': null},
        ],
      });

  test('edits only until goods arrive; receives and closes while open', () {
    expect(request('open').isEditable, isTrue);
    expect(request('partially_received').isEditable, isFalse);
    expect(request('partially_received').isOpen, isTrue);
    expect(request('received').isOpen, isFalse);
    expect(request('closed').isOpen, isFalse);
  });

  test('parses lines with what arrived', () {
    final line = request('open').lineItems.single;
    expect(line.quantity, 4);
    expect(line.pending, 2);
    expect(request('open').storeId, 's1');
  });

  test('status follows good + damaged against the requested quantity', () {
    Map<String, dynamic> line(num received, num damaged) => {
      'quantity': 5,
      'received': received,
      'damaged': damaged,
    };
    expect(purchaseRequestStatus([line(0, 0), line(0, 0)]), 'open');
    expect(
      purchaseRequestStatus([line(5, 0), line(0, 0)]),
      'partially_received',
    );
    expect(purchaseRequestStatus([line(4, 1), line(5, 0)]), 'received');
  });
}
