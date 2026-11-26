import 'package:auth/auth.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:portal/home_screen.dart';
import 'package:portal/login_screen.dart';
import 'package:school_library/school_library.dart';

const _loginPath = '/login';
const _homePath = '/';

GoRouter createRouter(AuthProvider authProvider) => GoRouter(
  refreshListenable: authProvider,
  redirect: (context, state) {
    final signedIn = authProvider.user != null;
    final atLogin = state.matchedLocation == _loginPath;
    if (!signedIn) return atLogin ? null : _loginPath;
    return atLogin ? _homePath : null;
  },
  routes: [
    GoRoute(path: _loginPath, builder: (_, _) => const LoginScreen()),
    GoRoute(path: _homePath, builder: (_, _) => const HomeScreen()),
    ...inventoryRoutes(),
    ...libraryRoutes(),
  ],
);
