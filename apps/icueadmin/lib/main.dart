import 'dart:async';

import 'package:announcements/announcements.dart';
import 'package:api_client/api_client.dart';
import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:gatepass/gatepass.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/di/injection.dart';
import 'package:icueadmin/features/splash/app_bootstrap.dart';
import 'package:icueadmin/routing/app_router.dart';
import 'package:icueadmin/theme/app_theme.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';
import 'package:reports/reports.dart';
import 'package:routes/routes.dart';
import 'package:tracking/tracking.dart';
import 'package:vehicles/vehicles.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Env is a compile-time define, so it's safe to resolve before bootstrap.
  final env = ApiEnvironment.fromEnvironment();
  runApp(
    AppBootstrap(
      environment: env,
      builder: (connectivity) =>
          IcueAdminApp(environment: env, connectivity: connectivity),
    ),
  );
}

class IcueAdminApp extends StatefulWidget {
  const IcueAdminApp({
    required this.environment,
    required this.connectivity,
    super.key,
  });

  final ApiEnvironment environment;
  final ConnectivityService connectivity;

  @override
  State<IcueAdminApp> createState() => _IcueAdminAppState();
}

class _IcueAdminAppState extends State<IcueAdminApp> {
  late final AuthProvider _authProvider;
  late final DriverProvider _driverProvider;
  late final VehicleProvider _vehicleProvider;
  late final RoutesProvider _routesProvider;
  late final AnnouncementsProvider _announcementsProvider;
  late final ExpenseProvider _expenseProvider;
  late final LogBookProvider _logBookProvider;
  late final ReportsProvider _reportsProvider;
  late final GatePassProvider _gatePassProvider;
  late final TrackingProvider _trackingProvider;
  late final DropBoardingProvider _dropBoardingProvider;
  late final AttendanceProvider _attendanceProvider;
  late final GoRouter _router;
  int? _trackedUserId;
  int? _trackedBranchId;

  @override
  void initState() {
    super.initState();
    _authProvider = getIt<AuthProvider>();
    _driverProvider = getIt<DriverProvider>();
    _vehicleProvider = getIt<VehicleProvider>();
    _routesProvider = getIt<RoutesProvider>();
    _announcementsProvider = getIt<AnnouncementsProvider>();
    _expenseProvider = getIt<ExpenseProvider>();
    _logBookProvider = getIt<LogBookProvider>();
    _reportsProvider = getIt<ReportsProvider>();
    _gatePassProvider = getIt<GatePassProvider>();
    _trackingProvider = getIt<TrackingProvider>();
    _dropBoardingProvider = getIt<DropBoardingProvider>();
    _attendanceProvider = getIt<AttendanceProvider>();
    // Seed so a restored session isn't logged as a fresh login.
    _trackedUserId = _authProvider.user?.id;
    _trackedBranchId = _authProvider.selectedBranch?.id;
    _authProvider.addListener(_syncFirebaseUser);
    _syncFirebaseUser();
    _router = createRouter(
      authProvider: _authProvider,
      environment: widget.environment,
    );
    // Restored session: login-time prompt won't fire, so ask here.
    if (_authProvider.user != null) {
      unawaited(NotificationService.instance.requestPermission());
    }
    unawaited(
      NotificationService.instance.init(
        // Backend sends the target path as data['route'].
        onTap: (data) {
          final route = data['route'];
          if (route is String && route.startsWith('/')) _router.go(route);
        },
      ),
    );
  }

  /// Tags crash reports and analytics events with the signed-in user (cleared on logout).
  void _syncFirebaseUser() {
    final user = _authProvider.user;
    final branch = _authProvider.selectedBranch;
    if (user?.id != _trackedUserId) {
      if (user == null) {
        track(AppEvents.logout);
      } else {
        AnalyticsService.instance.logLogin('otp');
        unawaited(NotificationService.instance.requestPermission());
      }
    }
    if (branch != null && branch.id != _trackedBranchId) {
      track(AppEvents.branchSelected);
    }
    _trackedUserId = user?.id;
    _trackedBranchId = branch?.id;
    CrashlyticsService.instance.setUser(
      id: user == null ? null : '${user.id}',
      organizationId: user == null ? null : '${user.organizationId}',
      zoneId: user == null ? null : '${user.zoneId}',
      // Zonal admins pick a branch; fall back to the user's own otherwise.
      branchId: user == null ? null : '${branch?.id ?? user.branchId}',
      schoolName: branch?.schoolName ?? user?.schoolName,
    );
    AnalyticsService.instance.setUser(
      id: user == null ? null : '${user.id}',
      properties: {
        'organization_id': '${user?.organizationId}',
        'zone_id': '${user?.zoneId}',
        'branch_id': '${branch?.id ?? user?.branchId}',
        'school_name': branch?.schoolName ?? user?.schoolName,
      },
    );
  }

  @override
  void dispose() {
    _authProvider.removeListener(_syncFirebaseUser);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DriverProvider>.value(value: _driverProvider),
        ChangeNotifierProvider<VehicleProvider>.value(value: _vehicleProvider),
        ChangeNotifierProvider<RoutesProvider>.value(value: _routesProvider),
        ChangeNotifierProvider<AnnouncementsProvider>.value(
          value: _announcementsProvider,
        ),
        ChangeNotifierProvider<ExpenseProvider>.value(value: _expenseProvider),
        ChangeNotifierProvider<LogBookProvider>.value(value: _logBookProvider),
        ChangeNotifierProvider<ReportsProvider>.value(value: _reportsProvider),
        ChangeNotifierProvider<GatePassProvider>.value(
          value: _gatePassProvider,
        ),
        ChangeNotifierProvider<TrackingProvider>.value(
          value: _trackingProvider,
        ),
        ChangeNotifierProvider<DropBoardingProvider>.value(
          value: _dropBoardingProvider,
        ),
        ChangeNotifierProvider<AttendanceProvider>.value(
          value: _attendanceProvider,
        ),
      ],
      child: MaterialApp.router(
        title: 'iCue Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forEnvironment(widget.environment),
        routerConfig: _router,
        builder: (context, child) =>
            ConnectivityBanner(service: widget.connectivity, child: child!),
      ),
    );
  }
}
