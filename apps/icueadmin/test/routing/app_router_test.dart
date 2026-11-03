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

  group('AppRoutes canonical route definitions', () {
    test('defines main layout routes', () {
      expect(AppRoutes.trackBus, '/layout.trackvehicle');
      expect(AppRoutes.fleetStatus, '/layout.fleetdashboard');
      expect(AppRoutes.manageRoutes, '/layout.routes');
      expect(AppRoutes.postAnnouncement, '/layout.fleetannouncement');
      expect(
        AppRoutes.announcements,
        '/layout.fleetannouncement/layout.annoucements',
      );
      expect(AppRoutes.drivers, '/layout.drivers');
      expect(AppRoutes.vehicles, '/layout.vehicles');
      expect(AppRoutes.manageExpense, '/layout.fuelfilling');
      expect(AppRoutes.repairsExpense, '/layout.repairsandexpenses');
      expect(AppRoutes.logBook, '/layout.logbook');
      expect(AppRoutes.reports, '/layout.reports');
      expect(AppRoutes.gatePass, '/layout.gatepass');
      expect(AppRoutes.attendance, '/layout.attendance');
      expect(AppRoutes.dropBoarding, '/layout.dropboarding');
    });

    test('defines sub-routes under corresponding layout modules', () {
      expect(AppRoutes.addDriver, '/layout.drivers/add-driver');
      expect(AppRoutes.driverInfo, '/layout.drivers/driver-info');
      expect(AppRoutes.driverDocs, '/layout.drivers/driver-docs');
      expect(AppRoutes.addVehicle, '/layout.vehicles/add-vehicle');
      expect(AppRoutes.vehicleDetails, '/layout.vehicles/vehicle-details');
      expect(
        AppRoutes.studentRouteChange,
        '/layout.routes/student-route-change',
      );
      expect(AppRoutes.routeTimeChange, '/layout.routes/route-time-change');
      expect(
        AppRoutes.complaintsDashboard,
        '/layout.logbook/layout.complaintsdashboard',
      );
      expect(AppRoutes.complaints, '/layout.logbook/layout.complaints');
      expect(
        AppRoutes.addComplaint,
        '/layout.logbook/layout.complaints/add-complaint',
      );
      expect(AppRoutes.cleaningLog, '/layout.logbook/layout.cleaninglog');
      expect(AppRoutes.alcoholTestForm, '/layout.logbook/layout.alcoholtest');
      expect(
        AppRoutes.arrivalTimeReport,
        '/layout.reports/layout.vehiclearrival',
      );
      expect(
        AppRoutes.cleaningReport,
        '/layout.reports/layout.vehiclecleaning',
      );
      expect(
        AppRoutes.alcoholTestReport,
        '/layout.reports/layout.alcoholtestreport',
      );
      expect(
        AppRoutes.generateGatePass,
        '/layout.gatepass/layout.generategatepass',
      );
      expect(
        AppRoutes.pendingGatePass,
        '/layout.gatepass/layout.approvegatepass',
      );
    });
  });
}
