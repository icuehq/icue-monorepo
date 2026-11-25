// Inventory reports: what each one loads and how its rows are built (pure, so they are unit tested).

import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// The collection a report reads, and the field its date range filters (null: no date range).
enum ReportSource {
  balances('inventoryBalances', null),
  movements('inventoryMovements', 'transactionDate'),
  purchaseRequests('inventoryPurchaseRequests', 'createdAt'),
  assets('inventoryAssets', null),
  maintenance('inventoryMaintenanceJobs', 'reportedDate');

  const ReportSource(this.collection, this.dateField);

  final String collection;
  final String? dateField;

  bool get hasDates => dateField != null;

  /// The date field holds a calendar day (midnight India time) rather than an instant.
  bool get isDay => dateField != 'createdAt';
}

/// How a report cell is shown: quantities and money are numbers (right-aligned, sorted as numbers),
/// a status is a raw status value shown as a chip.
enum ReportCell { text, quantity, money, status }

/// One column: its header, how its cells are shown and whether they are added up under the table.
typedef ReportColumnSpec = ({String label, ReportCell kind, bool sum});

ReportColumnSpec _text(String label) =>
    (label: label, kind: ReportCell.text, sum: false);
ReportColumnSpec _count(String label) =>
    (label: label, kind: ReportCell.quantity, sum: false);
ReportColumnSpec _amount(String label, {bool sum = false}) =>
    (label: label, kind: ReportCell.money, sum: sum);
ReportColumnSpec _state(String label) =>
    (label: label, kind: ReportCell.status, sum: false);

/// The reports on the Reports page, in display order.
enum InventoryReport {
  stockOnHand(
    'Stock on hand',
    'Every item in each store: quantity available, damaged and expired, its value and stock status.',
    ReportSource.balances,
    ['in_stock', 'low_stock', 'out_of_stock'],
  ),
  reorder(
    'Reorder list',
    'Items at or below their reorder level, how many to buy and the estimated cost.',
    ReportSource.balances,
    [],
  ),
  expiry(
    'Expiry',
    'Batches in stock by expiry date, with the quantity and value at risk.',
    ReportSource.balances,
    ['expired', 'within_30_days', 'within_90_days'],
  ),
  consumption(
    'Consumption by item',
    'What each store issued, got back and used up in the period, and its value.',
    ReportSource.movements,
    [],
  ),
  ledger(
    'Stock ledger',
    'Every stock movement in the period: receipts, issues, returns, adjustments and write-offs.',
    ReportSource.movements,
    [
      'receive',
      'issue',
      'return',
      'adjust',
      'damage',
      'expire',
      'writeoff',
      'restore',
    ],
  ),
  losses(
    'Losses and write-offs',
    'Stock lost, damaged, expired or adjusted per item in the period, and the value written off.',
    ReportSource.movements,
    [],
  ),
  purchases(
    'Purchase deliveries',
    'Each purchase request line: ordered, received, damaged and still pending.',
    ReportSource.purchaseRequests,
    ['pending', 'complete'],
  ),
  assetRegister(
    'Asset register',
    'Registered assets with their store, status, condition, holder, price and warranty.',
    ReportSource.assets,
    [
      'available',
      'assigned',
      'under_maintenance',
      'under_repair',
      'damaged',
      'lost',
      'retired',
      'disposed',
    ],
  ),
  maintenanceCost(
    'Maintenance',
    'Maintenance jobs reported in the period, how long they took and what they cost.',
    ReportSource.maintenance,
    [
      'open',
      'assigned',
      'in_progress',
      'waiting_for_parts',
      'completed',
      'cancelled',
    ],
  );

  const InventoryReport(
    this.title,
    this.description,
    this.source,
    this.filters,
  );

  final String title;
  final String description;
  final ReportSource source;

  /// Choices of the report's filter chips (applied in the client).
  final List<String> filters;

  /// Filter chip labels where the plain wording is not clear enough.
  static const filterLabels = {
    'within_30_days': 'Within 30 days',
    'within_90_days': 'Within 90 days',
    'receive': 'Received',
    'issue': 'Issued',
    'return': 'Returned',
    'adjust': 'Adjusted',
    'damage': 'Damaged',
    'expire': 'Expired',
    'writeoff': 'Lost',
    'restore': 'Restored',
    'pending': 'Pending delivery',
    'complete': 'Fully received',
  };
}

/// Everything a report's rows are built from.
class ReportInput {
  const ReportInput({
    required this.documents,
    required this.items,
    required this.categoryNames,
    required this.storeNames,
    required this.today,
  });

  /// Raw documents of the report's [ReportSource] (with `id`).
  final List<Map<String, dynamic>> documents;
  final Map<String, InventoryItem> items;
  final Map<String, String> categoryNames;

  /// The stores the user may see; documents of other stores are left out.
  final Map<String, String> storeNames;

  /// `yyyy-MM-dd`, India time.
  final String today;
}

class ReportTable {
  const ReportTable(this.columns, this.rows);

  final List<ReportColumnSpec> columns;
  final List<List<String>> rows;

  List<String> get header => [for (final column in columns) column.label];

  Set<int> get sumColumns => {
    for (var index = 0; index < columns.length; index++)
      if (columns[index].sum) index,
  };
}

String _quantity(num value) => value.toDouble().toQuantityText();
String _money(num value) => value.toDouble().toAmountText();
double _round(double value) => (value * 100).round() / 100;

/// Builds [report] from [input], narrowed to [storeId] and the report [filter] when given.
ReportTable buildReport(
  InventoryReport report,
  ReportInput input, {
  String? storeId,
  String? filter,
}) {
  final documents = [
    for (final document in input.documents)
      if (report.source == ReportSource.maintenance ||
          (input.storeNames.containsKey(document['storeId']) &&
              (storeId == null || document['storeId'] == storeId)))
        document,
  ];
  final scoped = ReportInput(
    documents: documents,
    items: input.items,
    categoryNames: input.categoryNames,
    storeNames: input.storeNames,
    today: input.today,
  );
  return switch (report) {
    InventoryReport.stockOnHand => _stockOnHand(scoped, storeId, filter),
    InventoryReport.reorder => _reorder(scoped, storeId),
    InventoryReport.expiry => _expiry(scoped, filter),
    InventoryReport.consumption => _consumption(scoped),
    InventoryReport.ledger => _ledger(scoped, filter),
    InventoryReport.losses => _losses(scoped),
    InventoryReport.purchases => _purchases(scoped, filter),
    InventoryReport.assetRegister => _assets(scoped, filter),
    InventoryReport.maintenanceCost => _maintenance(scoped, filter),
  };
}

/// Stock of one item in one store, summed over its batches and variants.
class _ItemStock {
  double available = 0;
  double damaged = 0;
  double expired = 0;
  double value = 0;
}

/// Per item and store: summed balances, plus every active item of a visible store without any (nothing in stock).
Map<(String, String), _ItemStock> _stockByItem(
  ReportInput input,
  String? storeId,
) {
  final stock = <(String, String), _ItemStock>{};
  for (final item in input.items.values) {
    if (item.active &&
        input.storeNames.containsKey(item.storeId) &&
        (storeId == null || item.storeId == storeId) &&
        item.tracking != Tracking.asset) {
      stock[(item.id, item.storeId)] = _ItemStock();
    }
  }
  for (final document in input.documents) {
    final line = stock.putIfAbsent((
      readString(document['itemId']),
      readString(document['storeId']),
    ), _ItemStock.new);
    line.available += readDouble(document['quantityAvailable']);
    line.damaged += readDouble(document['quantityDamaged']);
    line.expired += readDouble(document['quantityExpired']);
    line.value += readDouble(document['value']);
  }
  return stock;
}

String _itemName(ReportInput input, String itemId) =>
    input.items[itemId]?.name ?? 'Unknown item';

String _store(ReportInput input, Object? storeId) =>
    input.storeNames[storeId] ?? '';

String _stockStatus(double available, double? reorderLevel) => available <= 0
    ? 'out_of_stock'
    : reorderLevel != null && available <= reorderLevel
    ? 'low_stock'
    : 'in_stock';

ReportTable _stockOnHand(ReportInput input, String? storeId, String? filter) {
  final rows = <List<String>>[];
  for (final MapEntry(key: (itemId, storeKey), value: stock) in _stockByItem(
    input,
    storeId,
  ).entries) {
    final item = input.items[itemId];
    final status = _stockStatus(stock.available, item?.reorderLevel);
    if (filter != null && status != filter) continue;
    rows.add([
      _itemName(input, itemId),
      input.categoryNames[item?.categoryId] ?? '',
      _store(input, storeKey),
      item?.stockUnit ?? '',
      _quantity(stock.available),
      _quantity(stock.damaged),
      _quantity(stock.expired),
      item?.reorderLevel == null ? '' : _quantity(item!.reorderLevel!),
      _money(stock.value),
      status,
    ]);
  }
  rows.sort((left, right) => left.first.compareTo(right.first));
  return ReportTable([
    _text('Item'),
    _text('Category'),
    _text('Store'),
    _text('Unit'),
    _count('Available'),
    _count('Damaged'),
    _count('Expired'),
    _count('Reorder level'),
    _amount('Value (₹)', sum: true),
    _state('Status'),
  ], rows);
}

ReportTable _reorder(ReportInput input, String? storeId) {
  final rows = <List<String>>[];
  for (final MapEntry(key: (itemId, storeKey), value: stock) in _stockByItem(
    input,
    storeId,
  ).entries) {
    final item = input.items[itemId];
    final reorderLevel = item?.reorderLevel;
    if (item == null ||
        reorderLevel == null ||
        stock.available > reorderLevel) {
      continue;
    }
    // ponytail: buys back up to twice the reorder level; add a per-item "maximum stock" when schools ask.
    final toBuy = reorderLevel * 2 - stock.available;
    final unitCost =
        item.defaultPrice ??
        (stock.available > 0 ? stock.value / stock.available : 0);
    rows.add([
      item.name,
      input.categoryNames[item.categoryId] ?? '',
      _store(input, storeKey),
      item.stockUnit,
      _quantity(stock.available),
      _quantity(reorderLevel),
      _quantity(toBuy),
      _money(unitCost),
      _money(_round(toBuy * unitCost)),
    ]);
  }
  rows.sort((left, right) => left.first.compareTo(right.first));
  return ReportTable([
    _text('Item'),
    _text('Category'),
    _text('Store'),
    _text('Unit'),
    _count('Available'),
    _count('Reorder level'),
    _count('Suggested order'),
    _amount('Unit cost (₹)'),
    _amount('Estimated cost (₹)', sum: true),
  ], rows);
}

ReportTable _expiry(ReportInput input, String? filter) {
  final lines = <(String, List<String>)>[];
  for (final document in input.documents) {
    final expiry = readDayOrNull(document['expiryDate']);
    final available = readDouble(document['quantityAvailable']);
    if (expiry == null || available <= 0) continue;
    final daysLeft = daysBetween(input.today, expiry);
    final keep = switch (filter) {
      'expired' => daysLeft < 0,
      'within_30_days' => daysLeft >= 0 && daysLeft <= 30,
      'within_90_days' => daysLeft >= 0 && daysLeft <= 90,
      _ => true,
    };
    if (!keep) continue;
    final itemId = readString(document['itemId']);
    lines.add((
      expiry,
      [
        _itemName(input, itemId),
        _store(input, document['storeId']),
        readString(document['batchNumber']),
        expiry.toDisplayDay(),
        '$daysLeft',
        daysLeft < 0
            ? 'expired'
            : daysLeft <= 30
            ? 'expiring_soon'
            : 'in_date',
        _quantity(available),
        input.items[itemId]?.stockUnit ?? '',
        _money(readDouble(document['value'])),
      ],
    ));
  }
  lines.sort((left, right) => left.$1.compareTo(right.$1));
  return ReportTable(
    [
      _text('Item'),
      _text('Store'),
      _text('Batch'),
      _text('Expires on'),
      _count('Days left'),
      _state('Status'),
      _count('Available'),
      _text('Unit'),
      _amount('Value (₹)', sum: true),
    ],
    [for (final (_, row) in lines) row],
  );
}

/// Movement quantities summed per item and store for the [types] given, keyed by type.
Map<(String, String), Map<String, ({double quantity, double value})>>
_movementTotals(ReportInput input, Set<String> types) {
  final totals =
      <(String, String), Map<String, ({double quantity, double value})>>{};
  for (final document in input.documents) {
    final type = readString(document['type']);
    // A bucket move (damaged/expired) mirrors the available-stock row: count the available side only.
    if (!types.contains(type) ||
        (type != 'return' &&
            type != 'receive' &&
            document['bucket'] != 'available')) {
      continue;
    }
    final quantity = readDouble(document['quantity']);
    final key = (
      readString(document['itemId']),
      readString(document['storeId']),
    );
    final byType = totals.putIfAbsent(key, () => {});
    final current = byType[type] ?? (quantity: 0.0, value: 0.0);
    byType[type] = (
      quantity: current.quantity + quantity,
      value: current.value + quantity * readDouble(document['unitCost']),
    );
  }
  return totals;
}

ReportTable _consumption(ReportInput input) {
  final rows = <List<String>>[];
  for (final MapEntry(key: (itemId, storeId), value: byType) in _movementTotals(
    input,
    const {'issue', 'return'},
  ).entries) {
    final issued = -(byType['issue']?.quantity ?? 0);
    final returned = byType['return']?.quantity ?? 0;
    final value =
        -(byType['issue']?.value ?? 0) - (byType['return']?.value ?? 0);
    rows.add([
      _itemName(input, itemId),
      _store(input, storeId),
      input.items[itemId]?.stockUnit ?? '',
      _quantity(issued),
      _quantity(returned),
      _quantity(issued - returned),
      _money(_round(value)),
    ]);
  }
  rows.sort((left, right) => left.first.compareTo(right.first));
  return ReportTable([
    _text('Item'),
    _text('Store'),
    _text('Unit'),
    _count('Issued'),
    _count('Returned'),
    _count('Used'),
    _amount('Value used (₹)', sum: true),
  ], rows);
}

const _movementLabels = {
  'receive': 'Received',
  'issue': 'Issued',
  'return': 'Returned',
  'adjust': 'Adjusted',
  'damage': 'Marked damaged',
  'expire': 'Marked expired',
  'writeoff': 'Lost',
  'restore': 'Restored',
};

ReportTable _ledger(ReportInput input, String? filter) {
  final documents =
      [
        for (final document in input.documents)
          if (filter == null || document['type'] == filter) document,
      ]..sort((left, right) {
        final byDay = readDay(left['transactionDate'])
            .compareTo(readDay(right['transactionDate']));
        if (byDay != 0) return byDay;
        final leftAt = left['createdAt'] as Timestamp?;
        final rightAt = right['createdAt'] as Timestamp?;
        final byTime = leftAt == null || rightAt == null
            ? 0
            : leftAt.compareTo(rightAt);
        return byTime != 0
            ? byTime
            : readNumber(left['seq']).compareTo(readNumber(right['seq']));
      });
  final rows = <List<String>>[];
  for (final document in documents) {
    final quantity = readDouble(document['quantity']);
    final itemId = readString(document['itemId']);
    final bucket = readString(document['bucket']);
    rows.add([
      readDay(document['transactionDate']).toDisplayDay(),
      _itemName(input, itemId),
      _store(input, document['storeId']),
      readString(document['batchNumber']),
      _movementLabels[document['type']] ??
          humanizeStatus(readString(document['type'])),
      bucket == 'available' ? 'Usable' : humanizeStatus(bucket),
      quantity > 0 ? _quantity(quantity) : '',
      quantity < 0 ? _quantity(-quantity) : '',
      input.items[itemId]?.stockUnit ?? '',
      _money(_round(quantity.abs() * readDouble(document['unitCost']))),
    ]);
  }
  return ReportTable([
    _text('Date'),
    _text('Item'),
    _text('Store'),
    _text('Batch'),
    _text('Movement'),
    _text('Stock'),
    _count('In'),
    _count('Out'),
    _text('Unit'),
    _amount('Value (₹)'),
  ], rows);
}

ReportTable _losses(ReportInput input) {
  const types = {'damage', 'expire', 'writeoff', 'adjust', 'restore'};
  final rows = <List<String>>[];
  for (final MapEntry(key: (itemId, storeId), value: byType) in _movementTotals(
    input,
    types,
  ).entries) {
    double out(String type) => -(byType[type]?.quantity ?? 0);
    double lostValue(String type) => -(byType[type]?.value ?? 0);
    final adjusted = byType['adjust']?.quantity ?? 0;
    final restored = byType['restore']?.quantity ?? 0;
    final value = types.fold<double>(
      0,
      (total, type) => total + lostValue(type),
    );
    rows.add([
      _itemName(input, itemId),
      _store(input, storeId),
      input.items[itemId]?.stockUnit ?? '',
      _quantity(out('damage')),
      _quantity(out('expire')),
      _quantity(out('writeoff')),
      _quantity(adjusted),
      _quantity(restored),
      _money(_round(value)),
    ]);
  }
  rows.sort((left, right) => left.first.compareTo(right.first));
  return ReportTable([
    _text('Item'),
    _text('Store'),
    _text('Unit'),
    _count('Damaged'),
    _count('Expired'),
    _count('Lost'),
    _count('Adjusted (±)'),
    _count('Restored'),
    _amount('Net loss (₹)', sum: true),
  ], rows);
}

ReportTable _purchases(ReportInput input, String? filter) {
  final rows = <List<String>>[];
  final documents = [...input.documents]
    ..sort(
      (left, right) =>
          readString(right['number']).compareTo(readString(left['number'])),
    );
  for (final document in documents) {
    final status = readString(document['status']);
    for (final line
        in document['lineItems'] is List
            ? document['lineItems'] as List
            : const []) {
      if (line is! Map) continue;
      final ordered = readDouble(line['quantity']);
      final received = readDouble(line['received']);
      final damaged = readDouble(line['damaged']);
      final pending = status == 'closed'
          ? 0.0
          : (ordered - received - damaged).clamp(0, ordered).toDouble();
      if (filter == 'pending' && pending <= 0) continue;
      if (filter == 'complete' && pending > 0) continue;
      final itemId = readString(line['itemId']);
      final unitPrice = input.items[itemId]?.defaultPrice ?? 0;
      rows.add([
        readString(document['number']),
        document['createdAt'] is Timestamp
            ? (document['createdAt'] as Timestamp)
                  .toDate()
                  .toIndianTime()
                  .toNumericDate()
            : '',
        readDay(document['requiredDate']).toDisplayDay(),
        _store(input, document['storeId']),
        _itemName(input, itemId),
        input.items[itemId]?.stockUnit ?? '',
        _quantity(ordered),
        _quantity(received),
        _quantity(damaged),
        _quantity(pending),
        _money(_round(received * unitPrice)),
        status,
      ]);
    }
  }
  return ReportTable([
    _text('Request'),
    _text('Raised on'),
    _text('Needed by'),
    _text('Store'),
    _text('Item'),
    _text('Unit'),
    _count('Ordered'),
    _count('Received'),
    _count('Damaged'),
    _count('Pending'),
    _amount('Received value (₹)', sum: true),
    _state('Status'),
  ], rows);
}

String _custodian(Object? value) => value is Map
    ? '${humanizeStatus(readString(value['type']))} #${readString(value['personErpId'])}'
    : '';

ReportTable _assets(ReportInput input, String? filter) {
  final rows = <List<String>>[];
  for (final document in input.documents) {
    final status = readString(document['status']);
    if (status == 'unregistered' || (filter != null && status != filter)) {
      continue;
    }
    final warrantyEnd = readDayOrNull((document['warranty'] as Map?)?['end']);
    rows.add([
      readString(document['name']),
      readString(document['rfidTag']),
      readString(document['serialNumber']),
      _itemName(input, readString(document['itemId'])),
      _store(input, document['storeId']),
      status,
      humanizeStatus(readString(document['condition'])),
      _custodian(document['assignedTo']),
      readDay(document['purchaseDate']).toDisplayDay(),
      warrantyEnd == null
          ? ''
          : warrantyEnd.compareTo(input.today) < 0
          ? 'Expired ${warrantyEnd.toDisplayDay()}'
          : warrantyEnd.toDisplayDay(),
      _money(readDouble(document['price'])),
    ]);
  }
  rows.sort((left, right) => left.first.compareTo(right.first));
  return ReportTable([
    _text('Asset'),
    _text('Tag'),
    _text('Serial number'),
    _text('Item'),
    _text('Store'),
    _state('Status'),
    _text('Condition'),
    _text('Held by'),
    _text('Purchased on'),
    _text('Warranty until'),
    _amount('Price (₹)', sum: true),
  ], rows);
}

ReportTable _maintenance(ReportInput input, String? filter) {
  final documents =
      [
        for (final document in input.documents)
          if (filter == null || document['status'] == filter) document,
      ]..sort(
        (left, right) =>
            readDay(right['reportedDate'])
                .compareTo(readDay(left['reportedDate'])),
      );
  final rows = <List<String>>[];
  for (final document in documents) {
    final reported = readDay(document['reportedDate']);
    final completed = readDayOrNull(document['completedDate']);
    final days = daysBetween(reported, completed ?? input.today);
    rows.add([
      readString(document['number']),
      readString(document['assetName']),
      readString(document['issue']),
      readString(document['priority']),
      reported.toDisplayDay(),
      completed?.toDisplayDay() ?? '',
      '$days',
      readString(document['technician']),
      readString(document['status']),
      _money(readDouble(document['cost'])),
    ]);
  }
  return ReportTable([
    _text('Job'),
    _text('Asset'),
    _text('Problem'),
    _state('Priority'),
    _text('Reported'),
    _text('Completed'),
    _count('Days'),
    _text('Technician'),
    _state('Status'),
    _amount('Cost (₹)', sum: true),
  ], rows);
}
