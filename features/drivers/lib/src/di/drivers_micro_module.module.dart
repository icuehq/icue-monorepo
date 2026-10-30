//@GeneratedMicroModule;DriversPackageModule;package:drivers/src/di/drivers_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:drivers/src/providers/driver_provider.dart' as _i111;
import 'package:drivers/src/services/driver_service.dart' as _i20;
import 'package:injectable/injectable.dart' as _i526;

class DriversPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i20.DriverService>(
        () => _i20.DriverService(gh<_i633.ApiClient>()));
    gh.lazySingleton<_i111.DriverProvider>(
        () => _i111.DriverProvider(gh<_i20.DriverService>()));
  }
}
