import 'package:icue_firebase/icue_firebase.dart';

String reservationStatusLabel(String s) => switch (s) {
  'waiting' => 'Waiting in queue',
  'ready' => 'Ready for collection',
  'fulfilled' => 'Fulfilled',
  'cancelled' => 'Cancelled',
  'expired' => 'Expired',
  _ => s,
};

/// A book reservation placed by a member (FRS 11.12).
class LibReservation {
  const LibReservation({
    required this.id,
    required this.number,
    required this.memberId,
    required this.memberType,
    required this.personErpId,
    required this.catalogueId,
    required this.title,
    required this.libraryId,
    required this.campusId,
    required this.status,
    this.heldCopyId,
    this.holdUntil,
    this.fulfilledLoanId,
    this.fulfilledCopyId,
    this.createdAt,
  });

  factory LibReservation.fromMap(String id, Map<String, dynamic> m) =>
      LibReservation(
        id: id,
        number: m['number'] as String? ?? '',
        memberId: m['memberId'] as String? ?? '',
        memberType: m['memberType'] as String? ?? 'student',
        personErpId: (m['personErpId'] as num? ?? 0).toInt(),
        catalogueId: m['catalogueId'] as String? ?? '',
        title: m['title'] as String? ?? '',
        libraryId: m['libraryId'] as String? ?? '',
        campusId: (m['campusId'] as num? ?? 0).toInt(),
        status: m['status'] as String? ?? 'waiting',
        heldCopyId: m['heldCopyId'] as String?,
        holdUntil: m['holdUntil'] as String?,
        fulfilledLoanId: m['fulfilledLoanId'] as String?,
        fulfilledCopyId: m['fulfilledCopyId'] as String?,
        createdAt: m['createdAt'] is Timestamp
            ? (m['createdAt'] as Timestamp).toDate()
            : null,
      );

  final String id;
  final String number;
  final String memberId;
  final String memberType;
  final int personErpId;
  final String catalogueId;
  final String title;
  final String libraryId;
  final int campusId;
  final String status;
  final String? heldCopyId;
  final String? holdUntil;
  final String? fulfilledLoanId;
  final String? fulfilledCopyId;
  final DateTime? createdAt;

  bool get isWaiting => status == 'waiting';
  bool get isReady => status == 'ready';
  bool get isLive => isWaiting || isReady;
  String get memberLabel =>
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';
}
