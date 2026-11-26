import 'package:gatepass/src/ui/gatepass_requests_page.dart';
import 'package:gatepass/src/ui/generate_gatepass_page.dart';
import 'package:go_router/go_router.dart';

class GatePassRoutes {
  const GatePassRoutes._();

  /// Child of the app's `/` route; full path `/layout.gatepass`.
  static const String parentGatePass = 'layout.gatepass';
  static const String requests = 'gatepass-requests';
  static const String requestsPath = '/layout.gatepass/gatepass-requests';
}

/// Parent routes; mount as children of the dashboard route.
List<RouteBase> parentGatePassRoutes() => [
  GoRoute(
    name: 'gatepass-page',
    path: GatePassRoutes.parentGatePass,
    builder: (_, _) => const GenerateGatePassPage(),
    routes: [
      GoRoute(
        name: 'gatepass-requests-page',
        path: GatePassRoutes.requests,
        builder: (_, _) => const GatePassRequestsPage(),
      ),
    ],
  ),
];
