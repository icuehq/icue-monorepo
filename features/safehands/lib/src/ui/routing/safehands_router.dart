import 'package:go_router/go_router.dart';
import 'package:safehands/src/ui/add_escort_page.dart';
import 'package:safehands/src/ui/escort_page.dart';
import 'package:safehands/src/ui/safehands_page.dart';

/// Paths keep the old app's spelling (capital S) because menu actions send them.
class SafeHandsRoutes {
  const SafeHandsRoutes._();

  /// Child of the app's `/` route.
  static const String safeHands = 'layout.Safehands';
  static const String escort = 'escort';
  static const String addEscort = 'add-escort';
  static const String escortPath = '/layout.Safehands/escort';
  static const String addEscortPath = '/layout.Safehands/escort/add-escort';
}

/// Mount as children of the dashboard route.
List<RouteBase> safeHandsRoutes() => [
  GoRoute(
    name: 'safe-hands-page',
    path: SafeHandsRoutes.safeHands,
    builder: (_, _) => const SafeHandsPage(),
    routes: [
      GoRoute(
        name: 'escort-page',
        path: SafeHandsRoutes.escort,
        builder: (_, _) => const EscortPage(),
        routes: [
          GoRoute(
            name: 'add-escort-page',
            path: SafeHandsRoutes.addEscort,
            builder: (_, _) => const AddEscortPage(),
          ),
        ],
      ),
    ],
  ),
];
