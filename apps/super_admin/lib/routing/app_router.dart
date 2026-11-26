import 'package:auth/auth.dart';
import 'package:face_enrollment/face_enrollment.dart';
import 'package:go_router/go_router.dart';
import 'package:super_admin/login_screen.dart';

const _loginPath = '/login';

GoRouter createRouter(AuthProvider authProvider) => GoRouter(
  initialLocation: FaceEnrollmentRoutes.students,
  refreshListenable: authProvider,
  redirect: (context, state) {
    final signedIn = authProvider.user != null;
    final atLogin = state.matchedLocation == _loginPath;
    if (!signedIn) return atLogin ? null : _loginPath;
    return atLogin ? FaceEnrollmentRoutes.students : null;
  },
  routes: [
    GoRoute(path: _loginPath, builder: (_, _) => const LoginScreen()),
    ...faceEnrollmentRoutes(),
  ],
);
