import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('asset parses custody, warranty and maintenance flags', () {
    final a = InvAsset.fromMap('a', {
      'assetId': 'AST/2026-27/000001',
      'status': 'assigned',
      'campusId': 31,
      'warranty': {'start': '2026-01-01', 'end': '2027-01-01'},
      'assignedTo': {'type': 'department', 'erpId': 3},
      'activeMaintenanceId': 'm',
      'price': 450,
    });
    expect(a.assignedTo!.label, 'department #3');
    expect(a.warrantyEnd, '2027-01-01');
    expect(a.price, 450);
    expect(a.inMaintenance, isTrue);
    expect(a.isRetired, isFalse);
    expect(InvAsset.fromMap('a', {'status': 'disposed'}).isRetired, isTrue);
  });

  test('assignment and maintenance parse; only open jobs are live', () {
    final g = InvAssignment.fromMap('g', {
      'assignee': {'type': 'staff', 'erpId': 7},
      'closedAs': 'transferred',
      'ack': {'at': 1},
    });
    expect(g.closedAs, 'transferred');
    expect(g.acknowledged, isTrue);
    final m = InvMaintenance.fromMap('m', {
      'status': 'in_progress',
      'cost': 0,
      'partsUsed': [
        {'itemId': 'i', 'qty': 2},
      ],
    });
    expect(m.isLive, isTrue);
    expect(m.cost, 0);
    expect(m.parts.single.qty, 2);
    expect(
      InvMaintenance.fromMap('m', {'status': 'completed'}).isLive,
      isFalse,
    );
  });
}
