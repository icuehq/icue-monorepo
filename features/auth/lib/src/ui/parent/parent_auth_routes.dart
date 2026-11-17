import 'package:auth/src/ui/parent/parent_login_page.dart';
import 'package:auth/src/ui/parent/parent_otp_page.dart';
import 'package:go_router/go_router.dart';

class ParentAuthRoutes {
  const ParentAuthRoutes._();

  static const String login = '/login';
  static const String otp = '/otp';
}

/// Parent login routes; the OTP page receives the mobile number as `extra`.
List<RouteBase> parentAuthRoutes() => [
  GoRoute(
    name: 'login-page',
    path: ParentAuthRoutes.login,
    builder: (_, _) => const ParentLoginPage(),
  ),
  GoRoute(
    name: 'otp-page',
    path: ParentAuthRoutes.otp,
    builder: (_, state) =>
        ParentOtpPage(mobile: (state.extra as String?) ?? ''),
  ),
];
