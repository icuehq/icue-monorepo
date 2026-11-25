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

  test('current stock sums batches per item, lists empty items, hides other stores', () {
    final table = buildReport(
      InventoryReport.currentStock,
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
    expect(pens[3], '6');
    expect(pens[6], '300.00');
    expect(pens.last, 'low_stock');
    expect(table.rows.first.last, 'out_of_stock');
    expect(
      buildReport(
        InventoryReport.currentStock,
        input([]),
        filter: 'low_stock',
      ).rows,
      isEmpty,
    );
  });

  test('expiring items read in plain words, earliest first', () {
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
    final table = buildReport(InventoryReport.expiringItems, input(documents));
    expect(table.rows.map((row) => row[4]), [
      'Expired 24 days ago',
      'In 15 days',
      'In 188 days',
    ]);
    expect(
      buildReport(
        InventoryReport.expiringItems,
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
    String day = '2026-11-20',
  }) => {
    'type': type,
    'itemId': 'pens',
    'storeId': 's1',
    'quantity': quantity,
    'bucket': bucket,
    'unitCost': 10,
    'transactionDate': dayTimestamp(day),
  };

  test('stock summary works out opening and closing usable stock', () {
    final table = buildReport(
      InventoryReport.stockSummary,
      ReportInput(
        documents: [
          move('receive', 50),
          move('receive', 3, bucket: 'damaged'),
          move('issue', -5),
          move('return', 1),
          move('damage', -2),
          move('damage', 2, bucket: 'damaged'),
          move('restore', 1),
          move('adjust', -1),
          // After the period: not in it, but taken back off today's stock.
          move('issue', -4, day: '2026-11-24'),
        ],
        balances: [
          {'itemId': 'pens', 'storeId': 's1', 'quantityAvailable': 60},
        ],
        periodEnd: '2026-11-21',
        items: items,
        categoryNames: const {'c1': 'Stationery'},
        storeNames: const {'s1': 'Main store'},
        today: '2026-11-25',
      ),
    );
    final pens = table.rows.firstWhere((row) => row.first == 'Pens');
    // Opening 20 + 50 received - 5 given out + 1 returned - 1 damaged - 1 corrected = 64 closing.
    expect(pens.sublist(3), ['20', '50', '5', '1', '1', '-1', '64']);
  });

  test('items given out list each line with who it went to', () {
    final table = buildReport(
      InventoryReport.itemsGivenOut,
      input([
        {
          'number': 'ISS/1',
          'storeId': 's1',
          'transactionDate': dayTimestamp('2026-11-20'),
          'requesterName': 'Asha',
          'purpose': 'Class 5 exams',
          'lineItems': [
            {
              'itemId': 'pens',
              'quantity': 3,
              'quantityReturned': 1,
              'unitCost': 10,
            },
          ],
        },
      ]),
    );
    expect(table.rows.single.sublist(1, 7), [
      'Asha',
      'Class 5 exams',
      'Pens',
      'Main store',
      '3',
      '1',
    ]);
    expect(table.rows.single[8], '30.00');
  });

  test('stock in & out shows one line per change of usable stock', () {
    final table = buildReport(
      InventoryReport.stockInOut,
      input([
        move('damage', -2),
        move('damage', 2, bucket: 'damaged'),
        move('receive', 5),
      ]),
    );
    expect(table.rows.map((row) => row[1]), ['Marked damaged', 'Received']);
    expect(table.rows.first.sublist(5, 7), ['', '2']);
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
