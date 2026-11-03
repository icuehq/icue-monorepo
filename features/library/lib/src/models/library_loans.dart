import 'package:school_library/src/models/library_loans.g.dart';

export 'library_loans.g.dart';

extension LibraryLoanMembers on LibraryLoan {
  bool get isActive => status == 'active';
  bool get canRenew => isActive && renewals < maxRenewals;
  String get memberLabel =>
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';

  /// Days past due as of [today] (`yyyy-MM-dd`); 0 when not overdue.
  int overdueOn(String today) {
    if (!isActive || dueDate.compareTo(today) >= 0) return 0;
    return DateTime.parse(today).difference(DateTime.parse(dueDate)).inDays;
  }
}
