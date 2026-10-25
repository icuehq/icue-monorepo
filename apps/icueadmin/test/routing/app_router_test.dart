import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/routing/app_router.dart';
import 'package:icueadmin/routing/app_routes.dart';

void main() {
  group('handleAuthRedirect pure logic', () {
    test('redirects unauthenticated to login', () {
      expect(
        handleAuthRedirect(
          isAuthenticated: false,
          needsBranchSelection: false,
          matchedLocation: AppRoutes.dashboard,
        ),
        AppRoutes.login,
      );
      expect(
        handleAuthRedirect(
          isAuthenticated: false,
          needsBranchSelection: false,
          matchedLocation: AppRoutes.branches,
        ),
        AppRoutes.login,
      );
      expect(
        handleAuthRedirect(
          isAuthenticated: false,
          needsBranchSelection: false,
          matchedLocation: AppRoutes.login,
        ),
        isNull,
      );
    });

    test('redirects zonal admin needing branch selection to branches', () {
      expect(
        handleAuthRedirect(
          isAuthenticated: true,
          needsBranchSelection: true,
          matchedLocation: AppRoutes.dashboard,
        ),
        AppRoutes.branches,
      );
      expect(
        handleAuthRedirect(
          isAuthenticated: true,
          needsBranchSelection: true,
          matchedLocation: AppRoutes.login,
        ),
        AppRoutes.branches,
      );
      expect(
        handleAuthRedirect(
          isAuthenticated: true,
          needsBranchSelection: true,
          matchedLocation: AppRoutes.branches,
        ),
        isNull,
      );
    });

    test('redirects authenticated user on login to dashboard', () {
      expect(
        handleAuthRedirect(
          isAuthenticated: true,
          needsBranchSelection: false,
          matchedLocation: AppRoutes.login,
        ),
        AppRoutes.dashboard,
      );
      expect(
        handleAuthRedirect(
          isAuthenticated: true,
          needsBranchSelection: false,
          matchedLocation: AppRoutes.dashboard,
        ),
        isNull,
      );
      expect(
        handleAuthRedirect(
          isAuthenticated: true,
          needsBranchSelection: false,
          matchedLocation: AppRoutes.branches,
        ),
        isNull,
      );
    });
  });
}
