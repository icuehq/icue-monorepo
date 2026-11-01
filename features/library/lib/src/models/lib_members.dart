List<T> _list<T>(Object? v) => v is List ? List<T>.from(v) : <T>[];

const fineTypes = {
  'none': 'No fine',
  'per_day': 'Per day overdue',
  'flat': 'Flat amount',
};

/// Borrowing rules of one member category in one library (FRS 11.8).
class LibPolicy {
  const LibPolicy({
    required this.id,
    required this.name,
    required this.libraryId,
    required this.memberCategory,
    required this.maxBooks,
    required this.loanDays,
    required this.maxRenewals,
    required this.fineType,
    required this.fineAmount,
    required this.graceDays,
    required this.canReserve,
    required this.overdueRenewal,
    required this.restrictedCategoryIds,
    required this.active,
    this.maxFine,
  });

  factory LibPolicy.fromMap(String id, Map<String, dynamic> m) => LibPolicy(
    id: id,
    name: m['name'] as String? ?? '',
    libraryId: m['libraryId'] as String? ?? '',
    memberCategory: m['memberCategory'] as String? ?? '',
    maxBooks: (m['maxBooks'] as num? ?? 0).toInt(),
    loanDays: (m['loanDays'] as num? ?? 0).toInt(),
    maxRenewals: (m['maxRenewals'] as num? ?? 0).toInt(),
    fineType: m['fineType'] as String? ?? 'none',
    fineAmount: (m['fineAmount'] as num? ?? 0).toDouble(),
    graceDays: (m['graceDays'] as num? ?? 0).toInt(),
    maxFine: (m['maxFine'] as num?)?.toDouble(),
    canReserve: m['canReserve'] == true,
    overdueRenewal: m['overdueRenewal'] == true,
    restrictedCategoryIds: _list<String>(m['restrictedCategoryIds']),
    active: m['status'] != 'inactive',
  );

  final String id;
  final String name;
  final String libraryId;
  final String memberCategory;
  final int maxBooks;
  final int loanDays;
  final int maxRenewals;
  final String fineType;
  final double fineAmount;
  final int graceDays;
  final double? maxFine;
  final bool canReserve;
  final bool overdueRenewal;
  final List<String> restrictedCategoryIds;
  final bool active;

  String get summary =>
      '$maxBooks book${maxBooks == 1 ? '' : 's'} · $loanDays days · '
      '$maxRenewals renewal${maxRenewals == 1 ? '' : 's'}';
}

/// A student or teacher who may borrow (FRS 11.7); the ERP person is only referenced by ID.
class LibMember {
  const LibMember({
    required this.id,
    required this.memberType,
    required this.erpId,
    required this.memberCategory,
    required this.libraryIds,
    required this.start,
    required this.activeLoans,
    required this.blocked,
    required this.active,
    this.classId,
    this.end,
  });

  factory LibMember.fromMap(String id, Map<String, dynamic> m) => LibMember(
    id: id,
    memberType: m['memberType'] as String? ?? 'student',
    erpId: (m['erpId'] as num? ?? 0).toInt(),
    classId: (m['classId'] as num?)?.toInt(),
    memberCategory: m['memberCategory'] as String? ?? '',
    libraryIds: _list<String>(m['libraryIds']),
    start: m['start'] as String? ?? '',
    end: m['end'] as String?,
    activeLoans: (m['activeLoans'] as num? ?? 0).toInt(),
    blocked: m['blocked'] == true,
    active: m['status'] != 'inactive',
  );

  final String id;
  final String memberType;
  final int erpId;
  final int? classId;
  final String memberCategory;
  final List<String> libraryIds;
  final String start;
  final String? end;
  final int activeLoans;
  final bool blocked;
  final bool active;

  bool get isStudent => memberType == 'student';
  String get label => '${isStudent ? 'Student' : 'Teacher'} #$erpId';
}
