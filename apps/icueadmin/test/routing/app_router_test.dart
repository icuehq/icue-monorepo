import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/features/dashboard/dashboard_page.dart';
import 'package:icueadmin/routing/app_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:school_library/school_library.dart';

void main() {
  group('handleAuthRedirect pure logic', () {
    test('librarian is sent to the library from login and dashboard', () {
      for (final from in [AppRoutes.login, AppRoutes.dashboard]) {
        expect(
          handleAuthRedirect(
            isAuthenticated: true,
            needsBranchSelection: false,
            isLibrarian: true,
            matchedLocation: from,
          ),
          LibraryRoutes.library,
        );
      }
    });

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

  group('AppRoutes canonical route definitions', () {
    test('module paths are kebab-case without backend layout ids', () {
      expect(AppRoutes.drivers, '/drivers');
      expect(AppRoutes.postAnnouncement, '/announcements');
      expect(AppRoutes.announcements, '/announcements/history');
      expect(AppRoutes.manageExpense, '/fuel-filling');
      expect(AppRoutes.repairsExpense, '/repairs-expenses');
      expect(AppRoutes.trackBus, '/track-vehicle');
      expect(AppRoutes.gatePass, '/gate-pass');
      expect(InventoryRoutes.inventory, '/inventory');
      expect(LibraryRoutes.library, '/library');
    });

    test('sub-routes nest under their module with dotted names', () {
      expect(AppRoutes.addDriver, '/drivers/add');
      expect(AppRoutes.addDriverName, 'drivers.add');
      expect(AppRoutes.addComplaint, '/logbook/complaints/add');
      expect(AppRoutes.addComplaintName, 'logbook.complaints.add');
      expect(AppRoutes.arrivalTimeReport, '/reports/vehicle-arrival');
      expect(AppRoutes.pendingGatePass, '/gate-pass/pending');
      expect(LibraryRoutes.libraryBookImportName, 'library.catalogue.import');
    });

    test('every dashboard backend id maps to a layout-free path', () {
      expect(dashboardRoutePaths, hasLength(15));
      for (final path in dashboardRoutePaths.values) {
        expect(path, startsWith('/'));
        expect(path, isNot(contains('layout')));
      }
    });
  });
}
