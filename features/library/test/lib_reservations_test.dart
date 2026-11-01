import 'package:flutter_test/flutter_test.dart';
import 'package:school_library/school_library.dart';

void main() {
  test('LibReservation parses a document and determines status', () {
    final r = LibReservation.fromMap('r1', {
      'number': 'RSV-000001',
      'memberId': 'student_501',
      'memberType': 'student',
      'personErpId': 501,
      'catalogueId': 'b1',
      'title': 'Test Book',
      'libraryId': 'lib1',
      'campusId': 10,
      'status': 'ready',
      'heldCopyId': 'ACC-000001',
      'holdUntil': '2026-11-04',
    });
    expect(r.memberLabel, 'Student #501');
    expect(r.isReady, isTrue);
    expect(r.isWaiting, isFalse);
    expect(r.isLive, isTrue);
    expect(reservationStatusLabel(r.status), 'Ready for collection');
  });
}
