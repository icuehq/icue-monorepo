import 'package:flutter_test/flutter_test.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibraryReservation parses a document and determines status', () {
    final reservation = LibraryReservation.fromMap('r1', {
      'number': 'RSV-000001',
      'memberId': 'student_501',
      'memberType': 'student',
      'personErpId': 501,
      'catalogueId': 'b1',
      'title': 'Test Book',
      'libraryId': 'lib1',
      'campusId': 10,
      'status': 'ready',
      'heldBarcode': 'ACC-000001',
      'holdUntil': dayTimestamp('2026-11-04'),
    });
    expect(reservation.memberLabel, 'Student #501');
    expect(reservation.isReady, isTrue);
    expect(reservation.isWaiting, isFalse);
    expect(reservation.isLive, isTrue);
    expect(reservationStatusLabel(reservation.status), 'Ready for collection');
  });
}
