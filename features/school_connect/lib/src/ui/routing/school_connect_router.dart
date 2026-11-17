import 'package:go_router/go_router.dart';
import 'package:school_connect/src/ui/complaints_page.dart';
import 'package:school_connect/src/ui/event_payment_history_page.dart';
import 'package:school_connect/src/ui/events_page.dart';
import 'package:school_connect/src/ui/post_complaint_page.dart';
import 'package:school_connect/src/ui/request_for_entry_page.dart';

class SchoolConnectRoutes {
  const SchoolConnectRoutes._();

  /// Hub route (a menu of the sub-actions the server enables), child of `/`.
  static const String hub = 'layout.schoolconnect';
  static const String hubPath = '/layout.schoolconnect';

  /// Children of [hub].
  static const String requestForEntry = 'layout.requestforentry';
  static const String events = 'Layout.events';
  static const String paymentHistory = 'events-payment-history';
  static const String paymentHistoryPath =
      '/layout.schoolconnect/Layout.events/events-payment-history';

  /// Children of `/`.
  static const String postComplaint = 'layout.complaints';
  static const String complaints = 'complaints';
  static const String complaintsPath = '/complaints';
}

/// Mount as children of the School Connect hub route.
List<RouteBase> schoolConnectHubRoutes() => [
  GoRoute(
    name: 'request-for-entry-page',
    path: SchoolConnectRoutes.requestForEntry,
    builder: (_, _) => const RequestForEntryPage(),
  ),
  GoRoute(
    name: 'events-page',
    path: SchoolConnectRoutes.events,
    builder: (_, _) => const EventsPage(),
    routes: [
      GoRoute(
        name: 'events-payment-history',
        path: SchoolConnectRoutes.paymentHistory,
        builder: (_, _) => const EventPaymentHistoryPage(),
      ),
    ],
  ),
];

/// Mount as children of the dashboard route.
List<RouteBase> complaintRoutes() => [
  GoRoute(
    name: 'post-complaint-page',
    path: SchoolConnectRoutes.postComplaint,
    builder: (_, _) => const PostComplaintPage(),
  ),
  GoRoute(
    name: 'complaints-page',
    path: SchoolConnectRoutes.complaints,
    builder: (_, _) => const ComplaintsPage(),
  ),
];
