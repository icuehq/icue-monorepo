import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/src/models/library_loans.g.dart';

export 'library_loans.g.dart';

/// `05 Mar 2025 · 3 days left` (or `due today` / `N days overdue`) for [dueDate] (`yyyy-MM-dd`) as of [today];
/// the date alone once the loan is closed.
String dueLabel(
  String dueDate, {
  required bool isActive,
  required String today,
  String separator = ' · ',
}) {
  final date = dueDate.toDisplayDay();
  if (!isActive) return date;
  final left = daysBetween(today, dueDate);
  if (left == 0) return '$date${separator}due today';
  final days = left.abs();
  return '$date$separator$days ${days == 1 ? 'day' : 'days'} ${left > 0 ? 'left' : 'overdue'}';
}

extension LibraryLoanMembers on LibraryLoan {
  bool get isActive => status == 'active';
  bool get canRenew => isActive && renewals < maxRenewals;
  String get memberLabel =>
      memberName ??
      '${memberType == 'STUDENT' ? 'Student' : 'Employee'} #$personErpId';

  /// Book title, or the copy barcode when the title is missing.
  String get bookLabel => bookTitle ?? barcode;

  /// Days past due as of [today] (`yyyy-MM-dd`); 0 when not overdue.
  int overdueOn(String today) {
    if (!isActive || dueDate.compareTo(today) >= 0) return 0;
    return daysBetween(dueDate, today);
  }

  /// Due date plus days remaining as of [today]; see [dueLabel].
  String dueLabelOn(String today) =>
      dueLabel(dueDate, isActive: isActive, today: today);

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

/// Due-date filter of the Issued Books list.
enum LoanDueFilter {
  overdue('Overdue'),
  dueToday('Due today');

  const LoanDueFilter(this.label);
  final String label;
}
