import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('asset parses custody, warranty and maintenance flags', () {
    final asset = InventoryAsset.fromMap('a', {
      'status': 'assigned',
      'warranty': {
        'start': dayTimestamp('2026-01-01'),
        'end': dayTimestamp('2027-01-01'),
      },
      'assignedTo': {'type': 'department', 'personErpId': 3},
      'activeMaintenanceId': 'm',
      'price': 450,
    });
    expect(asset.assignedTo!.label, 'department #3');
    expect(asset.warrantyEnd, '2027-01-01');
    expect(asset.price, 450);
    expect(asset.inMaintenance, isTrue);
    expect(asset.isRetired, isFalse);
    expect(
      InventoryAsset.fromMap('a', {'status': 'disposed'}).isRetired,
      isTrue,
    );
  });

  test('assignment and maintenance parse; only open jobs are live', () {
    final assignment = InventoryAssignment.fromMap('g', {
      'assignee': {'type': 'staff', 'personErpId': 7},
      'closedAs': 'transferred',
      'acknowledgement': {'at': 1},
    });
    expect(assignment.closedAs, 'transferred');
    expect(assignment.acknowledged, isTrue);
    final maintenance = InventoryMaintenance.fromMap('m', {
      'status': 'in_progress',
      'cost': 0,
      'partsUsed': [
        {'itemId': 'i', 'quantity': 2},
      ],
    });
    expect(maintenance.isLive, isTrue);
    expect(maintenance.cost, 0);
    expect(maintenance.parts.single.quantity, 2);
    expect(
      InventoryMaintenance.fromMap('m', {'status': 'completed'}).isLive,
      isFalse,
    );
  });
}
