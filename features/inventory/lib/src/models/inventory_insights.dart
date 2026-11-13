// Dashboard and reports (Inv-7). Parse and display only; rules live in Cloud Functions.

import 'package:icue_firebase/icue_firebase.dart'
    show ReportColumn, readDay, readNumber, readString;
import 'package:icue_ui/icue_ui.dart';

/// Resolves IDs to display names for report cells.
class ReportNames {
  const ReportNames({required this.item, required this.store});

  final String Function(Object? id) item;
  final String Function(Object? id) store;
}

String _money(Object? value) =>
    value == null ? '' : readNumber(value).toAmountText();

typedef ReportCol = ReportColumn<ReportNames>;

/// A report is one collection query plus columns (FRS 10.23). Date range and `statuses`
/// filter on the server; every other filter is the search box over the loaded rows.
class ReportDef {
  const ReportDef(
    this.key,
    this.title,
    this.collection,
    this.cols, {
    this.dateField = 'createdAt',
    this.isDay = false,
    this.hasDates = true,
    this.statuses = const [],
    this.fixedStatuses = const [],
    this.where = const {},
  });

  final String key;
  final String title;
  final String collection;
  final String dateField;
  final List<ReportCol> cols;

  /// Date field holds a calendar day (midnight India time) instead of an instant.
  final bool isDay;
  final bool hasDates;

  /// Status choices offered to the user / statuses always applied.
  final List<String> statuses;
  final List<String> fixedStatuses;
  final Map<String, Object?> where;
}

ReportCol _textColumn(String label, String field, {bool sum = false}) =>
    ReportCol(label, (m, _) => readString(m[field]), sum: sum);
ReportCol _item() =>
    ReportCol('Item', (data, reportNames) => reportNames.item(data['itemId']));
ReportCol _store(String value) =>
    ReportCol('Store', (data, reportNames) => reportNames.store(data[value]));
ReportCol _date(String label, String value) =>
    ReportCol(label, (m, _) => readDay(m[value]).toDisplayDay());
ReportCol _quantityColumn(String label, String value, {bool sum = false}) =>
    ReportCol(label, (m, _) => readString(readNumber(m[value])), sum: sum);

const _poStates = [
  'draft',
  'issued',
  'acknowledged',
  'partially_received',
  'fully_received',
  'closed',
  'cancelled',
];

final stockCols = <ReportCol>[
  _item(),
  _store('storeId'),
  ReportCol('Batch', (m, _) => readString(m['batchNumber'])),
  _quantityColumn('Available', 'quantityAvailable', sum: true),
  _quantityColumn('Damaged', 'quantityDamaged', sum: true),
  _quantityColumn('Expired', 'quantityExpired', sum: true),
  ReportCol('Value', (m, _) => _money(m['value']), sum: true),
];

/// Dashboard figures from the `inventoryStats/overall` [summary] (InventoryStatsTotals): the branch's, with the
/// stock figures of [storeId] when given. Expired and expiring stock lines are the `expiryOn` days before [today]
/// and in the next 30 (`yyyy-MM-dd`).
Map<String, num> overviewFigures(
  Map<String, dynamic>? summary,
  String? storeId, {
  required String today,
}) {
  final branch = summary ?? const <String, dynamic>{};
  final stock = storeId == null
      ? branch
      : (branch['stores'] as Map<String, dynamic>?)?[storeId]
                as Map<String, dynamic>? ??
            const <String, dynamic>{};
  num figure(Map<String, dynamic> source, String key) =>
      source[key] as num? ?? 0;
  final soon = DateTime.parse(today).add(const Duration(days: 30)).toApiDate();
  num lines(bool Function(String day) test) =>
      (stock['expiryOn'] as Map<String, dynamic>? ?? const {}).entries
          .where((entry) => test(entry.key))
          .fold<num>(0, (total, entry) => total + (entry.value as num));
  final pendingPurchases = figure(branch, 'pendingPurchaseRequests');
  return {
    'items': figure(branch, 'items'),
    'available': figure(stock, 'available'),
    'value': figure(stock, 'value'),
    'low': figure(stock, 'lowStock'),
    'out': figure(stock, 'outOfStock'),
    'expiring': lines(
      (day) => day.compareTo(today) >= 0 && day.compareTo(soon) <= 0,
    ),
    'expired': lines((day) => day.compareTo(today) < 0),
    'prs': pendingPurchases,
    'approvals': pendingPurchases + figure(branch, 'pendingIssueRequests'),
    'pos': figure(branch, 'openPurchaseOrders'),
    'receipts': figure(branch, 'awaitingReceipt'),
    'assets': figure(branch, 'assets'),
    'maint': figure(branch, 'underMaintenance'),
  };
}

/// The FRS 10.23 reports.
final inventoryReports = <ReportDef>[
  ReportDef(
    'stock',
    'Stock summary',
    'inventoryBalances',
    stockCols,
    hasDates: false,
  ),
  ReportDef('itemwise', 'Item-wise stock', 'inventoryBalances', [
    _item(),
    _store('storeId'),
    ReportCol('Batch', (m, _) => readString(m['batchNumber'])),
    _quantityColumn('Available', 'quantityAvailable', sum: true),
    _quantityColumn('Received', 'totalQuantityReceived', sum: true),
    _quantityColumn('Issued', 'totalQuantityIssued', sum: true),
  ], hasDates: false),
  ReportDef('movements', 'Stock movement', 'inventoryMovements', [
    _date('Date', 'transactionDate'),
    _item(),
    _store('storeId'),
    _textColumn('Type', 'type'),
    _quantityColumn('Qty', 'quantity', sum: true),
    _textColumn('Bucket', 'bucket'),
    _textColumn('Reference', 'referenceType'),
  ]),
  ReportDef('valuation', 'Stock valuation', 'inventoryBalances', [
    _item(),
    _store('storeId'),
    _quantityColumn('Available', 'quantityAvailable'),
    ReportCol('Unit cost', (m, _) => _money(m['unitCost'])),
    ReportCol('Value', (m, _) => _money(m['value']), sum: true),
  ], hasDates: false),
  ReportDef(
    'low',
    'Low stock',
    'inventoryBalances',
    [
      _item(),
      _store('storeId'),
      _quantityColumn('Available', 'quantityAvailable'),
    ],
    hasDates: false,
    where: {'isBelowReorderLevel': true},
  ),
  ReportDef(
    'expiry',
    'Expiry',
    'inventoryBalances',
    [
      _item(),
      _store('storeId'),
      _textColumn('Batch', 'batchNumber'),
      _date('Expires', 'earliestExpiryDate'),
      _quantityColumn('Available', 'quantityAvailable', sum: true),
    ],
    dateField: 'earliestExpiryDate',
    isDay: true,
  ),
  ReportDef(
    'purchases',
    'Purchase history',
    'inventoryPurchaseOrders',
    [
      _date('Date', 'createdAt'),
      _textColumn('Order', 'number'),
      _textColumn('Vendor', 'vendorId'),
      _textColumn('Status', 'status'),
      ReportCol('Total', (m, _) => _money(m['total']), sum: true),
    ],
    fixedStatuses: ['partially_received', 'fully_received', 'closed'],
  ),
  ReportDef('vendors', 'Vendors', 'inventoryVendors', [
    _textColumn('Code', 'code'),
    _textColumn('Name', 'name'),
    _textColumn('Status', 'status'),
  ], hasDates: false),
  ReportDef(
    'prs',
    'Purchase requests',
    'inventoryPurchaseRequests',
    [
      _date('Date', 'createdAt'),
      _textColumn('Request', 'number'),
      _textColumn('Status', 'status'),
      _textColumn('Priority', 'priority'),
    ],
    statuses: ['draft', 'pending', 'approved', 'rejected', 'cancelled'],
  ),
  ReportDef('pos', 'Purchase orders', 'inventoryPurchaseOrders', [
    _date('Date', 'createdAt'),
    _textColumn('Order', 'number'),
    _textColumn('Vendor', 'vendorId'),
    _textColumn('Status', 'status'),
    ReportCol('Total', (m, _) => _money(m['total']), sum: true),
  ], statuses: _poStates),
  ReportDef('goodsReceipts', 'Goods receiving', 'inventoryReceipts', [
    _date('Date', 'createdAt'),
    _textColumn('GRN', 'number'),
    _store('storeId'),
    _textColumn('Source', 'source'),
    ReportCol('Lines', (m, _) => '${(m['lineItems'] as List?)?.length ?? 0}'),
  ]),
  ReportDef('issues', 'Issuance', 'inventoryIssues', [
    _date('Date', 'createdAt'),
    _textColumn('Issue', 'number'),
    _store('storeId'),
    ReportCol(
      'Recipient',
      (m, _) =>
          '${(m['recipient'] as Map?)?['type'] ?? ''} #${(m['recipient'] as Map?)?['personErpId'] ?? ''}',
    ),
    ReportCol('Lines', (m, _) => '${(m['lineItems'] as List?)?.length ?? 0}'),
  ]),
  ReportDef(
    'assets',
    'Asset register',
    'inventoryAssets',
    [
      _textColumn('Name', 'name'),
      _textColumn('Serial', 'serialNumber'),
      _textColumn('Status', 'status'),
      _textColumn('Condition', 'condition'),
      ReportCol(
        'Held by',
        (m, _) => m['assignedTo'] is Map
            ? '${(m['assignedTo'] as Map)['type']} #${(m['assignedTo'] as Map)['personErpId']}'
            : '',
      ),
    ],
    statuses: [
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
  ReportDef('assignments', 'Asset assignment', 'inventoryAssetAssignments', [
    _date('Assigned', 'assignedAt'),
    _textColumn('Asset', 'assetName'),
    ReportCol(
      'Assignee',
      (m, _) =>
          '${(m['assignee'] as Map?)?['type'] ?? ''} #${(m['assignee'] as Map?)?['personErpId'] ?? ''}',
    ),
    _date('Returned', 'returnedAt'),
    _textColumn('Closed as', 'closedAs'),
  ], dateField: 'assignedAt'),
  ReportDef(
    'maintenance',
    'Maintenance',
    'inventoryMaintenanceJobs',
    [
      _date('Date', 'createdAt'),
      _textColumn('Job', 'number'),
      _textColumn('Asset', 'assetName'),
      _textColumn('Status', 'status'),
      ReportCol('Cost', (m, _) => _money(m['cost']), sum: true),
    ],
    statuses: [
      'open',
      'assigned',
      'in_progress',
      'waiting_for_parts',
      'completed',
      'cancelled',
    ],
  ),
];

/// Dashboard tiles (FRS 10.1): key, label, permissions that can read the underlying records.
const dashboardStats = <(String, String, List<String>)>[
  ('items', 'Active items', ['inventory.items.view']),
  (
    'available',
    'Available stock',
    ['inventory.stock.view', 'inventory.reports.view'],
  ),
  ('value', 'Stock value', ['inventory.stock.view', 'inventory.reports.view']),
  (
    'low',
    'Low-stock lines',
    ['inventory.stock.view', 'inventory.reports.view'],
  ),
  (
    'out',
    'Out-of-stock lines',
    ['inventory.stock.view', 'inventory.reports.view'],
  ),
  (
    'expiring',
    'Expiring in 30 days',
    ['inventory.stock.view', 'inventory.reports.view'],
  ),
  (
    'expired',
    'Expired lines',
    ['inventory.stock.view', 'inventory.reports.view'],
  ),
  (
    'prs',
    'Pending purchase requests',
    ['inventory.purchaseRequest.approve', 'inventory.procure.operate'],
  ),
  (
    'approvals',
    'Pending approvals',
    ['inventory.purchaseRequest.approve', 'inventory.issue.approve'],
  ),
  (
    'pos',
    'Open purchase orders',
    ['inventory.procure.operate', 'inventory.reports.view'],
  ),
  (
    'receipts',
    'Pending goods receipts',
    ['inventory.procure.operate', 'inventory.reports.view'],
  ),
  ('assets', 'Registered assets', ['inventory.assets.view']),
  ('maint', 'Assets under maintenance', ['inventory.assets.view']),
];
