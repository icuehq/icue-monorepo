import 'package:go_router/go_router.dart';
import 'package:parent_transport/src/ui/my_vehicles_page.dart';
import 'package:parent_transport/src/ui/track_bus_page.dart';
import 'package:parent_transport/src/ui/transport_attendance_page.dart';

class TransportRoutes {
  const TransportRoutes._();

  /// Children of the app's `/` route.
  static const String trackBus = 'layout.trackbus';
  static const String trackBusPath = '/layout.trackbus';
  static const String transportAttendance = 'layout.transportattendance';

  /// Child of the app's `/profile` route.
  static const String myVehicles = 'my-vehicles';
  static const String myVehiclesPath = '/profile/my-vehicles';
}

/// Mount as children of the dashboard route.
List<RouteBase> parentTransportRoutes() => [
  GoRoute(
    name: 'track-bus-page',
    path: TransportRoutes.trackBus,
    builder: (_, _) => const TrackBusPage(),
  ),
  GoRoute(
    name: 'transport-attendance-page',
    path: TransportRoutes.transportAttendance,
    builder: (_, _) => const TransportAttendancePage(),
  ),
];

/// Mount as children of the profile route.
List<RouteBase> parentTransportProfileRoutes() => [
  GoRoute(
    name: 'my-vehicles',
    path: TransportRoutes.myVehicles,
    builder: (_, _) => const MyVehiclesPage(),
  ),
];
