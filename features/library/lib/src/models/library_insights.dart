// Library dashboard figures and loan reports. Display only; rules live in Firestore rules.

import 'package:icue_firebase/icue_firebase.dart'
    show ReportColumn, readDay, readNumber, readString;
import 'package:icue_ui/icue_ui.dart';

/// Resolves IDs to display names for report cells.
class LibraryNames {
  const LibraryNames({
    required this.title,
    required this.library,
    required this.classLabel,
  });

  final String Function(Object? id) title;
  final String Function(Object? id) library;
  final String Function(int? classId, String? section) classLabel;
}

typedef LibraryReportCol = ReportColumn<LibraryNames>;

/// How a report's rows are built from the loans of the chosen period.
/// KPI counts of the loans report across every matching loan, not just the loaded page.
typedef LoanReportCounts = ({int returned, int active, int overdueOrLost});

enum LibraryReportKind {
  /// One row per loan issued in the range.
  loans,

  /// One row per month: books issued and returned.
  monthly,

  /// One row per student: loans in the range.
  student,

  /// One row per staff member (teacher): loans in the range.
  staff,
}

class LibraryReportDef {
  const LibraryReportDef(
    this.key,
    this.title,
    this.blurb,
    this.kind,
    this.cols, {
    this.statuses = const [],
  });

  final String key;
  final String title;
  final String blurb;
  final LibraryReportKind kind;
  final List<LibraryReportCol> cols;

  /// Loan status choices offered to the user (loans report only).
  final List<String> statuses;
}

LibraryReportCol _text(String label, String field) =>
    LibraryReportCol(label, (m, _) => readString(m[field]));
LibraryReportCol _day(String label, String field) =>
    LibraryReportCol(label, (m, _) => readDay(m[field]).toDisplayDay());
LibraryReportCol _count(String label, String field) => LibraryReportCol(
  label,
  (m, _) => readString(readNumber(m[field])),
  sum: true,
);

/// Member name with class and section on a second line (students only).
LibraryReportCol _member() => LibraryReportCol('Member', (m, names) {
  final name = readString(m['memberName']);
  final label = name.isEmpty ? '#${m['personErpId']}' : name;
  final classId = (m['memberClassId'] as num?)?.toInt();
  if (classId == null) return label;
  final section = readString(m['memberSection']);
  final className = names.classLabel(classId, null);
  return '$label\n$className${section.isEmpty ? '' : ' ($section)'}';
});
LibraryReportCol _month() => LibraryReportCol('Month', (m, _) {
  final parts = readString(m['month']).split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  return date.toDisplayDate().substring(3);
});

final _memberCols = [
  _member(),
  _text('Admission No.', 'admissionNumber'),
  _count('Issued', 'issued'),
  _count('Returned', 'returned'),
  _count('Still out', 'active'),
  _count('Overdue', 'overdue'),
];

/// The library reports.
final libraryReports = <LibraryReportDef>[
  LibraryReportDef(
    'dateRange',
    'Issues by date range',
    'Every book issued between two dates',
    LibraryReportKind.loans,
    [
      _member(),
      _text('Admission No.', 'admissionNumber'),
      LibraryReportCol(
        'Title',
        (data, names) => names.title(data['catalogueId']),
      ),
      LibraryReportCol('Library', (m, names) => names.library(m['libraryId'])),
      _day('Issued', 'issuedDate'),
      _day('Due', 'dueDate'),
      _day('Returned', 'returnedDate'),
      _text('Status', 'status'),
    ],
    statuses: ['active', 'returned', 'lost'],
  ),
  LibraryReportDef(
    'monthly',
    'Monthly issue & return',
    'Books issued and returned each month',
    LibraryReportKind.monthly,
    [_month(), _count('Issued', 'issued'), _count('Returned', 'returned')],
  ),
  LibraryReportDef(
    'student',
    'Student-wise',
    'Books borrowed by each student',
    LibraryReportKind.student,
    _memberCols,
  ),
  LibraryReportDef(
    'staff',
    'Staff-wise',
    'Books borrowed by each staff member',
    LibraryReportKind.staff,
    _memberCols,
  ),
];

/// Dashboard tiles (FRS 11.1): key and label.
const libraryDashboardStats = <(String, String)>[
  ('titles', 'Books'),
  ('copies', 'Physical copies'),
  ('available', 'Available copies'),
  ('issued', 'Issued copies'),
  ('overdue', 'Overdue books'),
  ('lost', 'Lost books'),
  ('damaged', 'Damaged books'),
  ('students', 'Student borrowers'),
  ('teachers', 'Teacher borrowers'),
  ('pending', 'Pending returns'),
  ('fines', 'Outstanding fines'),
];
