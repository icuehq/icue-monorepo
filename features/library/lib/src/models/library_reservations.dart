import 'package:school_library/src/models/library_reservations.g.dart';

export 'library_reservations.g.dart';

String reservationStatusLabel(String value) => switch (value) {
  'waiting' => 'Waiting in queue',
  'ready' => 'Ready for collection',
  'fulfilled' => 'Fulfilled',
  'cancelled' => 'Cancelled',
  'expired' => 'Expired',
  _ => value,
};

extension LibraryReservationMembers on LibraryReservation {
  bool get isWaiting => status == 'waiting';
  bool get isReady => status == 'ready';
  bool get isLive => isWaiting || isReady;
  String get memberLabel =>
      '${memberType == 'student' ? 'Student' : 'Teacher'} #$personErpId';
}
