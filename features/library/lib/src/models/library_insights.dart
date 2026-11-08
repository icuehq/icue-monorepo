// Library dashboard, reports and import columns (Lib-8). Display only; rules live in Cloud Functions and Firestore rules.

import 'package:core_ui/core_ui.dart';
import 'package:icue_firebase/icue_firebase.dart'
    show ReportColumn, ReportRow, readDay, readNumber, readString;

/// Resolves IDs to display names for report cells.
class LibraryNames {
  const LibraryNames({
    required this.title,
    required this.library,
    required this.category,
  });

  final String Function(Object? id) title;
  final String Function(Object? id) library;
  final String Function(Object? id) category;
}

typedef LibraryReportCol = ReportColumn<LibraryNames>;

/// How a report's rows are produced.
enum LibraryReportType {
  /// One campus-scoped collection query.
  query,

  /// Titles ranked by loans in the period (computed over the loans).
  popular,

  /// Titles with copies but no loan in the period.
  inactive,
}

/// A report is one campus-scoped collection query plus columns (FRS 11.18). Library, date range and `statuses`
/// filter on the server; every other filter (member, category, author…) is the search box over the loaded rows.
class LibraryReportDef {
  const LibraryReportDef(
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
    this.type = LibraryReportType.query,
  });

  final String key;
  final String title;
  final String collection;
  final List<LibraryReportCol> cols;

  /// Field holding the date the range filters (a Timestamp); null = no date filter.
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
  final LibraryReportType type;

  bool get hasDates => dateField != null;
}

LibraryReportCol _textColumn(String label, String field, {bool sum = false}) =>
    LibraryReportCol(label, (m, _) => readString(m[field]), sum: sum);
LibraryReportCol _dayColumn(String label, String value) =>
    LibraryReportCol(label, (m, _) => readDay(m[value]).toDisplayDay());
LibraryReportCol _title() => LibraryReportCol(
  'Title',
  (data, names) => names.title(data['catalogueId']),
);
LibraryReportCol _lib([String f = 'libraryId']) =>
    LibraryReportCol('Library', (data, names) => names.library(data[f]));
LibraryReportCol _person() => LibraryReportCol(
  'Member',
  (m, _) => '${m['memberType'] ?? 'person'} #${m['personErpId'] ?? ''}',
);
LibraryReportCol _money(String label, String value) => LibraryReportCol(
  label,
  (m, _) => readNumber(m[value]).toAmountText(),
  sum: true,
);

int _overdueDays(ReportRow data) {
  final due = DateTime.tryParse(readDay(data['dueDate']));
  if (due == null) return 0;
  final today = DateTime.now();
  final value = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(due).inDays;
  return value < 0 ? 0 : value;
}

const _loanStatuses = ['active', 'returned', 'lost'];

/// The FRS 11.18 reports.
final libraryReports = <LibraryReportDef>[
  LibraryReportDef(
    'catalogue',
    'Book catalogue',
    'libraryCatalogue',
    [
      _textColumn('Title', 'title'),
      LibraryReportCol(
        'Authors',
        (m, _) => ((m['authors'] as List?) ?? []).join('; '),
      ),
      _textColumn('Publisher', 'publisher'),
      _textColumn('Edition', 'edition'),
      _textColumn('Year', 'year'),
      LibraryReportCol(
        'Category',
        (data, names) => names.category(data['categoryId']),
      ),
    ],
    schoolWide: true,
    hasLibrary: false,
  ),
  LibraryReportDef('accession', 'Copy register', 'libraryCopies', [
    _textColumn('Barcode', 'barcode'),
    _title(),
    _lib(),
    _textColumn('Shelf', 'shelf'),
    _dayColumn('Acquired', 'acquiredDate'),
    _money('Price', 'price'),
  ], dateField: 'acquiredDate'),
  LibraryReportDef(
    'stock',
    'Library stock',
    'libraryCopies',
    [
      _textColumn('Barcode', 'barcode'),
      _title(),
      _lib(),
      _textColumn('Shelf', 'shelf'),
      _textColumn('Status', 'status'),
      _textColumn('Condition', 'condition'),
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
  LibraryReportDef(
    'available',
    'Available books',
    'libraryCopies',
    [
      _textColumn('Barcode', 'barcode'),
      _title(),
      _lib(),
      _textColumn('Shelf', 'shelf'),
    ],
    where: {'status': 'available'},
  ),
  LibraryReportDef(
    'issued',
    'Issued books',
    'libraryLoans',
    [
      _textColumn('Issue', 'number'),
      _person(),
      _title(),
      _textColumn('Barcode', 'barcode'),
      _lib(),
      _dayColumn('Issued', 'issuedDate'),
      _dayColumn('Due', 'dueDate'),
    ],
    dateField: 'issuedDate',
    where: {'status': 'active'},
  ),
  LibraryReportDef(
    'overdue',
    'Overdue books',
    'libraryLoans',
    [
      _textColumn('Issue', 'number'),
      _person(),
      _title(),
      _lib(),
      _dayColumn('Due', 'dueDate'),
      LibraryReportCol(
        'Days overdue',
        (m, _) => '${_overdueDays(m)}',
        sum: true,
      ),
    ],
    where: {'status': 'active'},
    overdue: true,
  ),
  LibraryReportDef(
    'history',
    'Member history',
    'libraryLoans',
    [
      _textColumn('Issue', 'number'),
      _person(),
      _title(),
      _dayColumn('Issued', 'issuedDate'),
      _dayColumn('Due', 'dueDate'),
      _dayColumn('Returned', 'returnedDate'),
      _textColumn('Status', 'status'),
    ],
    dateField: 'issuedDate',
    statuses: _loanStatuses,
  ),
  LibraryReportDef(
    'fines',
    'Fine report',
    'libraryFines',
    [
      _dayColumn('Date', 'createdAt'),
      _textColumn('Fine', 'fineNumber'),
      _person(),
      _textColumn('Type', 'type'),
      _money('Amount', 'amount'),
      _money('Waived', 'waived'),
      _money('Paid', 'paid'),
      _money('Outstanding', 'outstanding'),
      _textColumn('Status', 'status'),
    ],
    dateField: 'createdAt',
    statuses: ['outstanding', 'partially_paid', 'paid', 'waived'],
  ),
  LibraryReportDef(
    'lost',
    'Lost books',
    'libraryIncidents',
    [
      _dayColumn('Date', 'reportedDate'),
      _textColumn('Incident', 'incidentNumber'),
      _textColumn('Barcode', 'barcode'),
      _title(),
      _lib(),
      _money('Charge', 'charge'),
      _textColumn('Status', 'status'),
    ],
    dateField: 'reportedDate',
    where: {'type': 'lost'},
  ),
  LibraryReportDef(
    'damaged',
    'Damaged books',
    'libraryIncidents',
    [
      _dayColumn('Date', 'reportedDate'),
      _textColumn('Incident', 'incidentNumber'),
      _textColumn('Barcode', 'barcode'),
      _title(),
      _lib(),
      _textColumn('Severity', 'severity'),
      _textColumn('Repair', 'repairStatus'),
      _textColumn('Status', 'status'),
    ],
    dateField: 'reportedDate',
    where: {'type': 'damaged'},
  ),
  LibraryReportDef(
    'acquisitions',
    'Acquisition report',
    'libraryAcquisitions',
    [
      _dayColumn('Date', 'date'),
      _textColumn('Acquisition', 'number'),
      _title(),
      _lib(),
      LibraryReportCol(
        'Copies',
        (m, _) => readString(readNumber(m['quantity'])),
        sum: true,
      ),
      _money('Price', 'price'),
    ],
    dateField: 'date',
  ),
  LibraryReportDef(
    'popular',
    'Popular books',
    'libraryLoans',
    [
      _title(),
      LibraryReportCol(
        'Loans',
        (m, _) => readString(readNumber(m['count'])),
        sum: true,
      ),
    ],
    dateField: 'issuedDate',
    type: LibraryReportType.popular,
  ),
  LibraryReportDef(
    'inactive',
    'Inactive books',
    'libraryLoans',
    [
      _title(),
      LibraryReportCol(
        'Copies',
        (m, _) => readString(readNumber(m['count'])),
        sum: true,
      ),
    ],
    dateField: 'issuedDate',
    type: LibraryReportType.inactive,
  ),
];

/// Dashboard tiles (FRS 11.1): key and label.
const libraryDashboardStats = <(String, String)>[
  ('titles', 'Book titles'),
  ('copies', 'Physical copies'),
  ('available', 'Available copies'),
  ('issued', 'Issued copies'),
  ('overdue', 'Overdue books'),
  ('reserved', 'Reserved books'),
  ('lost', 'Lost books'),
  ('damaged', 'Damaged books'),
  ('students', 'Student borrowers'),
  ('teachers', 'Teacher borrowers'),
  ('pending', 'Pending returns'),
  ('fines', 'Outstanding fines'),
];
