import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../services/analytics_service.dart';
import '../services/api_client.dart';
import '../services/injectable.dart';
import 'alcohol_test_provider.dart';
import 'announcements_provider.dart';
import 'attendance_provider.dart';
import 'auth_provider.dart';
import 'common_provider.dart';
import 'driver_provider.dart';
import 'expense_provider.dart';
import 'facility_provider.dart';
import 'gatepass_provider.dart';
import 'reports_provider.dart';
import 'students_provider.dart';
import 'vehicle_provider.dart';

List<SingleChildWidget> get appProviders {
  return [
    Provider(create: (_) => getIt<ApiClient>()),
    Provider(create: (_) => getIt<AnalyticsService>()),

    ChangeNotifierProvider(create: (_) => getIt<AuthProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<AnnouncementsProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<StudentsProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<VehicleProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<AttendanceProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<GatePassProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<ExpenseProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<DriverProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<CommonProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<ReportsProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<AlcoholTestProvider>()),
    ChangeNotifierProvider(create: (_) => getIt<FacilityProvider>()),
  ];
}
