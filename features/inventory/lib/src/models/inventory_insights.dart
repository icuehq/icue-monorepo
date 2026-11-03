// Stock verification, dashboard and reports (Inv-7). Parse and display only; rules live in Cloud Functions.

import 'package:core_ui/core_ui.dart';
import 'package:icue_firebase/icue_firebase.dart'
    show ReportColumn, readDay, readNumber, readString;
import 'package:inventory/src/models/inventory_insights.g.dart';

export 'inventory_insights.g.dart';

extension InventoryVerificationMembers on InventoryVerification {
  bool get counting => status == 'counting';
  bool get submitted => status == 'submitted';
}

extension VerificationLineMembers on VerificationLine {
  num? get difference => counted == null ? null : counted! - expected;
}

/// Resolves IDs to display names for report cells.
class ReportNames {
  const ReportNames({required this.item, required this.store});

  final String Function(Object? id) item;
  final String Function(Object? id) store;
}

String _money(Object? value) =>
    value == null ? '' : readNumber(value).toAmountText();

typedef ReportCol = ReportColumn<ReportNames>;

/// A report is one campus-scoped collection query plus columns (FRS 10.23). Date range and `statuses`
/// filter on the server; every other filter is the search box over the loaded rows.
class ReportDef {
  const ReportDef(
    this.key,
    this.title,
    this.collection,
    this.cols, {
    this.dateField = 'createdAt',
    this.isString = false,
    this.hasDates = true,
    this.statuses = const [],
    this.fixedStatuses = const [],
    this.where = const {},
    this.schoolWide = false,
  });

  final String key;
  final String title;
  final String collection;
  final String dateField;
  final List<ReportCol> cols;

  /// Date field holds a `yyyy-MM-dd` string instead of a timestamp.
  final bool isString;
  final bool hasDates;
  final bool schoolWide;

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
      _textColumn('Expires', 'earliestExpiryDate'),
      _quantityColumn('Available', 'quantityAvailable', sum: true),
    ],
    dateField: 'earliestExpiryDate',
    isString: true,
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
  ReportDef(
    'vendors',
    'Vendors',
    'inventoryVendors',
    [
      _textColumn('Code', 'code'),
      _textColumn('Name', 'name'),
      _textColumn('Status', 'status'),
    ],
    hasDates: false,
    schoolWide: true,
  ),
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
  ReportDef('transfers', 'Transfers', 'inventoryTransfers', [
    _date('Date', 'createdAt'),
    _textColumn('Transfer', 'number'),
    ReportCol(
      'From',
      (data, reportNames) =>
          reportNames.store((data['from'] as Map?)?['storeId']),
    ),
    ReportCol(
      'To',
      (data, reportNames) =>
          reportNames.store((data['to'] as Map?)?['storeId']),
    ),
    _textColumn('Status', 'status'),
  ]),
  ReportDef(
    'assets',
    'Asset register',
    'inventoryAssets',
    [
      _textColumn('Asset', 'assetId'),
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
    _textColumn('Asset', 'assetCode'),
    _textColumn('Name', 'assetName'),
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
      _textColumn('Asset', 'assetCode'),
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
  ReportDef('verifications', 'Stock verification', 'inventoryVerifications', [
    _date('Date', 'createdAt'),
    _textColumn('Session', 'number'),
    _textColumn('Store', 'storeName'),
    _textColumn('Status', 'status'),
    _quantityColumn('Lines', 'lineCount', sum: true),
    _quantityColumn('Differences', 'differenceCount', sum: true),
  ]),
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

/// Columns of each import type (`inventory-import-run`); the first row of the pasted CSV.
const importColumns = <String, List<String>>{
  'categories': ['code', 'name', 'tracking', 'parentCode'],
  'stores': ['code', 'name', 'campusId', 'location'],
  'items': [
    'code',
    'name',
    'categoryCode',
    'stockUnit',
    'tracking',
    'reorderLevel',
    'defaultPrice',
  ],
  'vendors': ['code', 'name', 'contactPerson', 'phone', 'email', 'taxNumber'],
};

/// Permission the single-record callable of each import type needs.
const importPermissions = <String, String>{
  'categories': 'inventory.settings',
  'stores': 'inventory.settings',
  'items': 'inventory.items.manage',
  'vendors': 'inventory.vendors.manage',
};
