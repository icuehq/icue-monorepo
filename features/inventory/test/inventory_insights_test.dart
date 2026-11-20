import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

void main() {
  test('every report has a unique key and columns', () {
    expect(
      inventoryReports.map((reportDef) => reportDef.key).toSet().length,
      inventoryReports.length,
    );
    expect(inventoryReports.length, 15);
    expect(
      inventoryReports.every((reportDef) => reportDef.cols.isNotEmpty),
      isTrue,
    );
  });

  test('overview figures read the stats summary, branch or one store', () {
    final summary = {
      'items': 12,
      'available': 40.0,
      'value': 900.5,
      'lowStock': 3,
      'outOfStock': 1,
      'expiryOn': {'2026-11-01': 2, '2026-11-20': 4, '2027-05-01': 5},
      'pendingPurchaseRequests': 2,
      'pendingIssueRequests': 1,
      'openPurchaseOrders': 6,
      'awaitingReceipt': 2,
      'assets': 9,
      'underMaintenance': 1,
      'stores': {
        's1': {
          'available': 15.0,
          'lowStock': 1,
          'expiryOn': {'2026-11-20': 1},
        },
      },
    };
    final branch = overviewFigures(summary, null, today: '2026-11-13');
    expect(branch['expired'], 2);
    expect(branch['expiring'], 4);
    expect(branch['approvals'], 3);
    expect(branch['pos'], 6);
    final store = overviewFigures(summary, 's1', today: '2026-11-13');
    expect(store['available'], 15);
    expect(store['low'], 1);
    expect(store['expiring'], 1);
    expect(store['items'], 12);
    expect(overviewFigures(null, null, today: '2026-11-13')['items'], 0);
  });
}
