// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:firebase_analytics/firebase_analytics.dart' as _i398;
import 'package:firebase_crashlytics/firebase_crashlytics.dart' as _i141;
import 'package:firebase_messaging/firebase_messaging.dart' as _i892;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../providers/alcohol_test_provider.dart' as _i818;
import '../providers/announcements_provider.dart' as _i957;
import '../providers/attendance_provider.dart' as _i625;
import '../providers/auth_provider.dart' as _i773;
import '../providers/common_provider.dart' as _i710;
import '../providers/driver_provider.dart' as _i825;
import '../providers/expense_provider.dart' as _i964;
import '../providers/facility_provider.dart' as _i485;
import '../providers/gatepass_provider.dart' as _i371;
import '../providers/reports_provider.dart' as _i990;
import '../providers/students_provider.dart' as _i871;
import '../providers/vehicle_provider.dart' as _i1020;
import 'analytics_service.dart' as _i912;
import 'api_client.dart' as _i1013;
import 'crashlytics_service.dart' as _i487;
import 'injectable.dart' as _i1027;
import 'notification_service.dart' as _i459;
import 'route_observer.dart' as _i55;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final serviceModules = _$ServiceModules();
    gh.singleton<_i361.Dio>(() => serviceModules.dio);
    gh.lazySingleton<_i398.FirebaseAnalytics>(
        () => serviceModules.firebaseAnalytics);
    gh.lazySingleton<_i141.FirebaseCrashlytics>(
        () => serviceModules.firebaseCrashlytics);
    gh.lazySingleton<_i892.FirebaseMessaging>(
        () => serviceModules.firebaseMessaging);
    gh.lazySingleton<_i487.CrashlyticsService>(
        () => _i487.CrashlyticsService(gh<_i141.FirebaseCrashlytics>()));
    gh.lazySingleton<_i912.AnalyticsService>(
        () => _i912.AnalyticsService(gh<_i398.FirebaseAnalytics>()));
    gh.factory<_i55.AnalyticsRouteObserver>(
        () => _i55.AnalyticsRouteObserver(gh<_i912.AnalyticsService>()));
    gh.lazySingleton<_i1013.ApiClient>(() => _i1013.ApiClient(
          gh<_i361.Dio>(),
          gh<_i487.CrashlyticsService>(),
        ));
    gh.lazySingleton<_i371.GatePassProvider>(
        () => _i371.GatePassProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i625.AttendanceProvider>(
        () => _i625.AttendanceProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i485.FacilityProvider>(
        () => _i485.FacilityProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i773.AuthProvider>(
        () => _i773.AuthProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i825.DriverProvider>(
        () => _i825.DriverProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i990.ReportsProvider>(
        () => _i990.ReportsProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i871.StudentsProvider>(
        () => _i871.StudentsProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i1020.VehicleProvider>(
        () => _i1020.VehicleProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i957.AnnouncementsProvider>(
        () => _i957.AnnouncementsProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i964.ExpenseProvider>(
        () => _i964.ExpenseProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i710.CommonProvider>(
        () => _i710.CommonProvider(gh<_i1013.ApiClient>()));
    gh.lazySingleton<_i818.AlcoholTestProvider>(
        () => _i818.AlcoholTestProvider(gh<_i1013.ApiClient>()));
    gh.singleton<_i459.NotificationService>(
        () => _i459.NotificationService(gh<_i773.AuthProvider>()));
    return this;
  }
}

class _$ServiceModules extends _i1027.ServiceModules {}
