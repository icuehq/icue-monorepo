//@GeneratedMicroModule;ParentTransportPackageModule;package:parent_transport/src/di/parent_transport_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/auth.dart' as _i662;
import 'package:injectable/injectable.dart' as _i526;
import 'package:parent_transport/src/providers/parent_tracking_provider.dart'
    as _i726;
import 'package:parent_transport/src/providers/parent_vehicles_provider.dart'
    as _i1065;
import 'package:parent_transport/src/providers/route_notifications_provider.dart'
    as _i611;
import 'package:parent_transport/src/providers/transport_attendance_provider.dart'
    as _i169;
import 'package:parent_transport/src/services/location_service.dart' as _i80;
import 'package:parent_transport/src/services/parent_transport_service.dart'
    as _i711;

class ParentTransportPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    final locationClientModule = _$LocationClientModule();
    gh.lazySingleton<_i633.ApiClient>(
      () => locationClientModule.locationClient(),
      instanceName: 'location',
    );
    gh.lazySingleton<_i711.ParentTransportService>(
      () => _i711.ParentTransportService(gh<_i633.ApiClient>()),
    );
    gh.lazySingleton<_i80.LocationService>(
      () => _i80.LocationService(gh<_i633.ApiClient>(instanceName: 'location')),
    );
    gh.lazySingleton<_i1065.ParentVehiclesProvider>(
      () => _i1065.ParentVehiclesProvider(
        gh<_i711.ParentTransportService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
    gh.lazySingleton<_i611.RouteNotificationsProvider>(
      () => _i611.RouteNotificationsProvider(
        gh<_i711.ParentTransportService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
    gh.lazySingleton<_i169.TransportAttendanceProvider>(
      () => _i169.TransportAttendanceProvider(
        gh<_i711.ParentTransportService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
    gh.lazySingleton<_i726.ParentTrackingProvider>(
      () => _i726.ParentTrackingProvider(
        gh<_i711.ParentTransportService>(),
        gh<_i80.LocationService>(),
        gh<_i662.ParentAuthProvider>(),
        gh<_i662.ParentDeviceInfo>(),
      ),
    );
  }
}

class _$LocationClientModule extends _i80.LocationClientModule {}
