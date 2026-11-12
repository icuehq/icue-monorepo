import 'package:flutter/material.dart' show DateTimeRange;
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/src/models/library_loans.g.dart';

export 'library_loans.g.dart';

extension LibraryLoanMembers on LibraryLoan {
  bool get isActive => status == 'active';
  bool get canRenew => isActive && renewals < maxRenewals;
  String get memberLabel =>
      memberName ??
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';

  /// Book title, or the copy barcode when the title is missing.
  String get bookLabel => bookTitle ?? barcode;

  /// Days past due as of [today] (`yyyy-MM-dd`); 0 when not overdue.
  int overdueOn(String today) {
    if (!isActive || dueDate.compareTo(today) >= 0) return 0;
    return DateTime.parse('${today}T00:00:00Z')
        .difference(DateTime.parse('${dueDate}T00:00:00Z'))
        .inDays;
  }

  /// Fine the return will raise as of [today] (`LoanWrites.returnLoan`): per day or flat after the grace days, capped.
  double fineOn(String today) {
    final days = overdueOn(today);
    if (days <= graceDays) return 0;
    var amount = switch (fineType) {
      'per_day' => (days - graceDays) * fineAmount,
      'flat' => fineAmount,
      _ => 0.0,
    };
    final cap = maxFine;
    if (cap != null && cap > 0 && amount > cap) amount = cap;
    return amount;
  }
}

/// Date range presets shared by library reports and the Issued Books period filter.
enum LibraryDatePreset {
  all('All'),
  currentMonth('Current Month'),
  lastMonth('Last Month'),
  last6Months('Last 6 Months'),
  last12Months('Last 12 Months'),
  custom('Custom Date Range');

  const LibraryDatePreset(this.label);
  final String label;
}

/// Computes the [DateTimeRange] for a given [LibraryDatePreset].
DateTimeRange calculateRangeForPreset(
  LibraryDatePreset preset, {
  DateTimeRange? customRange,
}) {
  final today = DateTime.now().dateOnly;
  switch (preset) {
    case LibraryDatePreset.all:
      return DateTimeRange(start: DateTime(2000), end: today);
    case LibraryDatePreset.currentMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      );
    case LibraryDatePreset.lastMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month, 0),
      );
    case LibraryDatePreset.last6Months:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 5),
        end: today,
      );
    case LibraryDatePreset.last12Months:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 11),
        end: today,
      );
    case LibraryDatePreset.custom:
      return customRange ??
          DateTimeRange(start: DateTime(today.year, today.month), end: today);
  }
}

/// Due-date filter of the Issued Books list.
enum LoanDueFilter {
  overdue('Overdue'),
  dueToday('Due today');

  const LoanDueFilter(this.label);
  final String label;
}
