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

/// Issue-date window of the Issued Books list; each runs from [from] to today.
enum LoanIssuedWindow {
  today('Today'),
  week('Last 7 days'),
  month('Last 30 days'),
  thisMonth('This month');

  const LoanIssuedWindow(this.label);
  final String label;

  /// First issue day (`yyyy-MM-dd`) of the window ending on [todayDate].
  String from(String todayDate) {
    String daysBefore(int days) =>
        DateTime.parse('${todayDate}T00:00:00Z')
            .subtract(Duration(days: days))
            .toApiDate();
    return switch (this) {
      LoanIssuedWindow.today => todayDate,
      LoanIssuedWindow.week => daysBefore(6),
      LoanIssuedWindow.month => daysBefore(29),
      LoanIssuedWindow.thisMonth => '${todayDate.substring(0, 7)}-01',
    };
  }
}

/// Due-date filter of the Issued Books list.
enum LoanDueFilter {
  overdue('Overdue'),
  dueToday('Due today');

  const LoanDueFilter(this.label);
  final String label;
}
