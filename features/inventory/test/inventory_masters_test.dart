import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('InventoryItem parses a Firestore map', () {
    final item = InventoryItem.fromMap('i1', {
      'code': 'PEN-01',
      'name': 'Blue Pen',
      'categoryId': 'c1',
      'stockUnit': 'pcs',
      'tracking': 'batch',
      'purchaseUnits': [
        {'unit': 'box', 'factor': 10},
      ],
      'minLevel': 5,
      'status': 'inactive',
    });
    expect(item.tracking, Tracking.batch);
    expect(item.purchaseUnits.single.factor, 10.0);
    expect(item.minLevel, 5.0);
    expect(item.active, isFalse);
  });
}
