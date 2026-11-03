import 'package:icue_firebase/icue_firebase.dart';

String fineTypeLabel(String value) => switch (value) {
  'overdue' => 'Overdue',
  'lost' => 'Lost book',
  'damaged' => 'Damaged book',
  _ => value,
};

class LibraryFineWaiver {
  const LibraryFineWaiver({
    required this.amount,
    required this.reason,
    required this.performedBy,
    required this.performedAt,
  });

  factory LibraryFineWaiver.fromMap(Map<String, dynamic> data) =>
      LibraryFineWaiver(
        amount: (data['amount'] as num? ?? 0).toDouble(),
        reason: data['reason'] as String? ?? '',
        performedBy: data['performedBy'] as String? ?? '',
        performedAt: data['performedAt'] as String? ?? '',
      );

  final double amount;
  final String reason;
  final String performedBy;
  final String performedAt;
}

class LibraryFinePayment {
  const LibraryFinePayment({
    required this.amount,
    this.reference,
    this.date,
    this.performedBy,
  });

  factory LibraryFinePayment.fromMap(Map<String, dynamic> data) =>
      LibraryFinePayment(
        amount: (data['amount'] as num? ?? 0).toDouble(),
        reference: data['reference'] as String?,
        date: data['date'] as String?,
        performedBy: data['performedBy'] as String?,
      );

  final double amount;
  final String? reference;
  final String? date;
  final String? performedBy;
}

/// A library fine (overdue, lost book replacement, damaged penalty).
class LibraryFine {
  const LibraryFine({
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
    this.accessionNumber,
    this.catalogueId,
    this.fineCalculation,
    this.waivers = const [],
    this.payments = const [],
    this.createdAt,
  });

  factory LibraryFine.fromMap(String id, Map<String, dynamic> data) =>
      LibraryFine(
        id: id,
        fineNumber: data['fineNumber'] as String? ?? id,
        memberId: data['memberId'] as String? ?? '',
        memberType: data['memberType'] as String? ?? 'student',
        personErpId: (data['personErpId'] as num? ?? 0).toInt(),
        libraryId: data['libraryId'] as String? ?? '',
        campusId: (data['campusId'] as num? ?? 0).toInt(),
        type: data['type'] as String? ?? 'overdue',
        amount: (data['amount'] as num? ?? 0).toDouble(),
        waived: (data['waived'] as num? ?? 0).toDouble(),
        paid: (data['paid'] as num? ?? 0).toDouble(),
        outstanding: (data['outstanding'] as num? ?? 0).toDouble(),
        status: data['status'] as String? ?? 'outstanding',
        loanId: data['loanId'] as String?,
        incidentId: data['incidentId'] as String?,
        accessionNumber: data['accessionNumber'] as String?,
        catalogueId: data['catalogueId'] as String?,
        fineCalculation: data['fineCalculation'] is Map
            ? Map<String, dynamic>.from(data['fineCalculation'] as Map)
            : null,
        waivers: [
          for (final value in (data['waivers'] as List? ?? []))
            if (value is Map)
              LibraryFineWaiver.fromMap(Map<String, dynamic>.from(value)),
        ],
        payments: [
          for (final value in (data['payments'] as List? ?? []))
            if (value is Map)
              LibraryFinePayment.fromMap(Map<String, dynamic>.from(value)),
        ],
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
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
  final String? accessionNumber;
  final String? catalogueId;
  final Map<String, dynamic>? fineCalculation;
  final List<LibraryFineWaiver> waivers;
  final List<LibraryFinePayment> payments;
  final DateTime? createdAt;

  bool get isOutstanding =>
      outstanding > 0 && status != 'waived' && status != 'paid';
  String get memberLabel =>
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';
}
