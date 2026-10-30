//@GeneratedMicroModule;VehiclesPackageModule;package:vehicles/src/di/vehicles_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:injectable/injectable.dart' as _i526;
import 'package:vehicles/src/providers/vehicle_provider.dart' as _i406;
import 'package:vehicles/src/services/vehicle_service.dart' as _i196;

class VehiclesPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i196.VehicleService>(
        () => _i196.VehicleService(gh<_i633.ApiClient>()));
    gh.lazySingleton<_i406.VehicleProvider>(
        () => _i406.VehicleProvider(gh<_i196.VehicleService>()));
  }
}
