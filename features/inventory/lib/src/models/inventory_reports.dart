// Inventory reports: what each one loads and how its rows are built (pure, so they are unit tested).

import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// The collection a report reads, and the calendar-day field its period filters (null: no period).
enum ReportSource {
  balances('inventoryBalances', null),
  movements('inventoryMovements', 'transactionDate'),
  issues('inventoryIssues', 'transactionDate');

  const ReportSource(this.collection, this.dateField);

  final String collection;
  final String? dateField;

  bool get hasDates => dateField != null;
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
  currentStock(
    'Current stock',
    'How much of each item is in each store right now, and which items are running low or have run out.',
    ReportSource.balances,
    ['in_stock', 'low_stock', 'out_of_stock'],
  ),
  expiringItems(
    'Expiring items',
    'Items in stock that have expired or will expire soon, earliest first.',
    ReportSource.balances,
    ['expired', 'within_30_days', 'within_90_days'],
  ),
  stockSummary(
    'Stock summary',
    'For each item in the period: stock at the start, what came in, what went out and stock at the end.',
    ReportSource.movements,
    [],
  ),
  itemsGivenOut(
    'Items given out',
    'Who was given which items, how many and when.',
    ReportSource.issues,
    [],
  ),
  stockInOut(
    'Stock in & out',
    'Every change to usable stock in the period, one line each, by date.',
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

  /// Choices of the report's filter (applied in the client).
  final List<String> filters;

  /// The filter's label on the report page.
  String get filterLabel => this == stockInOut ? 'Type' : 'Show';

  /// Filter choice labels where the plain wording is not clear enough.
  static const filterLabels = {
    'low_stock': 'Running low',
    'expired': 'Already expired',
    'within_30_days': 'Expiring in 30 days',
    'within_90_days': 'Expiring in 90 days',
    ..._movementLabels,
  };
}

/// What each kind of stock change is called in reports.
const _movementLabels = {
  'receive': 'Received',
  'issue': 'Given out',
  'return': 'Returned',
  'adjust': 'Stock correction',
  'damage': 'Marked damaged',
  'expire': 'Marked expired',
  'writeoff': 'Lost',
  'restore': 'Back in use',
};

/// Everything a report's rows are built from.
class ReportInput {
  const ReportInput({
    required this.documents,
    required this.items,
    required this.categoryNames,
    required this.storeNames,
    required this.today,
    this.balances = const [],
    this.periodEnd,
  });

  /// Raw documents of the report's [ReportSource] (with `id`).
  final List<Map<String, dynamic>> documents;
  final Map<String, InventoryItem> items;
  final Map<String, String> categoryNames;

  /// The stores the user may see; documents of other stores are left out.
  final Map<String, String> storeNames;

  /// `yyyy-MM-dd`, India time.
  final String today;

  /// Stock summary only: today's balances, and the last day of the period (`yyyy-MM-dd`); its
  /// [documents] are the movements from the start of the period up to today.
  final List<Map<String, dynamic>> balances;
  final String? periodEnd;
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
  List<Map<String, dynamic>> visible(List<Map<String, dynamic>> documents) => [
    for (final document in documents)
      if (input.storeNames.containsKey(document['storeId']) &&
          (storeId == null || document['storeId'] == storeId))
        document,
  ];
  final scoped = ReportInput(
    documents: visible(input.documents),
    items: input.items,
    categoryNames: input.categoryNames,
    storeNames: input.storeNames,
    today: input.today,
    balances: visible(input.balances),
    periodEnd: input.periodEnd,
  );
  return switch (report) {
    InventoryReport.currentStock => _currentStock(scoped, storeId, filter),
    InventoryReport.expiringItems => _expiringItems(scoped, filter),
    InventoryReport.stockSummary => _stockSummary(scoped, storeId),
    InventoryReport.itemsGivenOut => _itemsGivenOut(scoped),
    InventoryReport.stockInOut => _stockInOut(scoped, filter),
  };
}

/// Every active, non-asset item of a visible store (narrowed to [storeId]), keyed by item and store.
Iterable<(String, String)> _stockedItems(ReportInput input, String? storeId) =>
    [
      for (final item in input.items.values)
        if (item.active &&
            input.storeNames.containsKey(item.storeId) &&
            (storeId == null || item.storeId == storeId) &&
            item.tracking != Tracking.asset)
          (item.id, item.storeId),
    ];

(String, String) _key(Map<String, dynamic> document) =>
    (readString(document['itemId']), readString(document['storeId']));

String _itemName(ReportInput input, String itemId) =>
    input.items[itemId]?.name ?? 'Unknown item';

String _store(ReportInput input, Object? storeId) =>
    input.storeNames[storeId] ?? '';

String _unit(ReportInput input, String itemId) =>
    input.items[itemId]?.stockUnit ?? '';

List<List<String>> _byFirstColumn(List<List<String>> rows) =>
    rows..sort((left, right) => left.first.compareTo(right.first));

ReportTable _currentStock(ReportInput input, String? storeId, String? filter) {
  final stock = <(String, String), ({double quantity, double value})>{
    for (final key in _stockedItems(input, storeId))
      key: (quantity: 0, value: 0),
  };
  for (final document in input.documents) {
    final current = stock[_key(document)] ?? (quantity: 0.0, value: 0.0);
    stock[_key(document)] = (
      quantity: current.quantity + readDouble(document['quantityAvailable']),
      value: current.value + readDouble(document['value']),
    );
  }
  final rows = <List<String>>[];
  for (final MapEntry(key: (itemId, storeKey), value: line) in stock.entries) {
    final item = input.items[itemId];
    final minimum = item?.reorderLevel;
    final status = line.quantity <= 0
        ? 'out_of_stock'
        : minimum != null && line.quantity <= minimum
        ? 'low_stock'
        : 'in_stock';
    if (filter != null && status != filter) continue;
    rows.add([
      _itemName(input, itemId),
      input.categoryNames[item?.categoryId] ?? '',
      _store(input, storeKey),
      _quantity(line.quantity),
      item?.stockUnit ?? '',
      minimum == null ? '' : _quantity(minimum),
      _money(_round(line.value)),
      status,
    ]);
  }
  return ReportTable([
    _text('Item'),
    _text('Category'),
    _text('Store'),
    _count('In stock'),
    _text('Unit'),
    _count('Minimum stock'),
    _amount('Value (₹)', sum: true),
    _state('Status'),
  ], _byFirstColumn(rows));
}

/// "Expired 3 days ago", "Expires today", "In 12 days".
String _expiresText(int daysLeft) => switch (daysLeft) {
  < -1 => 'Expired ${-daysLeft} days ago',
  -1 => 'Expired yesterday',
  0 => 'Expires today',
  1 => 'Tomorrow',
  _ => 'In $daysLeft days',
};

ReportTable _expiringItems(ReportInput input, String? filter) {
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
        _expiresText(daysLeft),
        _quantity(available),
        _unit(input, itemId),
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
      _text('Expiry date'),
      _text('Expires'),
      _count('Quantity'),
      _text('Unit'),
      _amount('Value (₹)', sum: true),
    ],
    [for (final (_, row) in lines) row],
  );
}

/// Usable stock of one item in one store over the period.
class _Summary {
  double atEnd = 0;
  double received = 0;
  double givenOut = 0;
  double returned = 0;
  double damagedOrLost = 0;
  double corrected = 0;

  double get atStart =>
      atEnd - received + givenOut - returned + damagedOrLost - corrected;
}

/// Usable stock only: a damage or loss moves units out of usable stock (its other row, into the
/// damaged or expired stock, is left out), and putting them back in use brings them back.
ReportTable _stockSummary(ReportInput input, String? storeId) {
  final periodEnd = input.periodEnd ?? input.today;
  final summary = <(String, String), _Summary>{
    for (final key in _stockedItems(input, storeId)) key: _Summary(),
  };
  for (final balance in input.balances) {
    summary.putIfAbsent(_key(balance), _Summary.new).atEnd += readDouble(
      balance['quantityAvailable'],
    );
  }
  for (final movement in input.documents) {
    if (movement['bucket'] != 'available') continue;
    final line = summary.putIfAbsent(_key(movement), _Summary.new);
    final quantity = readDouble(movement['quantity']);
    // Balances are today's: take back what changed after the period to get its closing stock.
    if (readDay(movement['transactionDate']).compareTo(periodEnd) > 0) {
      line.atEnd -= quantity;
      continue;
    }
    switch (movement['type']) {
      case 'receive':
        line.received += quantity;
      case 'issue':
        line.givenOut -= quantity;
      case 'return':
        line.returned += quantity;
      case 'adjust':
        line.corrected += quantity;
      default:
        line.damagedOrLost -= quantity;
    }
  }
  final rows = [
    for (final MapEntry(key: (itemId, storeKey), value: line)
        in summary.entries)
      [
        _itemName(input, itemId),
        _store(input, storeKey),
        _unit(input, itemId),
        _quantity(line.atStart),
        _quantity(line.received),
        _quantity(line.givenOut),
        _quantity(line.returned),
        _quantity(line.damagedOrLost),
        _quantity(line.corrected),
        _quantity(line.atEnd),
      ],
  ];
  return ReportTable([
    _text('Item'),
    _text('Store'),
    _text('Unit'),
    _count('Opening stock'),
    _count('Received'),
    _count('Given out'),
    _count('Returned'),
    _count('Damaged / lost'),
    _count('Corrections (±)'),
    _count('Closing stock'),
  ], _byFirstColumn(rows));
}

/// One line per item given out; [ReportInput.documents] are issues carrying their request's
/// `requesterName` and `purpose`.
ReportTable _itemsGivenOut(ReportInput input) {
  final documents = [...input.documents]
    ..sort(
      (left, right) =>
          readDay(right['transactionDate'])
              .compareTo(readDay(left['transactionDate'])),
    );
  final rows = <List<String>>[];
  for (final issue in documents) {
    final lines = issue['lineItems'] is List
        ? issue['lineItems'] as List
        : const <Object?>[];
    for (final line in lines) {
      if (line is! Map) continue;
      final itemId = readString(line['itemId']);
      final quantity = readDouble(line['quantity']);
      rows.add([
        readDay(issue['transactionDate']).toDisplayDay(),
        readString(issue['requesterName']),
        readString(issue['purpose']),
        _itemName(input, itemId),
        _store(input, issue['storeId']),
        _quantity(quantity),
        _quantity(readDouble(line['quantityReturned'])),
        _unit(input, itemId),
        _money(_round(quantity * readDouble(line['unitCost']))),
        readString(issue['number']),
      ]);
    }
  }
  return ReportTable([
    _text('Date'),
    _text('Given to'),
    _text('Purpose'),
    _text('Item'),
    _text('Store'),
    _count('Quantity'),
    _count('Returned'),
    _text('Unit'),
    _amount('Value (₹)', sum: true),
    _text('Issue number'),
  ], rows);
}

ReportTable _stockInOut(ReportInput input, String? filter) {
  final documents =
      [
        for (final document in input.documents)
          if (document['bucket'] == 'available' &&
              (filter == null || document['type'] == filter))
            document,
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
    rows.add([
      readDay(document['transactionDate']).toDisplayDay(),
      _movementLabels[document['type']] ??
          humanizeStatus(readString(document['type'])),
      _itemName(input, itemId),
      _store(input, document['storeId']),
      readString(document['batchNumber']),
      quantity > 0 ? _quantity(quantity) : '',
      quantity < 0 ? _quantity(-quantity) : '',
      _unit(input, itemId),
      _money(_round(quantity.abs() * readDouble(document['unitCost']))),
    ]);
  }
  return ReportTable([
    _text('Date'),
    _text('What happened'),
    _text('Item'),
    _text('Store'),
    _text('Batch'),
    _count('In'),
    _count('Out'),
    _text('Unit'),
    _amount('Value (₹)'),
  ], rows);
}
