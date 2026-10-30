import 'package:api_client/api_client.dart';
import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:drivers/drivers.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/announcements/announcements_page.dart';
import 'package:icueadmin/features/announcements/post_announcements_page.dart';
import 'package:icueadmin/features/attendance/attendance_confirmation_page.dart';
import 'package:icueadmin/features/attendance/attendance_page.dart';
import 'package:icueadmin/features/attendance/create_attendance_page.dart';
import 'package:icueadmin/features/attendance/sdk_attendance_page.dart';
import 'package:icueadmin/features/attendance/sections_page.dart';
import 'package:icueadmin/features/auth/login_page.dart';
import 'package:icueadmin/features/branches/branches_page.dart';
import 'package:icueadmin/features/dashboard/dashboard_page.dart';
import 'package:icueadmin/features/drivers/add_driver_page.dart';
import 'package:icueadmin/features/drivers/driver_docs_page.dart';
import 'package:icueadmin/features/drivers/driver_info_page.dart';
import 'package:icueadmin/features/drivers/drivers_page.dart';
import 'package:icueadmin/features/drop_boarding/boarding_page.dart';
import 'package:icueadmin/features/drop_boarding/drop_boarding_page.dart';
import 'package:icueadmin/features/drop_boarding/drop_vehicles_page.dart';
import 'package:icueadmin/features/expenses/end_filling_page.dart';
import 'package:icueadmin/features/expenses/expense_confirmation_page.dart';
import 'package:icueadmin/features/expenses/generic_expense_form_page.dart';
import 'package:icueadmin/features/expenses/manage_expense_page.dart';
import 'package:icueadmin/features/expenses/options_page.dart';
import 'package:icueadmin/features/expenses/repairs_expense_page.dart';
import 'package:icueadmin/features/expenses/self_filling_page.dart';
import 'package:icueadmin/features/gatepass/confirm_gatepass_page.dart';
import 'package:icueadmin/features/gatepass/gatepass_page.dart';
import 'package:icueadmin/features/gatepass/generate_gatepass_page.dart';
import 'package:icueadmin/features/gatepass/pending_gatepass_page.dart';
import 'package:icueadmin/features/logbook/add_complaint_page.dart';
import 'package:icueadmin/features/logbook/alcohol_test_form_page.dart';
import 'package:icueadmin/features/logbook/cleaning_log_page.dart';
import 'package:icueadmin/features/logbook/complaint_details_page.dart';
import 'package:icueadmin/features/logbook/complaints_dashboard_page.dart';
import 'package:icueadmin/features/logbook/complaints_page.dart';
import 'package:icueadmin/features/logbook/log_book_page.dart';
import 'package:icueadmin/features/reports/alcohol_test_report_page.dart';
import 'package:icueadmin/features/reports/arrival_time_report_page.dart';
import 'package:icueadmin/features/reports/cleaning_report_page.dart';
import 'package:icueadmin/features/reports/fuel_report_page.dart';
import 'package:icueadmin/features/reports/mileage_report_page.dart';
import 'package:icueadmin/features/reports/over_speed_report_page.dart';
import 'package:icueadmin/features/reports/reports_page.dart';
import 'package:icueadmin/features/routes/manage_routes_page.dart';
import 'package:icueadmin/features/routes/route_time_change_page.dart';
import 'package:icueadmin/features/routes/student_route_change_page.dart';
import 'package:icueadmin/features/tracking/fleet_status_page.dart';
import 'package:icueadmin/features/tracking/track_bus_page.dart';
import 'package:icueadmin/features/tracking/tracking_webview_page.dart';
import 'package:icueadmin/features/vehicles/add_vehicle_page.dart';
import 'package:icueadmin/features/vehicles/vehicle_details_page.dart';
import 'package:icueadmin/features/vehicles/vehicle_docs_page.dart';
import 'package:icueadmin/features/vehicles/vehicles_page.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:logbook/logbook.dart';
import 'package:routes/routes.dart';
import 'package:vehicles/vehicles.dart';

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
      GoRoute(
        path: AppRoutes.drivers,
        name: AppRoutes.driversName,
        builder: (context, state) => const DriversPage(),
      ),
      GoRoute(
        path: AppRoutes.addDriver,
        name: AppRoutes.addDriverName,
        builder: (context, state) {
          final driver = state.extra is Driver ? state.extra as Driver : null;
          return AddDriverPage(driver: driver);
        },
      ),
      GoRoute(
        path: AppRoutes.driverInfo,
        name: AppRoutes.driverInfoName,
        builder: (context, state) {
          final driver = state.extra as Driver;
          return DriverInfoPage(driver: driver);
        },
      ),
      GoRoute(
        path: AppRoutes.driverDocs,
        name: AppRoutes.driverDocsName,
        builder: (context, state) {
          final driver = state.extra as Driver;
          return DriverDocsPage(driver: driver);
        },
      ),
      GoRoute(
        path: AppRoutes.vehicles,
        name: AppRoutes.vehiclesName,
        builder: (context, state) => const VehiclesPage(),
      ),
      GoRoute(
        path: AppRoutes.addVehicle,
        name: AppRoutes.addVehicleName,
        builder: (context, state) {
          final vehicle =
              state.extra is VehicleData ? state.extra as VehicleData : null;
          return AddVehiclePage(vehicle: vehicle);
        },
      ),
      GoRoute(
        path: AppRoutes.vehicleDetails,
        name: AppRoutes.vehicleDetailsName,
        builder: (context, state) {
          final vehicle = state.extra as VehicleData;
          return VehicleDetailsPage(vehicle: vehicle);
        },
      ),
      GoRoute(
        path: AppRoutes.vehicleDocs,
        name: AppRoutes.vehicleDocsName,
        builder: (context, state) {
          final vehicle = state.extra as VehicleData;
          return VehicleDocsPage(vehicle: vehicle);
        },
      ),
      GoRoute(
        path: AppRoutes.manageRoutes,
        name: AppRoutes.manageRoutesName,
        builder: (context, state) => const ManageRoutesPage(),
      ),
      GoRoute(
        path: AppRoutes.studentRouteChange,
        name: AppRoutes.studentRouteChangeName,
        builder: (context, state) => const StudentRouteChangePage(),
      ),
      GoRoute(
        path: AppRoutes.routeTimeChange,
        name: AppRoutes.routeTimeChangeName,
        builder: (context, state) => const RouteTimeChangePage(),
      ),
      GoRoute(
        path: AppRoutes.announcements,
        name: AppRoutes.announcementsName,
        builder: (context, state) => const AnnouncementsPage(),
      ),
      GoRoute(
        path: AppRoutes.postAnnouncement,
        name: AppRoutes.postAnnouncementName,
        builder: (context, state) => const PostAnnouncementsPage(),
      ),
      GoRoute(
        path: AppRoutes.repairsExpense,
        name: AppRoutes.repairsExpenseName,
        builder: (context, state) => const RepairsExpensePage(),
      ),
      GoRoute(
        path: AppRoutes.vehicleOptions,
        name: AppRoutes.vehicleOptionsName,
        builder: (context, state) {
          final vehicle = state.extra as Vehicle;
          return OptionsPage(vehicle: vehicle);
        },
      ),
      GoRoute(
        path: AppRoutes.manageExpense,
        name: AppRoutes.manageExpenseName,
        builder: (context, state) => const ManageExpensePage(),
      ),
      GoRoute(
        path: AppRoutes.addExpense,
        name: AppRoutes.addExpenseName,
        builder: (context, state) {
          final args = state.extra as GenericExpenseArgs;
          return GenericExpenseFormPage(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.selfFilling,
        name: AppRoutes.selfFillingName,
        builder: (context, state) {
          final fuelType =
              state.extra is String ? state.extra as String : 'Diesel';
          return SelfFillingPage(initialFuelType: fuelType);
        },
      ),
      GoRoute(
        path: AppRoutes.endFilling,
        name: AppRoutes.endFillingName,
        builder: (context, state) {
          final fuelType =
              state.extra is String ? state.extra as String : 'Diesel';
          return EndFillingPage(initialFuelType: fuelType);
        },
      ),
      GoRoute(
        path: AppRoutes.expenseConfirmation,
        name: AppRoutes.expenseConfirmationName,
        builder: (context, state) {
          final data = state.extra as ExpenseConfirmationData;
          return ExpenseConfirmationPage(data: data);
        },
      ),
      GoRoute(
        path: AppRoutes.logBook,
        name: AppRoutes.logBookName,
        builder: (context, state) => const LogBookPage(),
      ),
      GoRoute(
        path: AppRoutes.complaintsDashboard,
        name: AppRoutes.complaintsDashboardName,
        builder: (context, state) => const ComplaintsDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.complaints,
        name: AppRoutes.complaintsName,
        builder: (context, state) {
          final map =
              state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
          return ComplaintsPage(
            status: map?['status'] as String?,
            categoryId: map?['categoryId'] as int?,
            vehicleId: map?['vehicleId'] as int?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.complaintDetails,
        name: AppRoutes.complaintDetailsName,
        builder: (context, state) {
          final complaint = state.extra as Complaint;
          return ComplaintDetailsPage(complaint: complaint);
        },
      ),
      GoRoute(
        path: AppRoutes.addComplaint,
        name: AppRoutes.addComplaintName,
        builder: (context, state) => const AddComplaintPage(),
      ),
      GoRoute(
        path: AppRoutes.cleaningLog,
        name: AppRoutes.cleaningLogName,
        builder: (context, state) => const CleaningLogPage(),
      ),
      GoRoute(
        path: AppRoutes.alcoholTestForm,
        name: AppRoutes.alcoholTestFormName,
        builder: (context, state) => const AlcoholTestFormPage(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: AppRoutes.reportsName,
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: AppRoutes.arrivalTimeReport,
        name: AppRoutes.arrivalTimeReportName,
        builder: (context, state) => const ArrivalTimeReportPage(),
      ),
      GoRoute(
        path: AppRoutes.cleaningReport,
        name: AppRoutes.cleaningReportName,
        builder: (context, state) => const CleaningReportPage(),
      ),
      GoRoute(
        path: AppRoutes.alcoholTestReport,
        name: AppRoutes.alcoholTestReportName,
        builder: (context, state) => const AlcoholTestReportPage(),
      ),
      GoRoute(
        path: AppRoutes.fuelReport,
        name: AppRoutes.fuelReportName,
        builder: (context, state) => const FuelReportPage(),
      ),
      GoRoute(
        path: AppRoutes.mileageReport,
        name: AppRoutes.mileageReportName,
        builder: (context, state) => const MileageReportPage(),
      ),
      GoRoute(
        path: AppRoutes.overSpeedReport,
        name: AppRoutes.overSpeedReportName,
        builder: (context, state) => const OverSpeedReportPage(),
      ),
      GoRoute(
        path: AppRoutes.gatePass,
        name: AppRoutes.gatePassName,
        builder: (context, state) => const GatePassPage(),
      ),
      GoRoute(
        path: AppRoutes.generateGatePass,
        name: AppRoutes.generateGatePassName,
        builder: (context, state) => const GenerateGatePassPage(),
      ),
      GoRoute(
        path: AppRoutes.confirmGatePass,
        name: AppRoutes.confirmGatePassName,
        builder: (context, state) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final student = map['student'] as StudentData;
          final personType = map['personType'] as String? ?? 'STUDENT';
          return ConfirmGatePassPage(
            student: student,
            personType: personType,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.pendingGatePass,
        name: AppRoutes.pendingGatePassName,
        builder: (context, state) => const PendingGatePassPage(),
      ),
      GoRoute(
        path: AppRoutes.fleetStatus,
        name: AppRoutes.fleetStatusName,
        builder: (context, state) => const FleetStatusPage(),
      ),
      GoRoute(
        path: AppRoutes.trackBus,
        name: AppRoutes.trackBusName,
        builder: (context, state) => const TrackBusPage(),
      ),
      GoRoute(
        path: AppRoutes.trackingWebview,
        name: AppRoutes.trackingWebviewName,
        builder: (context, state) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final url = map['url'] as String? ?? '';
          final title = map['title'] as String? ?? 'Live Tracking';
          return TrackingWebviewPage(url: url, title: title);
        },
      ),
      GoRoute(
        path: AppRoutes.dropBoarding,
        name: AppRoutes.dropBoardingName,
        builder: (context, state) => const DropBoardingPage(),
      ),
      GoRoute(
        path: AppRoutes.dropVehicles,
        name: AppRoutes.dropVehiclesName,
        builder: (context, state) => const DropVehiclesPage(),
      ),
      GoRoute(
        path: AppRoutes.boarding,
        name: AppRoutes.boardingName,
        builder: (context, state) => const BoardingPage(),
      ),
      GoRoute(
        path: AppRoutes.attendance,
        name: AppRoutes.attendanceName,
        builder: (context, state) => const AttendancePage(),
      ),
      GoRoute(
        path: AppRoutes.attendanceSections,
        name: AppRoutes.attendanceSectionsName,
        builder: (context, state) {
          final standard = state.extra as AssignedEntityClass;
          return SectionsPage(standard: standard);
        },
      ),
      GoRoute(
        path: AppRoutes.createAttendance,
        name: AppRoutes.createAttendanceName,
        builder: (context, state) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final standard = map['standard'] as AssignedEntityClass;
          final section = map['section'] as String? ?? '';
          return CreateAttendancePage(standard: standard, section: section);
        },
      ),
      GoRoute(
        path: AppRoutes.sdkAttendance,
        name: AppRoutes.sdkAttendanceName,
        builder: (context, state) {
          final map = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : <String, dynamic>{};
          final standard = map['standard'] as AssignedEntityClass;
          final section = map['section'] as String? ?? '';
          final initialMode =
              map['initialMode'] as AttendanceModeOption? ??
                  AttendanceModeOption.sdkLive;
          return SdkAttendancePage(
            standard: standard,
            section: section,
            initialMode: initialMode,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.attendanceConfirmation,
        name: AppRoutes.attendanceConfirmationName,
        builder: (context, state) => const AttendanceConfirmationPage(),
      ),
    ],
  );
}
