import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/auth/login_page.dart';
import 'package:icueadmin/features/branches/branches_page.dart';
import 'package:icueadmin/features/dashboard/dashboard_page.dart';
import 'package:icueadmin/routing/app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Pure redirect logic used by [GoRouter] and unit tests.
String? handleAuthRedirect({
  required bool isAuthenticated,
  required bool needsBranchSelection,
  required String matchedLocation,
}) {
  final isLoginRoute = matchedLocation == AppRoutes.login;
  final isBranchesRoute = matchedLocation == AppRoutes.branches;

  // 1. Unauthenticated users must be on /login
  if (!isAuthenticated) {
    return isLoginRoute ? null : AppRoutes.login;
  }

  // 2. Authenticated zonal admins who must select a branch first
  if (needsBranchSelection) {
    return isBranchesRoute ? null : AppRoutes.branches;
  }

  // 3. Authenticated users should not stay on the login screen
  if (isLoginRoute) {
    return AppRoutes.dashboard;
  }

  return null;
}

GoRouter createRouter({
  required AuthProvider authProvider,
  ApiEnvironment? environment,
  String initialLocation = AppRoutes.dashboard,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return GoRouter(
    navigatorKey: navigatorKey ?? rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: authProvider,
    redirect: (context, state) => handleAuthRedirect(
      isAuthenticated: authProvider.isAuthenticated,
      needsBranchSelection: authProvider.needsBranchSelection,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRoutes.dashboardName,
        builder: (context, state) => DashboardPage(environment: environment),
      ),
      GoRoute(
        path: AppRoutes.branches,
        name: AppRoutes.branchesName,
        builder: (context, state) => const BranchesPage(),
      ),
    ],
  );
}
