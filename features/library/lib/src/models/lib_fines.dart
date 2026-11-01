import 'package:icue_firebase/icue_firebase.dart';

String fineStatusLabel(String s) => switch (s) {
  'outstanding' => 'Outstanding',
  'partially_paid' => 'Partially paid',
  'paid' => 'Paid',
  'waived' => 'Waived',
  _ => s,
};

String fineTypeLabel(String t) => switch (t) {
  'overdue' => 'Overdue',
  'lost' => 'Lost book',
  'damaged' => 'Damaged book',
  _ => t,
};

class LibFineWaival {
  const LibFineWaival({
    required this.amount,
    required this.reason,
    required this.by,
    required this.at,
  });

  factory LibFineWaival.fromMap(Map<String, dynamic> m) => LibFineWaival(
    amount: (m['amount'] as num? ?? 0).toDouble(),
    reason: m['reason'] as String? ?? '',
    by: m['by'] as String? ?? '',
    at: m['at'] as String? ?? '',
  );

  final double amount;
  final String reason;
  final String by;
  final String at;
}

class LibFinePayment {
  const LibFinePayment({
    required this.amount,
    this.reference,
    this.date,
    this.by,
  });

  factory LibFinePayment.fromMap(Map<String, dynamic> m) => LibFinePayment(
    amount: (m['amount'] as num? ?? 0).toDouble(),
    reference: m['reference'] as String?,
    date: m['date'] as String?,
    by: m['by'] as String?,
  );

  final double amount;
  final String? reference;
  final String? date;
  final String? by;
}

/// A library fine (overdue, lost book replacement, damaged penalty).
class LibFine {
  const LibFine({
    required this.id,
    required this.fineNumber,
    required this.memberId,
    required this.memberType,
    required this.personErpId,
    required this.libraryId,
    required this.campusId,
    required this.type,
    required this.amount,
    required this.waived,
    required this.paid,
    required this.outstanding,
    required this.status,
    this.loanId,
    this.incidentId,
    this.accessionNo,
    this.catalogueId,
    this.calc,
    this.waivals = const [],
    this.payments = const [],
    this.createdAt,
  });

  factory LibFine.fromMap(String id, Map<String, dynamic> m) => LibFine(
    id: id,
    fineNumber: m['fineNumber'] as String? ?? id,
    memberId: m['memberId'] as String? ?? '',
    memberType: m['memberType'] as String? ?? 'student',
    personErpId: (m['personErpId'] as num? ?? 0).toInt(),
    libraryId: m['libraryId'] as String? ?? '',
    campusId: (m['campusId'] as num? ?? 0).toInt(),
    type: m['type'] as String? ?? 'overdue',
    amount: (m['amount'] as num? ?? 0).toDouble(),
    waived: (m['waived'] as num? ?? 0).toDouble(),
    paid: (m['paid'] as num? ?? 0).toDouble(),
    outstanding: (m['outstanding'] as num? ?? 0).toDouble(),
    status: m['status'] as String? ?? 'outstanding',
    loanId: m['loanId'] as String?,
    incidentId: m['incidentId'] as String?,
    accessionNo: m['accessionNo'] as String?,
    catalogueId: m['catalogueId'] as String?,
    calc: m['calc'] is Map ? Map<String, dynamic>.from(m['calc'] as Map) : null,
    waivals: [
      for (final w in (m['waivals'] as List? ?? []))
        if (w is Map) LibFineWaival.fromMap(Map<String, dynamic>.from(w)),
    ],
    payments: [
      for (final p in (m['payments'] as List? ?? []))
        if (p is Map) LibFinePayment.fromMap(Map<String, dynamic>.from(p)),
    ],
    createdAt: m['createdAt'] is Timestamp
        ? (m['createdAt'] as Timestamp).toDate()
        : null,
  );

  final String id;
  final String fineNumber;
  final String memberId;
  final String memberType;
  final int personErpId;
  final String libraryId;
  final int campusId;
  final String type;
  final double amount;
  final double waived;
  final double paid;
  final double outstanding;
  final String status;
  final String? loanId;
  final String? incidentId;
  final String? accessionNo;
  final String? catalogueId;
  final Map<String, dynamic>? calc;
  final List<LibFineWaival> waivals;
  final List<LibFinePayment> payments;
  final DateTime? createdAt;

  bool get isOutstanding =>
      outstanding > 0 && status != 'waived' && status != 'paid';
  String get memberLabel =>
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';
}
