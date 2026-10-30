//@GeneratedMicroModule;ReportsPackageModule;package:reports/src/di/reports_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:injectable/injectable.dart' as _i526;
import 'package:reports/src/providers/reports_provider.dart' as _i719;
import 'package:reports/src/services/reports_service.dart' as _i580;

class ReportsPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i580.ReportsService>(
        () => _i580.ReportsService(gh<_i633.ApiClient>()));
    gh.lazySingleton<_i719.ReportsProvider>(
        () => _i719.ReportsProvider(gh<_i580.ReportsService>()));
  }
}
