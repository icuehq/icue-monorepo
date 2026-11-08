import 'package:school_library/src/models/library_loans.g.dart';

export 'library_loans.g.dart';

extension LibraryLoanMembers on LibraryLoan {
  bool get isActive => status == 'active';
  bool get canRenew => isActive && renewals < maxRenewals;
  String get memberLabel =>
      memberName ??
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';

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
