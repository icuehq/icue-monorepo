import 'package:flutter_test/flutter_test.dart';
import 'package:impl/notifications/notification_tap.dart';

void main() {
  test('routes Track, Announcement and unknown actions', () {
    expect(
      parseNotificationTap({'StudentId': '12', 'action': 'Track'})?.path,
      '/layout.trackbus',
    );
    expect(
      parseNotificationTap({'StudentId': 12, 'action': 'Announcement'})?.path,
      '/layout.announcements',
    );
    expect(parseNotificationTap({'StudentId': '12'})?.path, '/');
    expect(parseNotificationTap({'StudentId': '12'})?.studentId, 12);
  });

  test('ignores payloads without a student', () {
    expect(parseNotificationTap({'action': 'Track'}), isNull);
    expect(parseNotificationTap({'StudentId': 'abc'}), isNull);
  });
}
