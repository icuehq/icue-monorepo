// Library dashboard, reports and import columns (Lib-8). Display only; rules live in Cloud Functions and Firestore rules.

import 'package:icue_firebase/icue_firebase.dart' show Timestamp;

num _n(Object? v) => v as num? ?? 0;
String _s(Object? v) => v == null ? '' : '$v';

/// Timestamp or `yyyy-MM-dd` string as a day.
String libDay(Object? v) {
  if (v is String) return v.length >= 10 ? v.substring(0, 10) : v;
  return v is Timestamp ? v.toDate().toIso8601String().substring(0, 10) : '';
}

/// Resolves IDs to display names for report cells.
class LibNames {
  const LibNames({
    required this.title,
    required this.library,
    required this.category,
  });

  final String Function(Object? id) title;
  final String Function(Object? id) library;
  final String Function(Object? id) category;
}

typedef LibReportRow = Map<String, dynamic>;

class LibReportCol {
  const LibReportCol(this.label, this.cell, {this.sum = false});

  final String label;
  final String Function(LibReportRow m, LibNames n) cell;

  /// Total shown under the table (cells must be numbers).
  final bool sum;
}

/// How a report's rows are produced.
enum LibReportKind {
  /// One campus-scoped collection query.
  query,

  /// Titles ranked by loans in the period (computed over the loans).
  popular,

  /// Titles with copies but no loan in the period.
  inactive,
}

/// A report is one campus-scoped collection query plus columns (FRS 11.18). Library, date range and `statuses`
/// filter on the server; every other filter (member, category, author…) is the search box over the loaded rows.
class LibReportDef {
  const LibReportDef(
    this.key,
    this.title,
    this.collection,
    this.cols, {
    this.dateField,
    this.statuses = const [],
    this.where = const {},
    this.schoolWide = false,
    this.hasLibrary = true,
    this.overdue = false,
    this.kind = LibReportKind.query,
  });

  final String key;
  final String title;
  final String collection;
  final List<LibReportCol> cols;

  /// Field holding the date the range filters (a `yyyy-MM-dd` string or a timestamp); null = no date filter.
  final String? dateField;

  /// Status choices offered to the user.
  final List<String> statuses;

  /// Equality filters always applied.
  final Map<String, Object?> where;

  /// Not campus scoped (the catalogue).
  final bool schoolWide;

  /// The collection has a `libraryId`.
  final bool hasLibrary;

  /// Active loans past their due date only.
  final bool overdue;
  final LibReportKind kind;

  bool get hasDates => dateField != null;
}

LibReportCol _c(String label, String field, {bool sum = false}) =>
    LibReportCol(label, (m, _) => _s(m[field]), sum: sum);
LibReportCol _day(String label, String f) =>
    LibReportCol(label, (m, _) => libDay(m[f]));
LibReportCol _title() =>
    LibReportCol('Title', (m, n) => n.title(m['catalogueId']));
LibReportCol _lib([String f = 'libraryId']) =>
    LibReportCol('Library', (m, n) => n.library(m[f]));
LibReportCol _person() => LibReportCol(
  'Member',
  (m, _) => '${m['memberType'] ?? 'person'} #${m['personErpId'] ?? ''}',
);
LibReportCol _money(String label, String f) =>
    LibReportCol(label, (m, _) => _n(m[f]).toStringAsFixed(2), sum: true);

int _overdueDays(LibReportRow m) {
  final due = DateTime.tryParse(_s(m['dueOn']));
  if (due == null) return 0;
  final today = DateTime.now();
  final d = DateTime(today.year, today.month, today.day).difference(due).inDays;
  return d < 0 ? 0 : d;
}

const _loanStatuses = ['active', 'returned', 'lost'];

/// The FRS 11.18 reports.
final libraryReports = <LibReportDef>[
  LibReportDef(
    'catalogue',
    'Book catalogue',
    'libCatalogue',
    [
      _c('Title', 'title'),
      LibReportCol(
        'Authors',
        (m, _) => ((m['authors'] as List?) ?? []).join('; '),
      ),
      _c('Publisher', 'publisher'),
      _c('Edition', 'edition'),
      _c('Year', 'year'),
      _c('ISBN', 'isbn13'),
      LibReportCol('Category', (m, n) => n.category(m['categoryId'])),
    ],
    schoolWide: true,
    hasLibrary: false,
  ),
  LibReportDef('accession', 'Accession register', 'libCopies', [
    _c('Accession no.', 'accessionNo'),
    _title(),
    _lib(),
    _c('Shelf', 'shelf'),
    _day('Acquired', 'acquiredOn'),
    _c('Source', 'source'),
    _money('Price', 'price'),
  ], dateField: 'acquiredOn'),
  LibReportDef(
    'stock',
    'Library stock',
    'libCopies',
    [
      _c('Accession no.', 'accessionNo'),
      _title(),
      _lib(),
      _c('Shelf', 'shelf'),
      _c('Status', 'status'),
      _c('Condition', 'condition'),
    ],
    statuses: [
      'available',
      'issued',
      'reserved',
      'under_maintenance',
      'damaged',
      'lost',
      'in_transit',
      'withdrawn',
    ],
  ),
  LibReportDef(
    'available',
    'Available books',
    'libCopies',
    [
      _c('Accession no.', 'accessionNo'),
      _title(),
      _lib(),
      _c('Shelf', 'shelf'),
    ],
    where: {'status': 'available'},
  ),
  LibReportDef(
    'issued',
    'Issued books',
    'libLoans',
    [
      _c('Issue', 'number'),
      _person(),
      _title(),
      _c('Accession no.', 'accessionNo'),
      _lib(),
      _day('Issued', 'issuedOn'),
      _day('Due', 'dueOn'),
    ],
    dateField: 'issuedOn',
    where: {'status': 'active'},
  ),
  LibReportDef(
    'overdue',
    'Overdue books',
    'libLoans',
    [
      _c('Issue', 'number'),
      _person(),
      _title(),
      _lib(),
      _day('Due', 'dueOn'),
      LibReportCol('Days overdue', (m, _) => '${_overdueDays(m)}', sum: true),
    ],
    where: {'status': 'active'},
    overdue: true,
  ),
  LibReportDef(
    'history',
    'Member history',
    'libLoans',
    [
      _c('Issue', 'number'),
      _person(),
      _title(),
      _day('Issued', 'issuedOn'),
      _day('Due', 'dueOn'),
      _day('Returned', 'returnedOn'),
      _c('Status', 'status'),
    ],
    dateField: 'issuedOn',
    statuses: _loanStatuses,
  ),
  LibReportDef(
    'fines',
    'Fine report',
    'libFines',
    [
      _day('Date', 'createdAt'),
      _c('Fine', 'fineNumber'),
      _person(),
      _c('Type', 'type'),
      _money('Amount', 'amount'),
      _money('Waived', 'waived'),
      _money('Paid', 'paid'),
      _money('Outstanding', 'outstanding'),
      _c('Status', 'status'),
    ],
    dateField: 'createdAt',
    statuses: ['outstanding', 'partially_paid', 'paid', 'waived'],
  ),
  LibReportDef(
    'lost',
    'Lost books',
    'libIncidents',
    [
      _day('Date', 'reportedDate'),
      _c('Incident', 'incidentNumber'),
      _c('Accession no.', 'accessionNo'),
      _title(),
      _lib(),
      _money('Charge', 'charge'),
      _c('Status', 'status'),
    ],
    dateField: 'reportedDate',
    where: {'kind': 'lost'},
  ),
  LibReportDef(
    'damaged',
    'Damaged books',
    'libIncidents',
    [
      _day('Date', 'reportedDate'),
      _c('Incident', 'incidentNumber'),
      _c('Accession no.', 'accessionNo'),
      _title(),
      _lib(),
      _c('Severity', 'severity'),
      _c('Repair', 'repairStatus'),
      _c('Status', 'status'),
    ],
    dateField: 'reportedDate',
    where: {'kind': 'damaged'},
  ),
  LibReportDef(
    'acquisitions',
    'Acquisition report',
    'libAcquisitions',
    [
      _day('Date', 'date'),
      _c('Acquisition', 'number'),
      _c('Source', 'type'),
      _title(),
      _lib(),
      LibReportCol('Copies', (m, _) => _s(_n(m['qty'])), sum: true),
      _money('Price', 'price'),
      _c('Vendor / donor', 'vendorOrDonor'),
    ],
    dateField: 'date',
    statuses: ['purchase', 'donation', 'opening'],
  ),
  LibReportDef(
    'transfers',
    'Transfer report',
    'libTransfers',
    [
      _day('Date', 'createdAt'),
      _c('Transfer', 'number'),
      _lib('fromLibraryId'),
      LibReportCol('To', (m, n) => n.library(m['toLibraryId'])),
      LibReportCol('Copies', (m, _) => '${(m['lines'] as List?)?.length ?? 0}'),
      _c('Status', 'status'),
    ],
    dateField: 'createdAt',
    statuses: [
      'requested',
      'approved',
      'dispatched',
      'partially_received',
      'received',
    ],
    hasLibrary: false,
  ),
  LibReportDef(
    'verifications',
    'Verification report',
    'libVerifications',
    [
      _day('Date', 'createdAt'),
      _c('Session', 'number'),
      _c('Library', 'libraryName'),
      _c('Shelf', 'shelf'),
      LibReportCol(
        'Expected',
        (m, _) => '${(m['expected'] as List?)?.length ?? 0}',
      ),
      LibReportCol(
        'Missing',
        (m, _) => '${(m['missing'] as List?)?.length ?? 0}',
        sum: true,
      ),
      LibReportCol(
        'Unexpected',
        (m, _) => '${(m['unexpected'] as List?)?.length ?? 0}',
        sum: true,
      ),
      _c('Status', 'status'),
    ],
    dateField: 'createdAt',
    statuses: ['counting', 'submitted', 'approved'],
  ),
  LibReportDef(
    'popular',
    'Popular books',
    'libLoans',
    [_title(), LibReportCol('Loans', (m, _) => _s(_n(m['count'])), sum: true)],
    dateField: 'issuedOn',
    kind: LibReportKind.popular,
  ),
  LibReportDef(
    'inactive',
    'Inactive books',
    'libLoans',
    [_title(), LibReportCol('Copies', (m, _) => _s(_n(m['count'])), sum: true)],
    dateField: 'issuedOn',
    kind: LibReportKind.inactive,
  ),
];

/// Dashboard tiles (FRS 11.1): key, label, permissions that can read the underlying records.
const libDashboardStats = <(String, String, List<String>)>[
  ('titles', 'Book titles', ['lib.catalogue.view']),
  ('copies', 'Physical copies', ['lib.catalogue.view']),
  ('available', 'Available copies', ['lib.catalogue.view']),
  ('issued', 'Issued copies', ['lib.catalogue.view']),
  ('overdue', 'Overdue books', ['lib.circulation.operate', 'lib.reports.view']),
  (
    'reserved',
    'Reserved books',
    ['lib.circulation.operate', 'lib.reports.view'],
  ),
  ('lost', 'Lost books', ['lib.catalogue.view']),
  ('damaged', 'Damaged books', ['lib.catalogue.view']),
  (
    'students',
    'Active student members',
    ['lib.members.view', 'lib.reports.view'],
  ),
  (
    'teachers',
    'Active teacher members',
    ['lib.members.view', 'lib.reports.view'],
  ),
  (
    'pending',
    'Pending returns',
    ['lib.circulation.operate', 'lib.reports.view'],
  ),
  (
    'fines',
    'Outstanding fines',
    ['lib.circulation.operate', 'lib.fines.waive', 'lib.reports.view'],
  ),
];

/// Columns of each import type (`lib-import-run`); the first row of the pasted CSV. Lists use `;`.
const libImportColumns = <String, List<String>>{
  'catalogue': [
    'title',
    'authors',
    'categoryCode',
    'isbn13',
    'isbn10',
    'publisher',
    'edition',
    'year',
    'language',
    'pages',
    'classNo',
    'keywords',
  ],
  'copies': [
    'isbn13',
    'libraryCode',
    'qty',
    'price',
    'shelf',
    'condition',
    'date',
  ],
  'members': [
    'memberType',
    'erpId',
    'memberCategory',
    'libraryCodes',
    'start',
    'end',
    'classId',
  ],
};

/// Permission the single-record callable of each import type needs.
const libImportPerms = <String, String>{
  'catalogue': 'lib.catalogue.manage',
  'copies': 'lib.catalogue.manage',
  'members': 'lib.circulation.operate',
};
