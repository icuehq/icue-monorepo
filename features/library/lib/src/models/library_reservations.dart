import 'package:icue_firebase/icue_firebase.dart';

String reservationStatusLabel(String value) => switch (value) {
  'waiting' => 'Waiting in queue',
  'ready' => 'Ready for collection',
  'fulfilled' => 'Fulfilled',
  'cancelled' => 'Cancelled',
  'expired' => 'Expired',
  _ => value,
};

/// A book reservation placed by a member (FRS 11.12).
class LibraryReservation {
  const LibraryReservation({
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

  factory LibraryReservation.fromMap(String id, Map<String, dynamic> data) =>
      LibraryReservation(
        id: id,
        number: data['number'] as String? ?? '',
        memberId: data['memberId'] as String? ?? '',
        memberType: data['memberType'] as String? ?? 'student',
        personErpId: (data['personErpId'] as num? ?? 0).toInt(),
        catalogueId: data['catalogueId'] as String? ?? '',
        title: data['title'] as String? ?? '',
        libraryId: data['libraryId'] as String? ?? '',
        campusId: (data['campusId'] as num? ?? 0).toInt(),
        status: data['status'] as String? ?? 'waiting',
        heldCopyId: data['heldCopyId'] as String?,
        holdUntil: data['holdUntil'] as String?,
        fulfilledLoanId: data['fulfilledLoanId'] as String?,
        fulfilledCopyId: data['fulfilledCopyId'] as String?,
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
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
