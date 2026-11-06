import 'package:auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses attendance mode and image limits', () {
    final settings = AppSettings.fromJson(const {
      'AttendCnfg': {'AttendanceMode': 'facial', 'UploadAttendImages': true},
      'VhCnfg': {'ComplaintImageLimit': 3},
    });
    final attendance = settings.attendance!;
    expect(attendance.allowsFacial, isTrue);
    expect(attendance.allowsManual, isFalse);
    expect(attendance.uploadImages, isTrue);
    expect(settings.vehicle!.complaintImageLimit, 3);
    expect(settings.vehicle!.cleaningImageLimit, 1);
  });

  test('missing mode allows everything', () {
    final attendance = AppSettings.fromJson(const {
      'AttendCnfg': <String, dynamic>{},
    }).attendance!;
    expect(attendance.allowsManual && attendance.allowsFacial, isTrue);
    expect(attendance.uploadImages, isFalse);
  });
}
