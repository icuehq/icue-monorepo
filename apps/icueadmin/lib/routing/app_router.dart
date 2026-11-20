import 'package:api_client/api_client.dart';
import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:drivers/drivers.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/features/auth/login_page.dart';
import 'package:icueadmin/features/branches/branches_page.dart';
import 'package:icueadmin/features/dashboard/dashboard_page.dart';
import 'package:icueadmin/features/expenses/expense_args.dart';
import 'package:icueadmin/routing/admin_pages.dart' deferred as pages;
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/coming_soon_page.dart';
import 'package:inventory/inventory.dart';
import 'package:logbook/logbook.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';
import 'package:vehicles/vehicles.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

Widget _adminPage(WidgetBuilder builder) =>
    IcueDeferred(load: pages.loadLibrary, builder: builder);

/// Redirects to [fallback] when a route that needs `extra` is opened without
/// it (process restore, deep link), instead of crashing on a failed cast.
GoRouterRedirect _requireExtra<T>(String fallback) =>
    (context, state) => state.extra is T ? null : fallback;

GoRouterRedirect _requireMapKeys(String fallback, List<String> keys) =>
    (context, state) {
      final extra = state.extra;
      return extra is Map && keys.every(extra.containsKey) ? null : fallback;
    };

/// Pure redirect logic used by [GoRouter] and unit tests.
String? handleAuthRedirect({
  required bool isAuthenticated,
  required bool needsBranchSelection,
  required String matchedLocation,
  bool isLibrarian = false,
  bool isStoreManager = false,
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

  // 3. Authenticated users should not stay on the login screen; librarians
  // land in the library module and store managers in inventory instead of the dashboard.
  final landing = isLibrarian
      ? LibraryRoutes.library
      : isStoreManager
      ? InventoryRoutes.inventory
      : null;
  if (isLoginRoute ||
      (landing != null && matchedLocation == AppRoutes.dashboard)) {
    return landing ?? AppRoutes.dashboard;
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
    errorBuilder: (context, state) => const ComingSoonPage(),
    observers: [AnalyticsService.instance.observer],
    refreshListenable: authProvider,
    redirect: (context, state) => handleAuthRedirect(
      isAuthenticated: authProvider.isAuthenticated,
      needsBranchSelection: authProvider.needsBranchSelection,
      isLibrarian: authProvider.isLibrarian,
      isStoreManager: authProvider.isAssignedStoresOnly,
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
      GoRoute(
        path: AppRoutes.requestItem,
        name: AppRoutes.requestItemName,
        builder: (context, state) => _adminPage((_) => pages.RequestItemPage()),
      ),
      ...inventoryRoutes(),
      ...libraryRoutes(),
      GoRoute(
        path: AppRoutes.drivers,
        name: AppRoutes.driversName,
        builder: (context, state) => _adminPage((_) => pages.DriversPage()),
      ),
      GoRoute(
        path: AppRoutes.addDriver,
        name: AppRoutes.addDriverName,
        builder: (context, state) => _adminPage((_) {
          final driver = state.extra is Driver ? state.extra as Driver : null;
          return pages.AddDriverPage(driver: driver);
        }),
      ),
      GoRoute(
        path: AppRoutes.driverInfo,
        name: AppRoutes.driverInfoName,
        redirect: _requireExtra<Driver>(AppRoutes.drivers),
        builder: (context, state) => _adminPage((_) {
          final driver = state.extra as Driver;
          return pages.DriverInfoPage(driver: driver);
        }),
      ),
      GoRoute(
        path: AppRoutes.driverDocs,
        name: AppRoutes.driverDocsName,
        redirect: _requireExtra<Driver>(AppRoutes.drivers),
        builder: (context, state) => _adminPage((_) {
          final driver = state.extra as Driver;
          return pages.DriverDocsPage(driver: driver);
        }),
      ),
      GoRoute(
        path: AppRoutes.vehicles,
        name: AppRoutes.vehiclesName,
        builder: (context, state) => _adminPage((_) => pages.VehiclesPage()),
      ),
      GoRoute(
        path: AppRoutes.addVehicle,
        name: AppRoutes.addVehicleName,
        builder: (context, state) => _adminPage((_) {
          final vehicle = state.extra is VehicleData
              ? state.extra as VehicleData
              : null;
          return pages.AddVehiclePage(vehicle: vehicle);
        }),
      ),
      GoRoute(
        path: AppRoutes.vehicleDetails,
        name: AppRoutes.vehicleDetailsName,
        redirect: _requireExtra<VehicleData>(AppRoutes.vehicles),
        builder: (context, state) => _adminPage((_) {
          final vehicle = state.extra as VehicleData;
          return pages.VehicleDetailsPage(vehicle: vehicle);
        }),
      ),
      GoRoute(
        path: AppRoutes.vehicleDocs,
        name: AppRoutes.vehicleDocsName,
        redirect: _requireExtra<VehicleData>(AppRoutes.vehicles),
        builder: (context, state) => _adminPage((_) {
          final vehicle = state.extra as VehicleData;
          return pages.VehicleDocsPage(vehicle: vehicle);
        }),
      ),
      GoRoute(
        path: AppRoutes.manageRoutes,
        name: AppRoutes.manageRoutesName,
        builder: (context, state) =>
            _adminPage((_) => pages.ManageRoutesPage()),
      ),
      GoRoute(
        path: AppRoutes.studentRouteChange,
        name: AppRoutes.studentRouteChangeName,
        builder: (context, state) =>
            _adminPage((_) => pages.StudentRouteChangePage()),
      ),
      GoRoute(
        path: AppRoutes.routeTimeChange,
        name: AppRoutes.routeTimeChangeName,
        builder: (context, state) =>
            _adminPage((_) => pages.RouteTimeChangePage()),
      ),
      GoRoute(
        path: AppRoutes.announcements,
        name: AppRoutes.announcementsName,
        builder: (context, state) =>
            _adminPage((_) => pages.AnnouncementsPage()),
      ),
      GoRoute(
        path: AppRoutes.postAnnouncement,
        name: AppRoutes.postAnnouncementName,
        builder: (context, state) =>
            _adminPage((_) => pages.PostAnnouncementsPage()),
      ),
      GoRoute(
        path: AppRoutes.repairsExpense,
        name: AppRoutes.repairsExpenseName,
        builder: (context, state) =>
            _adminPage((_) => pages.RepairsExpensePage()),
      ),
      GoRoute(
        path: AppRoutes.vehicleOptions,
        name: AppRoutes.vehicleOptionsName,
        redirect: _requireExtra<Vehicle>(AppRoutes.repairsExpense),
        builder: (context, state) => _adminPage((_) {
          final vehicle = state.extra as Vehicle;
          return pages.OptionsPage(vehicle: vehicle);
        }),
      ),
      GoRoute(
        path: AppRoutes.manageExpense,
        name: AppRoutes.manageExpenseName,
        builder: (context, state) =>
            _adminPage((_) => pages.ManageExpensePage()),
      ),
      GoRoute(
        path: AppRoutes.addExpense,
        name: AppRoutes.addExpenseName,
        redirect: _requireExtra<GenericExpenseArgs>(AppRoutes.repairsExpense),
        builder: (context, state) => _adminPage((_) {
          final args = state.extra as GenericExpenseArgs;
          return pages.GenericExpenseFormPage(args: args);
        }),
      ),
      GoRoute(
        path: AppRoutes.selfFilling,
        name: AppRoutes.selfFillingName,
        builder: (context, state) => _adminPage(
          (_) => pages.SelfFillingPage(
            initialFuelType: state.extra is String
                ? state.extra as String
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.selfFillingVehicles,
        name: AppRoutes.selfFillingVehiclesName,
        redirect: _requireExtra<String>(AppRoutes.manageExpense),
        builder: (context, state) => _adminPage(
          (_) => pages.SelfFillingVehiclesPage(fuelType: state.extra as String),
        ),
      ),
      GoRoute(
        path: AppRoutes.looseFuel,
        name: AppRoutes.looseFuelName,
        redirect: _requireExtra<LooseFuelArgs>(AppRoutes.manageExpense),
        builder: (context, state) => _adminPage(
          (_) => pages.LooseFuelExpensePage(args: state.extra as LooseFuelArgs),
        ),
      ),
      GoRoute(
        path: AppRoutes.endFilling,
        name: AppRoutes.endFillingName,
        redirect: _requireExtra<String>(AppRoutes.manageExpense),
        builder: (context, state) => _adminPage(
          (_) => pages.EndFillingPage(initialFuelType: state.extra as String),
        ),
      ),
      GoRoute(
        path: AppRoutes.expenseConfirmation,
        name: AppRoutes.expenseConfirmationName,
        redirect: _requireExtra<ExpenseConfirmationData>(AppRoutes.dashboard),
        builder: (context, state) => _adminPage((_) {
          final data = state.extra as ExpenseConfirmationData;
          return pages.ExpenseConfirmationPage(data: data);
        }),
      ),
      GoRoute(
        path: AppRoutes.logBook,
        name: AppRoutes.logBookName,
        builder: (context, state) => _adminPage((_) => pages.LogBookPage()),
      ),
      GoRoute(
        path: AppRoutes.complaintsDashboard,
        name: AppRoutes.complaintsDashboardName,
        builder: (context, state) =>
            _adminPage((_) => pages.ComplaintsDashboardPage()),
      ),
      GoRoute(
        path: AppRoutes.complaints,
        name: AppRoutes.complaintsName,
        builder: (context, state) => _adminPage((_) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : null;
          return pages.ComplaintsPage(
            status: map?['status'] as String?,
            categoryId: map?['categoryId'] as int?,
            vehicleId: map?['vehicleId'] as int?,
          );
        }),
      ),
      GoRoute(
        path: AppRoutes.complaintDetails,
        name: AppRoutes.complaintDetailsName,
        redirect: _requireExtra<Complaint>(AppRoutes.complaints),
        builder: (context, state) => _adminPage((_) {
          final complaint = state.extra as Complaint;
          return pages.ComplaintDetailsPage(complaint: complaint);
        }),
      ),
      GoRoute(
        path: AppRoutes.addComplaint,
        name: AppRoutes.addComplaintName,
        builder: (context, state) =>
            _adminPage((_) => pages.AddComplaintPage()),
      ),
      GoRoute(
        path: AppRoutes.cleaningLog,
        name: AppRoutes.cleaningLogName,
        builder: (context, state) => _adminPage((_) => pages.CleaningLogPage()),
      ),
      GoRoute(
        path: AppRoutes.alcoholTestForm,
        name: AppRoutes.alcoholTestFormName,
        builder: (context, state) =>
            _adminPage((_) => pages.AlcoholTestFormPage()),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: AppRoutes.reportsName,
        builder: (context, state) => _adminPage((_) => pages.ReportsPage()),
      ),
      GoRoute(
        path: AppRoutes.arrivalTimeReport,
        name: AppRoutes.arrivalTimeReportName,
        builder: (context, state) =>
            _adminPage((_) => pages.ArrivalTimeReportPage()),
      ),
      GoRoute(
        path: AppRoutes.cleaningReport,
        name: AppRoutes.cleaningReportName,
        builder: (context, state) =>
            _adminPage((_) => pages.CleaningReportPage()),
      ),
      GoRoute(
        path: AppRoutes.alcoholTestReport,
        name: AppRoutes.alcoholTestReportName,
        builder: (context, state) =>
            _adminPage((_) => pages.AlcoholTestReportPage()),
      ),
      GoRoute(
        path: AppRoutes.fuelReport,
        name: AppRoutes.fuelReportName,
        builder: (context, state) => _adminPage((_) => pages.FuelReportPage()),
      ),
      GoRoute(
        path: AppRoutes.mileageReport,
        name: AppRoutes.mileageReportName,
        builder: (context, state) =>
            _adminPage((_) => pages.MileageReportPage()),
      ),
      GoRoute(
        path: AppRoutes.overSpeedReport,
        name: AppRoutes.overSpeedReportName,
        builder: (context, state) =>
            _adminPage((_) => pages.OverSpeedReportPage()),
      ),
      GoRoute(
        path: AppRoutes.gatePass,
        name: AppRoutes.gatePassName,
        builder: (context, state) => _adminPage((_) => pages.GatePassPage()),
      ),
      GoRoute(
        path: AppRoutes.generateGatePass,
        name: AppRoutes.generateGatePassName,
        builder: (context, state) =>
            _adminPage((_) => pages.GenerateGatePassPage()),
      ),
      GoRoute(
        path: AppRoutes.confirmGatePass,
        name: AppRoutes.confirmGatePassName,
        redirect: _requireMapKeys(AppRoutes.gatePass, ['student']),
        builder: (context, state) => _adminPage((_) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final student = map['student'] as StudentData;
          final personType = map['personType'] as String? ?? 'STUDENT';
          return pages.ConfirmGatePassPage(
            student: student,
            personType: personType,
          );
        }),
      ),
      GoRoute(
        path: AppRoutes.pendingGatePass,
        name: AppRoutes.pendingGatePassName,
        builder: (context, state) =>
            _adminPage((_) => pages.PendingGatePassPage()),
      ),
      GoRoute(
        path: AppRoutes.fleetStatus,
        name: AppRoutes.fleetStatusName,
        builder: (context, state) => _adminPage((_) => pages.FleetStatusPage()),
      ),
      GoRoute(
        path: AppRoutes.trackBus,
        name: AppRoutes.trackBusName,
        builder: (context, state) => _adminPage((_) => pages.TrackBusPage()),
      ),
      GoRoute(
        path: AppRoutes.trackingWebview,
        name: AppRoutes.trackingWebviewName,
        builder: (context, state) => _adminPage((_) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final url = map['url'] as String? ?? '';
          final title = map['title'] as String? ?? 'Live Tracking';
          return pages.TrackingWebviewPage(url: url, title: title);
        }),
      ),
      GoRoute(
        path: AppRoutes.dropBoarding,
        name: AppRoutes.dropBoardingName,
        builder: (context, state) =>
            _adminPage((_) => pages.DropBoardingPage()),
      ),
      GoRoute(
        path: AppRoutes.dropVehicles,
        name: AppRoutes.dropVehiclesName,
        builder: (context, state) =>
            _adminPage((_) => pages.DropVehiclesPage()),
      ),
      GoRoute(
        path: AppRoutes.boarding,
        name: AppRoutes.boardingName,
        builder: (context, state) => _adminPage((_) => pages.BoardingPage()),
      ),
      GoRoute(
        path: AppRoutes.attendance,
        name: AppRoutes.attendanceName,
        builder: (context, state) => _adminPage((_) => pages.AttendancePage()),
      ),
      GoRoute(
        path: AppRoutes.attendanceSections,
        name: AppRoutes.attendanceSectionsName,
        redirect: _requireExtra<AssignedEntityClass>(AppRoutes.attendance),
        builder: (context, state) => _adminPage((_) {
          final standard = state.extra as AssignedEntityClass;
          return pages.SectionsPage(standard: standard);
        }),
      ),
      GoRoute(
        path: AppRoutes.createAttendance,
        name: AppRoutes.createAttendanceName,
        redirect: _requireMapKeys(AppRoutes.attendance, ['standard']),
        builder: (context, state) => _adminPage((_) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final standard = map['standard'] as AssignedEntityClass;
          final section = map['section'] as String? ?? '';
          return pages.CreateAttendancePage(
            standard: standard,
            section: section,
          );
        }),
      ),
      GoRoute(
        path: AppRoutes.sdkAttendance,
        name: AppRoutes.sdkAttendanceName,
        redirect: _requireMapKeys(AppRoutes.attendance, ['standard']),
        builder: (context, state) => _adminPage((_) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final standard = map['standard'] as AssignedEntityClass;
          final section = map['section'] as String? ?? '';
          final initialMode =
              map['initialMode'] as AttendanceModeOption? ??
              AttendanceModeOption.sdkLive;
          return pages.SdkAttendancePage(
            standard: standard,
            section: section,
            initialMode: initialMode,
          );
        }),
      ),
      GoRoute(
        path: AppRoutes.attendanceConfirmation,
        name: AppRoutes.attendanceConfirmationName,
        builder: (context, state) =>
            _adminPage((_) => pages.AttendanceConfirmationPage()),
      ),
    ],
  );
}
