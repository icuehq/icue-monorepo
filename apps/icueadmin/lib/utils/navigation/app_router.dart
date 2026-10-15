import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/complaint_data.dart';
import '../../models/drivers.dart';
import '../../pages/announcements/announcements_page.dart';
import '../../pages/announcements/post_announcements_page.dart';
import '../../pages/attendance/attendance_page.dart';
import '../../pages/attendance/class_attendance_details_page.dart';
import '../../pages/attendance/class_attendance_stats_page.dart';
import '../../pages/auth/login_page.dart';
import '../../pages/branches_page.dart';
import '../../pages/dashboard/dashboard_page.dart';
import '../../pages/dashboard/fleet_status_page.dart';
import '../../pages/drivers/add_driver_page.dart';
import '../../pages/drivers/driver_docs_page.dart';
import '../../pages/drivers/driver_info_page.dart';
import '../../pages/drivers/drivers_page.dart';
import '../../pages/drop_boarding/drop_boarding_page.dart';
import '../../pages/fuel/fuel_page.dart';
import '../../pages/gatepass/gatepass_page.dart';
import '../../pages/gatepass/generate_gatepass_page.dart';
import '../../pages/gatepass/pending_gatepass_page.dart';
import '../../pages/log_book/add_complaint_page.dart';
import '../../pages/log_book/alcohol_test/alcohol_test_report_page.dart';
import '../../pages/log_book/alcohol_test_form_page.dart';
import '../../pages/log_book/cleaning_log/cleaning_log_page.dart';
import '../../pages/log_book/complaints_dashboard_page.dart';
import '../../pages/log_book/complaints_page.dart';
import '../../pages/log_book/log_book_page.dart';
import '../../pages/manage_routes/manage_routes_page.dart';
import '../../pages/manage_routes/route_time_change_page.dart';
import '../../pages/manage_vehicles/add_vehicle_page.dart';
import '../../pages/manage_vehicles/vehicle_details_page.dart';
import '../../pages/manage_vehicles/vehicle_docs_page.dart';
import '../../pages/manage_vehicles/vehicles_page.dart';
import '../../pages/repairs_expense/repairs_expense_page.dart';
import '../../pages/reports/reports_page.dart';
import '../../pages/reports/vehicle_arrival_time_report_page.dart';
import '../../pages/splash_page.dart';
import '../../pages/students/student_route_change_page.dart';
import '../../pages/track_bus/track_bus_page.dart';
import '../../pages/vehicle_management/reports/cleaning_report_page.dart';
import '../../services/screen_tracker.dart';
import '../../utils/constants.dart';
import '../../widgets/coming_soon.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  errorBuilder: (context, state) => const ComingSoon(),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) =>
          const ScreenTracker(screenName: 'splash-page', child: SplashPage()),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) =>
          const ScreenTracker(screenName: 'login-page', child: LoginPage()),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ScreenTracker(
            screenName: 'dashboard-page',
            child: DashboardPage(),
          ),
          routes: [
            /// Fleet Dashboard Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.fleetdashboard',
              builder: (context, state) => const ScreenTracker(
                screenName: 'fleet-status-page',
                child: FleetStatusPage(),
              ),
            ),

            /// Track Vehicle Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.trackvehicle',
              builder: (context, state) => const ScreenTracker(
                screenName: 'track-bus-page',
                child: TrackBusPage(),
              ),
            ),

            /// Manage Routes
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.routes',
              builder: (context, state) => const ScreenTracker(
                screenName: 'manage-routes-page',
                child: ManageRoutesPage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'student-route-change',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'stundent-route-change-page',
                    child: StudentRouteChangePage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'route-time-change',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'route-time-change-page',
                    child: RouteTimeChangePage(),
                  ),
                ),
              ],
            ),

            /// Announcements Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.fleetannouncement',
              builder: (context, state) => const ScreenTracker(
                screenName: 'post-announcements-page',
                child: PostAnnouncementsPage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.annoucements',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'announcements-page',
                    child: AnnouncementsPage(),
                  ),
                ),
              ],
            ),

            /// Drivers Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.drivers',
              builder: (context, state) => const ScreenTracker(
                screenName: 'drivers-page',
                child: DriversPage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'add-driver',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'add-driver-page',
                    child: AddDriverPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'update-driver',
                  builder: (context, state) => ScreenTracker(
                    screenName: 'update-driver-page',
                    child: AddDriverPage(driver: state.extra as Driver),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'driver-info',
                  builder: (context, state) => ScreenTracker(
                    screenName: 'driver-info-page',
                    child: DriverInfoPage(
                      driverId: state.uri.queryParameters['driverId'] ?? '',
                    ),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'driver-docs',
                  builder: (context, state) => ScreenTracker(
                    screenName: 'driver-docs-page',
                    child: DriverDocsPage(driver: (state.extra as Driver)),
                  ),
                ),
              ],
            ),

            /// Fuel Filling Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.fuelfilling',
              builder: (context, state) => const ScreenTracker(
                screenName: 'fuel-page',
                child: FuelPage(),
              ),
            ),

            /// Manage Vehicles Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.vehicles',
              builder: (context, state) => const ScreenTracker(
                screenName: 'vehicles-page',
                child: VehiclesPage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'add-vehicle',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'add-vehicle-page',
                    child: AddVehiclePage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'vehicle-details',
                  builder: (context, state) => ScreenTracker(
                    screenName: 'vehicle-details-page',
                    parameters: {'id': state.uri.queryParameters['id'] ?? ''},
                    child: VehicleDetailsPage(
                      id: state.uri.queryParameters['id'] ?? '',
                    ),
                  ),
                  routes: [
                    GoRoute(
                      parentNavigatorKey: navigatorKey,
                      path: 'update-vehicle',
                      builder: (context, state) => ScreenTracker(
                        screenName: 'update-vehicle-page',
                        parameters: {
                          'id': state.uri.queryParameters['id'] ?? '',
                        },
                        child: AddVehiclePage(
                          id: state.uri.queryParameters['id'] ?? '',
                        ),
                      ),
                    ),
                    GoRoute(
                      parentNavigatorKey: navigatorKey,
                      path: 'vehicle-docs',
                      builder: (context, state) => ScreenTracker(
                        screenName: 'vehicle-docs-page',
                        parameters: {
                          'id': state.uri.queryParameters['id'] ?? '',
                        },
                        child: VehicleDocsPage(
                          id: state.uri.queryParameters['id'] ?? '',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            /// Repairs and Expenses Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.repairsandexpenses',
              builder: (context, state) => const ScreenTracker(
                screenName: 'repairs-and-expense-page',
                child: RepairsAndExpensePage(),
              ),
            ),

            /// Log Book Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.logbook',
              builder: (context, state) => const ScreenTracker(
                screenName: 'log-book-page',
                child: LogBookPage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.regularactivities',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'regular-activities-page',
                    child: ComingSoon(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.complaints',
                  builder: (context, state) {
                    final data = state.extra is Map
                        ? Map<String, dynamic>.from(state.extra as Map)
                        : <String, dynamic>{};
                    return ScreenTracker(
                      screenName: 'complaints-page',
                      parameters: data,
                      child: ComplaintsPage(
                        status: data['status'],
                        categoryId: data['categoryId'],
                        vehicleId: data['vehicleId'],
                      ),
                    );
                  },
                  routes: [
                    GoRoute(
                      parentNavigatorKey: navigatorKey,
                      path: 'add-complaint',
                      builder: (context, state) => ScreenTracker(
                        screenName: 'add-complaint-page',
                        child: AddComplaintPage(
                          complaint: state.extra as Complaint?,
                        ),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.complaintsdashboard',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'complaints-dashboard-page',
                    child: ComplaintsDashboardPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.cleaninglog',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'cleaning-log-page',
                    child: CleaningLogPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.alcoholtest',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'alcohol-test-form-page',
                    child: AlcoholTestFormPage(),
                  ),
                ),
              ],
            ),

            /// Reports Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.reports',
              builder: (context, state) => const ScreenTracker(
                screenName: 'reports-page',
                child: ReportsPage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.vehiclecleaning',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'vehicle-cleaning-report-page',
                    child: CleaningReportPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.vehiclearrival',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'vehicle-arrival-report-page',
                    child: VehicleArrivalTimeReportPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.alcoholtestreport',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'alcohol-test-report-page',
                    child: AlcoholTestReportPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.classattendance',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'class-attendance-stats-page',
                    child: ClassAttendanceStatsPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.classattendancestats',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'class-attendance-stats-page',
                    child: ClassAttendanceStatsPage(),
                  ),
                ),
              ],
            ),

            /// Gate Pass Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.gatepass',
              builder: (context, state) => const ScreenTracker(
                screenName: 'gate-pass-page',
                child: GatePassPage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.generategatepass',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'generate-gate-pass-page',
                    child: GenerateGatePassPage(),
                  ),
                ),
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'layout.approvegatepass',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'approve-gate-pass-page',
                    child: PendingGatePassPage(),
                  ),
                ),
              ],
            ),

            /// Attendance Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.attendance',
              builder: (context, state) => const ScreenTracker(
                screenName: 'attendance-page',
                child: AttendancePage(),
              ),
              routes: [
                GoRoute(
                  parentNavigatorKey: navigatorKey,
                  path: 'stats',
                  builder: (context, state) => const ScreenTracker(
                    screenName: 'class-attendance-stats-page',
                    child: ClassAttendanceStatsPage(),
                  ),
                ),
              ],
            ),

            /// Class Attendance Stats Direct Routes
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.classattendance',
              builder: (context, state) => const ScreenTracker(
                screenName: 'class-attendance-stats-page',
                child: ClassAttendanceStatsPage(),
              ),
            ),
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.classattendancestats',
              builder: (context, state) => const ScreenTracker(
                screenName: 'class-attendance-stats-page',
                child: ClassAttendanceStatsPage(),
              ),
            ),
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'class-attendance-details',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>? ?? {};
                return ScreenTracker(
                  screenName: 'class-attendance-details-page',
                  child: ClassAttendanceDetailsPage(
                    classId: extra['classId'] as int? ?? 0,
                    standard: extra['standard'] as String? ?? '',
                    section: extra['section'] as String? ?? '',
                    reportMode:
                        extra['reportMode'] as FilterMode? ?? FilterMode.bydate,
                    fromDate: extra['fromDate'] as DateTime?,
                    toDate: extra['toDate'] as DateTime?,
                    month: extra['month'] as String?,
                    year: extra['year'] as String?,
                  ),
                );
              },
            ),

            /// Branches Route
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'branches',
              builder: (context, state) => const ScreenTracker(
                screenName: 'branches-page',
                child: BranchesPage(),
              ),
            ),

            /// Drop Boarding
            GoRoute(
              parentNavigatorKey: navigatorKey,
              path: 'layout.dropboarding',
              builder: (context, state) => const ScreenTracker(
                screenName: 'branches-page',
                child: DropBoardingPage(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
