import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:inventory/inventory.dart';

void main() {
  const items = {
    'pens': InventoryItem(
      id: 'pens',
      name: 'Pens',
      storeId: 's1',
      categoryId: 'c1',
      stockUnit: 'Box',
      tracking: Tracking.quantity,
      reorderLevel: 10,
      defaultPrice: 50,
      active: true,
    ),
    'chalk': InventoryItem(
      id: 'chalk',
      name: 'Chalk',
      storeId: 's1',
      categoryId: 'c1',
      stockUnit: 'Box',
      tracking: Tracking.batch,
      active: true,
    ),
    'other': InventoryItem(
      id: 'other',
      name: 'Hidden',
      storeId: 's2',
      categoryId: 'c1',
      stockUnit: 'Nos',
      tracking: Tracking.quantity,
      active: true,
    ),
  };
  ReportInput input(List<Map<String, dynamic>> documents) => ReportInput(
    documents: documents,
    items: items,
    categoryNames: const {'c1': 'Stationery'},
    storeNames: const {'s1': 'Main store'},
    today: '2026-11-25',
  );

  test('stock on hand sums batches per item, lists empty items, hides other stores', () {
    final table = buildReport(
      InventoryReport.stockOnHand,
      input([
        {
          'itemId': 'pens',
          'storeId': 's1',
          'quantityAvailable': 4,
          'value': 200,
        },
        {
          'itemId': 'pens',
          'storeId': 's1',
          'quantityAvailable': 2,
          'value': 100,
        },
        {
          'itemId': 'other',
          'storeId': 's2',
          'quantityAvailable': 9,
          'value': 9,
        },
      ]),
    );
    expect(table.rows.map((row) => row.first), ['Chalk', 'Pens']);
    final pens = table.rows.last;
    expect(pens[4], '6');
    expect(pens[8], '300.00');
    expect(pens.last, 'low_stock');
    expect(table.rows.first.last, 'out_of_stock');
    expect(
      buildReport(
        InventoryReport.stockOnHand,
        input([]),
        filter: 'low_stock',
      ).rows,
      isEmpty,
    );
  });

  test('reorder list suggests buying back to twice the reorder level', () {
    final table = buildReport(
      InventoryReport.reorder,
      input([
        {
          'itemId': 'pens',
          'storeId': 's1',
          'quantityAvailable': 4,
          'value': 200,
        },
      ]),
    );
    expect(table.rows.single[6], '16');
    expect(table.rows.single.last, '800.00');
  });

  test('expiry flags expired and soon-expiring batches, oldest first', () {
    Map<String, dynamic> batch(String day) => {
      'itemId': 'chalk',
      'storeId': 's1',
      'batchNumber': day,
      'expiryDate': dayTimestamp(day),
      'quantityAvailable': 1,
      'value': 5,
    };
    final documents = [
      batch('2027-06-01'),
      batch('2026-11-01'),
      batch('2026-12-10'),
    ];
    final table = buildReport(InventoryReport.expiry, input(documents));
    expect(table.rows.map((row) => row[5]), [
      'expired',
      'expiring_soon',
      'in_date',
    ]);
    expect(
      buildReport(
        InventoryReport.expiry,
        input(documents),
        filter: 'expired',
      ).rows,
      hasLength(1),
    );
  });

  Map<String, dynamic> move(
    String type,
    num quantity, {
    String bucket = 'available',
  }) => {
    'type': type,
    'itemId': 'pens',
    'storeId': 's1',
    'quantity': quantity,
    'bucket': bucket,
    'unitCost': 10,
    'transactionDate': dayTimestamp('2026-11-20'),
  };

  test('consumption nets returns off issues', () {
    final row = buildReport(
      InventoryReport.consumption,
      input([
        move('issue', -5),
        move('return', 1),
        move('return', 1, bucket: 'damaged'),
        move('receive', 50),
      ]),
    ).rows.single;
    expect(row.sublist(3), ['5', '2', '3', '30.00']);
  });

  test(
    'losses count the available side of bucket moves and net off restores',
    () {
      final row = buildReport(
        InventoryReport.losses,
        input([
          move('damage', -2),
          move('damage', 2, bucket: 'damaged'),
          move('writeoff', -1),
          move('restore', 1),
        ]),
      ).rows.single;
      expect(row.sublist(3), ['2', '0', '1', '0', '1', '20.00']);
    },
  );

  test(
    'purchase deliveries show what is still pending; closed requests have none',
    () {
      Map<String, dynamic> request(String status) => {
        'number': 'PR-$status',
        'storeId': 's1',
        'status': status,
        'requiredDate': dayTimestamp('2026-12-01'),
        'lineItems': [
          {'itemId': 'pens', 'quantity': 10, 'received': 6, 'damaged': 1},
        ],
      };
      final documents = [request('partially_received'), request('closed')];
      final table = buildReport(InventoryReport.purchases, input(documents));
      expect(table.rows.map((row) => row[9]), ['3', '0']);
      expect(table.rows.first[10], '300.00');
      expect(
        buildReport(
          InventoryReport.purchases,
          input(documents),
          filter: 'pending',
        ).rows,
        hasLength(1),
      );
    },
  );

  test('asset register leaves out unregistered assets', () {
    final table = buildReport(
      InventoryReport.assetRegister,
      input([
        {
          'name': 'Projector',
          'storeId': 's1',
          'itemId': 'x',
          'status': 'assigned',
          'assignedTo': {'type': 'staff', 'personErpId': 7},
          'price': 20000,
        },
        {
          'name': 'New',
          'storeId': 's1',
          'itemId': 'x',
          'status': 'unregistered',
        },
      ]),
    );
    expect(table.rows.single[7], 'Staff #7');
    expect(table.sumColumns, {10});
  });

  test('overview figures read the stats summary, branch or one store', () {
    final summary = {
      'items': 12,
      'available': 40.0,
      'value': 900.5,
      'lowStock': 3,
      'outOfStock': 1,
      'expiryOn': {'2026-11-01': 2, '2026-11-20': 4, '2027-05-01': 5},
      'openPurchaseRequests': 2,
      'pendingIssueRequests': 1,
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
    expect(branch['approvals'], 1);
    expect(branch['prs'], 2);
    final store = overviewFigures(summary, 's1', today: '2026-11-13');
    expect(store['available'], 15);
    expect(store['low'], 1);
    expect(store['expiring'], 1);
    expect(store['items'], 12);
    expect(overviewFigures(null, null, today: '2026-11-13')['items'], 0);
  });

  test(
    'storeOverviewSummaries extracts active store metrics with zero defaults',
    () {
      final stores = [
        const InventoryStore(
          id: 's1',
          name: 'Main Store',
          managerId: '101',
          active: true,
        ),
        const InventoryStore(
          id: 's2',
          name: 'Science Lab',
          managerId: '102',
          active: true,
        ),
        const InventoryStore(
          id: 's3',
          name: 'Old Store',
          managerId: '103',
          active: false,
        ),
      ];
      final summary = {
        'stores': {
          's1': {
            'available': 24.0,
            'value': 1250.5,
            'lowStock': 2,
            'outOfStock': 1,
          },
        },
      };

      final rows = storeOverviewSummaries(summary, stores);
      expect(rows.length, 2);
      expect(rows[0].store.id, 's1');
      expect(rows[0].available, 24.0);
      expect(rows[0].value, 1250.5);
      expect(rows[0].lowStock, 2);
      expect(rows[0].outOfStock, 1);
      expect(rows[1].store.id, 's2');
      expect(rows[1].available, 0);
      expect(rows[1].value, 0);
    },
  );
}
