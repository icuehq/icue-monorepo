import 'package:announcements/announcements.dart';
import 'package:api_client/api_client.dart';
import 'package:attendance/attendance.dart';
import 'package:auth/auth.dart';
import 'package:drivers/drivers.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:gatepass/gatepass.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/di/injection.dart';
import 'package:icueadmin/routing/app_router.dart';
import 'package:icueadmin/theme/app_theme.dart';
import 'package:local_storage/local_storage.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';
import 'package:reports/reports.dart';
import 'package:routes/routes.dart';
import 'package:tracking/tracking.dart';
import 'package:vehicles/vehicles.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Resolve environment from --dart-define=ENV or --dart-define=FLAVOR
  final env = ApiEnvironment.fromEnvironment();

  // 2. Initialize dependencies for this environment
  await configureDependencies(env.name);

  // 3. Initialize Hive storage service & restore user session box
  await getIt<StorageService>().init();
  await getIt<UserLocalStorage>().init();

  runApp(IcueAdminApp(environment: env));
}

class IcueAdminApp extends StatefulWidget {
  const IcueAdminApp({required this.environment, super.key});

  final ApiEnvironment environment;

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
    _router = createRouter(
      authProvider: _authProvider,
      environment: widget.environment,
    );
  }

  @override
  void dispose() {
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
        ChangeNotifierProvider<ExpenseProvider>.value(
          value: _expenseProvider,
        ),
        ChangeNotifierProvider<LogBookProvider>.value(
          value: _logBookProvider,
        ),
        ChangeNotifierProvider<ReportsProvider>.value(
          value: _reportsProvider,
        ),
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
      ),
    );
  }
}
