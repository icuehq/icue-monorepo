import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('InventoryItem parses a Firestore map', () {
    final item = InventoryItem.fromMap('i1', {
      'name': 'Blue Pen',
      'categoryId': 'c1',
      'stockUnit': 'pcs',
      'tracking': 'batch',
      'reorderLevel': 10,
      'defaultPrice': 2.5,
      'status': 'inactive',
    });
    expect(item.tracking, Tracking.batch);
    expect(item.reorderLevel, 10.0);
    expect(item.defaultPrice, 2.5);
    expect(item.active, isFalse);
  });
}
