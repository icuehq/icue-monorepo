/// One issue of a copy to a member (FRS 11.9–11.11). Policy values are frozen on the loan at issue.
class LibLoan {
  const LibLoan({
    required this.id,
    required this.number,
    required this.memberId,
    required this.memberType,
    required this.personErpId,
    required this.copyId,
    required this.accessionNo,
    required this.catalogueId,
    required this.libraryId,
    required this.issuedOn,
    required this.dueOn,
    required this.renewals,
    required this.maxRenewals,
    required this.status,
    this.returnedOn,
    this.condition,
    this.overdueDays,
  });

  factory LibLoan.fromMap(String id, Map<String, dynamic> m) => LibLoan(
    id: id,
    number: m['number'] as String? ?? '',
    memberId: m['memberId'] as String? ?? '',
    memberType: m['memberType'] as String? ?? 'student',
    personErpId: (m['personErpId'] as num? ?? 0).toInt(),
    copyId: m['copyId'] as String? ?? '',
    accessionNo: m['accessionNo'] as String? ?? '',
    catalogueId: m['catalogueId'] as String? ?? '',
    libraryId: m['libraryId'] as String? ?? '',
    issuedOn: m['issuedOn'] as String? ?? '',
    dueOn: m['dueOn'] as String? ?? '',
    renewals: (m['renewals'] as List?)?.length ?? 0,
    maxRenewals: ((m['policySnapshot'] as Map?)?['maxRenewals'] as num? ?? 0)
        .toInt(),
    status: m['status'] as String? ?? 'active',
    returnedOn: m['returnedOn'] as String?,
    condition: m['condition'] as String?,
    overdueDays: (m['overdueDays'] as num?)?.toInt(),
  );

  final String id;
  final String number;
  final String memberId;
  final String memberType;
  final int personErpId;
  final String copyId;
  final String accessionNo;
  final String catalogueId;
  final String libraryId;
  final String issuedOn;
  final String dueOn;
  final int renewals;
  final int maxRenewals;
  final String status;
  final String? returnedOn;
  final String? condition;
  final int? overdueDays;

  bool get isActive => status == 'active';
  bool get canRenew => isActive && renewals < maxRenewals;
  String get memberLabel =>
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';

  /// Days past due as of [today] (`yyyy-MM-dd`); 0 when not overdue.
  int overdueOn(String today) {
    if (!isActive || dueOn.compareTo(today) >= 0) return 0;
    return DateTime.parse(today).difference(DateTime.parse(dueOn)).inDays;
  }
}
