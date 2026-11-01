// Stock verification, dashboard and reports (Inv-7). Parse and display only; rules live in Cloud Functions.

import 'package:icue_firebase/icue_firebase.dart' show Timestamp;

num _n(Object? v) => v as num? ?? 0;

/// One verification session (`invVerifications`).
class InvVerification {
  const InvVerification({
    required this.id,
    required this.number,
    required this.storeId,
    required this.storeName,
    required this.campusId,
    required this.status,
    required this.lineCount,
    required this.date,
    this.diffCount,
    this.remarks,
    this.approvalComment,
  });

  factory InvVerification.fromMap(String id, Map<String, dynamic> m) =>
      InvVerification(
        id: id,
        number: m['number'] as String? ?? '',
        storeId: m['storeId'] as String? ?? '',
        storeName: m['storeName'] as String? ?? '',
        campusId: _n(m['campusId']).toInt(),
        status: m['status'] as String? ?? 'counting',
        lineCount: _n(m['lineCount']).toInt(),
        date: m['verifiedDate'] as String? ?? '',
        diffCount: (m['diffCount'] as num?)?.toInt(),
        remarks: m['remarks'] as String?,
        approvalComment: (m['approval'] as Map?)?['comment'] as String?,
      );

  /// `counting` → `submitted` → `applied` (a rejected session goes back to `counting`).
  final String id;
  final String number;
  final String storeId;
  final String storeName;
  final String status;
  final String date;
  final int campusId;
  final int lineCount;
  final int? diffCount;
  final String? remarks;
  final String? approvalComment;

  bool get counting => status == 'counting';
  bool get submitted => status == 'submitted';
}

/// One counted balance of a session (`invVerifications/{id}/lines`).
class VerificationLine {
  const VerificationLine({
    required this.balanceId,
    required this.itemId,
    required this.expected,
    this.batchNo,
    this.counted,
    this.reason,
    this.note,
  });

  factory VerificationLine.fromMap(Map<String, dynamic> m) => VerificationLine(
    balanceId: m['balanceId'] as String? ?? '',
    itemId: m['itemId'] as String? ?? '',
    batchNo: m['batchNo'] as String?,
    expected: _n(m['expected']),
    counted: m['counted'] as num?,
    reason: m['reason'] as String?,
    note: m['note'] as String?,
  );

  static const reasons = ['missing', 'excess', 'count_correction', 'other'];

  final String balanceId;
  final String itemId;
  final String? batchNo;
  final String? reason;
  final String? note;
  final num expected;
  final num? counted;

  num? get diff => counted == null ? null : counted! - expected;
}

/// RFC 4180 CSV (quotes only where needed).
String toCsv(List<String> header, List<List<String>> rows) {
  String cell(String v) =>
      v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  return [header, ...rows].map((r) => r.map(cell).join(',')).join('\n');
}

/// Resolves IDs to display names for report cells.
class ReportNames {
  const ReportNames({required this.item, required this.store});

  final String Function(Object? id) item;
  final String Function(Object? id) store;
}

typedef ReportRow = Map<String, dynamic>;

String _s(Object? v) => v == null ? '' : '$v';

/// Timestamp or `yyyy-MM-dd` string as a day.
String dayOf(Object? v) {
  if (v is String) return v.length >= 10 ? v.substring(0, 10) : v;
  return v is Timestamp ? v.toDate().toIso8601String().substring(0, 10) : '';
}

String _money(Object? v) => v == null ? '' : _n(v).toStringAsFixed(2);

class ReportCol {
  const ReportCol(this.label, this.cell, {this.sum = false});

  final String label;
  final String Function(ReportRow m, ReportNames n) cell;

  /// Total shown under the table (cells must be numbers).
  final bool sum;
}

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

ReportCol _c(String label, String field, {bool sum = false}) =>
    ReportCol(label, (m, _) => _s(m[field]), sum: sum);
ReportCol _item() => ReportCol('Item', (m, n) => n.item(m['itemId']));
ReportCol _store(String f) => ReportCol('Store', (m, n) => n.store(m[f]));
ReportCol _date(String label, String f) =>
    ReportCol(label, (m, _) => dayOf(m[f]));
ReportCol _qty(String label, String f, {bool sum = false}) =>
    ReportCol(label, (m, _) => _s(_n(m[f])), sum: sum);

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
  ReportCol('Batch', (m, _) => _s(m['batchNo'])),
  _qty('Available', 'qtyAvailable', sum: true),
  _qty('Damaged', 'qtyDamaged', sum: true),
  _qty('Expired', 'qtyExpired', sum: true),
  ReportCol('Value', (m, _) => _money(m['value']), sum: true),
];

/// The FRS 10.23 reports.
final inventoryReports = <ReportDef>[
  ReportDef(
    'stock',
    'Stock summary',
    'invBalances',
    stockCols,
    hasDates: false,
  ),
  ReportDef('itemwise', 'Item-wise stock', 'invBalances', [
    _item(),
    _store('storeId'),
    ReportCol('Batch', (m, _) => _s(m['batchNo'])),
    _qty('Available', 'qtyAvailable', sum: true),
    _qty('Received', 'qtyReceivedTotal', sum: true),
    _qty('Issued', 'qtyIssuedTotal', sum: true),
  ], hasDates: false),
  ReportDef('movements', 'Stock movement', 'invMovements', [
    _date('Date', 'txnDate'),
    _item(),
    _store('storeId'),
    _c('Type', 'type'),
    _qty('Qty', 'qty', sum: true),
    _c('Bucket', 'bucket'),
    _c('Reference', 'refType'),
  ]),
  ReportDef('valuation', 'Stock valuation', 'invBalances', [
    _item(),
    _store('storeId'),
    _qty('Available', 'qtyAvailable'),
    ReportCol('Unit cost', (m, _) => _money(m['unitCost'])),
    ReportCol('Value', (m, _) => _money(m['value']), sum: true),
  ], hasDates: false),
  ReportDef(
    'low',
    'Low stock',
    'invBalances',
    [_item(), _store('storeId'), _qty('Available', 'qtyAvailable')],
    hasDates: false,
    where: {'belowReorder': true},
  ),
  ReportDef(
    'expiry',
    'Expiry',
    'invBalances',
    [
      _item(),
      _store('storeId'),
      _c('Batch', 'batchNo'),
      _c('Expires', 'expKey'),
      _qty('Available', 'qtyAvailable', sum: true),
    ],
    dateField: 'expKey',
    isString: true,
  ),
  ReportDef(
    'purchases',
    'Purchase history',
    'invPurchaseOrders',
    [
      _date('Date', 'createdAt'),
      _c('Order', 'number'),
      _c('Vendor', 'vendorId'),
      _c('Status', 'status'),
      ReportCol('Total', (m, _) => _money(m['total']), sum: true),
    ],
    fixedStatuses: ['partially_received', 'fully_received', 'closed'],
  ),
  ReportDef(
    'vendors',
    'Vendors',
    'invVendors',
    [_c('Code', 'code'), _c('Name', 'name'), _c('Status', 'status')],
    hasDates: false,
    schoolWide: true,
  ),
  ReportDef(
    'prs',
    'Purchase requests',
    'invPurchaseRequests',
    [
      _date('Date', 'createdAt'),
      _c('Request', 'number'),
      _c('Status', 'status'),
      _c('Priority', 'priority'),
    ],
    statuses: ['draft', 'pending', 'approved', 'rejected', 'cancelled'],
  ),
  ReportDef('pos', 'Purchase orders', 'invPurchaseOrders', [
    _date('Date', 'createdAt'),
    _c('Order', 'number'),
    _c('Vendor', 'vendorId'),
    _c('Status', 'status'),
    ReportCol('Total', (m, _) => _money(m['total']), sum: true),
  ], statuses: _poStates),
  ReportDef('grn', 'Goods receiving', 'invReceipts', [
    _date('Date', 'createdAt'),
    _c('GRN', 'number'),
    _store('storeId'),
    _c('Source', 'source'),
    ReportCol('Lines', (m, _) => '${(m['lines'] as List?)?.length ?? 0}'),
  ]),
  ReportDef('issues', 'Issuance', 'invIssues', [
    _date('Date', 'createdAt'),
    _c('Issue', 'number'),
    _store('storeId'),
    ReportCol(
      'Recipient',
      (m, _) =>
          '${(m['recipient'] as Map?)?['type'] ?? ''} #${(m['recipient'] as Map?)?['erpId'] ?? ''}',
    ),
    ReportCol('Lines', (m, _) => '${(m['lines'] as List?)?.length ?? 0}'),
  ]),
  ReportDef('transfers', 'Transfers', 'invTransfers', [
    _date('Date', 'createdAt'),
    _c('Transfer', 'number'),
    ReportCol('From', (m, n) => n.store((m['from'] as Map?)?['storeId'])),
    ReportCol('To', (m, n) => n.store((m['to'] as Map?)?['storeId'])),
    _c('Status', 'status'),
  ]),
  ReportDef(
    'assets',
    'Asset register',
    'invAssets',
    [
      _c('Asset', 'assetId'),
      _c('Name', 'name'),
      _c('Serial', 'serialNo'),
      _c('Status', 'status'),
      _c('Condition', 'condition'),
      ReportCol(
        'Held by',
        (m, _) => m['assignedTo'] is Map
            ? '${(m['assignedTo'] as Map)['type']} #${(m['assignedTo'] as Map)['erpId']}'
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
  ReportDef('assignments', 'Asset assignment', 'invAssetAssignments', [
    _date('Assigned', 'assignedAt'),
    _c('Asset', 'assetCode'),
    _c('Name', 'assetName'),
    ReportCol(
      'Assignee',
      (m, _) =>
          '${(m['assignee'] as Map?)?['type'] ?? ''} #${(m['assignee'] as Map?)?['erpId'] ?? ''}',
    ),
    _date('Returned', 'returnedAt'),
    _c('Closed as', 'closedAs'),
  ], dateField: 'assignedAt'),
  ReportDef(
    'maintenance',
    'Maintenance',
    'invMaintenance',
    [
      _date('Date', 'createdAt'),
      _c('Job', 'number'),
      _c('Asset', 'assetCode'),
      _c('Status', 'status'),
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
  ReportDef('verifications', 'Stock verification', 'invVerifications', [
    _date('Date', 'createdAt'),
    _c('Session', 'number'),
    _c('Store', 'storeName'),
    _c('Status', 'status'),
    _qty('Lines', 'lineCount', sum: true),
    _qty('Differences', 'diffCount', sum: true),
  ]),
];

/// Dashboard tiles (FRS 10.1): key, label, permissions that can read the underlying records.
const dashboardStats = <(String, String, List<String>)>[
  ('items', 'Active items', ['inv.items.view']),
  ('available', 'Available stock', ['inv.stock.view', 'inv.reports.view']),
  ('value', 'Stock value', ['inv.stock.view', 'inv.reports.view']),
  ('low', 'Low-stock lines', ['inv.stock.view', 'inv.reports.view']),
  ('out', 'Out-of-stock lines', ['inv.stock.view', 'inv.reports.view']),
  ('expiring', 'Expiring in 30 days', ['inv.stock.view', 'inv.reports.view']),
  ('expired', 'Expired lines', ['inv.stock.view', 'inv.reports.view']),
  (
    'prs',
    'Pending purchase requests',
    ['inv.pr.approve', 'inv.procure.operate'],
  ),
  ('approvals', 'Pending approvals', ['inv.pr.approve', 'inv.issue.approve']),
  ('pos', 'Open purchase orders', ['inv.procure.operate', 'inv.reports.view']),
  (
    'receipts',
    'Pending goods receipts',
    ['inv.procure.operate', 'inv.reports.view'],
  ),
  ('assets', 'Registered assets', ['inv.assets.view']),
  ('maint', 'Assets under maintenance', ['inv.assets.view']),
];

/// Parses RFC 4180 CSV (quoted cells, `""` escapes, CRLF) into maps keyed by the header row.
/// Blank lines are skipped; header names are trimmed.
List<Map<String, String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c != '"') {
        cell.write(c);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else if (c != '\r') {
      cell.write(c);
    }
  }
  endRow();
  if (rows.isEmpty) return [];
  final header = [for (final h in rows.first) h.trim()];
  return [
    for (final r in rows.skip(1))
      {
        for (var k = 0; k < header.length; k++)
          header[k]: k < r.length ? r[k].trim() : '',
      },
  ];
}

/// Columns of each import type (`inv-import-run`); the first row of the pasted CSV.
const importColumns = <String, List<String>>{
  'categories': ['code', 'name', 'tracking', 'parentCode'],
  'stores': ['code', 'name', 'campusId', 'location'],
  'items': [
    'code',
    'name',
    'categoryCode',
    'stockUnit',
    'tracking',
    'minLevel',
    'reorderLevel',
    'defaultPrice',
  ],
  'vendors': ['code', 'name', 'contactPerson', 'phone', 'email', 'taxNo'],
};
