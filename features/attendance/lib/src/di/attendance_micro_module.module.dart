//@GeneratedMicroModule;AttendancePackageModule;package:attendance/src/di/attendance_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:attendance/src/providers/attendance_provider.dart' as _i687;
import 'package:attendance/src/services/attendance_service.dart' as _i104;
import 'package:injectable/injectable.dart' as _i526;
import 'package:local_storage/local_storage.dart' as _i486;

class AttendancePackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i104.AttendanceService>(
        () => _i104.AttendanceService(gh<_i633.ApiClient>()));
    gh.factory<_i687.AttendanceProvider>(() => _i687.AttendanceProvider(
          gh<_i104.AttendanceService>(),
          gh<_i486.StorageService>(),
        ));
  }
}
