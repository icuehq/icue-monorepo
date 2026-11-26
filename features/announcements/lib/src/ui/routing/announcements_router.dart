import 'package:announcements/src/ui/parent_announcements_page.dart';
import 'package:go_router/go_router.dart';

class AnnouncementsRoutes {
  const AnnouncementsRoutes._();

  /// Child of the app's `/` route; full path `/layout.announcements`.
  static const String parentAnnouncements = 'layout.announcements';
  static const String parentAnnouncementsPath = '/layout.announcements';
}

/// Parent routes; mount as children of the dashboard route.
List<RouteBase> parentAnnouncementsRoutes() => [
  GoRoute(
    name: 'announcements-page',
    path: AnnouncementsRoutes.parentAnnouncements,
    builder: (_, _) => const ParentAnnouncementsPage(),
  ),
];
