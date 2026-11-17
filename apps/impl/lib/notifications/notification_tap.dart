import 'package:announcements/announcements.dart';
import 'package:parent_transport/parent_transport.dart';

/// Where a tapped push notification should go.
class NotificationTap {
  const NotificationTap({required this.studentId, required this.path});

  final int studentId;
  final String path;
}

/// Reads a push payload (`StudentId`, `action`). Null when it names no student.
/// `Track` opens bus tracking and `Announcement` the announcements; anything
/// else opens home.
NotificationTap? parseNotificationTap(Map<String, dynamic> data) {
  final studentId = int.tryParse('${data['StudentId']}');
  if (studentId == null) return null;
  final path = switch ('${data['action']}') {
    'Track' => TransportRoutes.trackBusPath,
    'Announcement' => AnnouncementsRoutes.parentAnnouncementsPath,
    _ => '/',
  };
  return NotificationTap(studentId: studentId, path: path);
}
