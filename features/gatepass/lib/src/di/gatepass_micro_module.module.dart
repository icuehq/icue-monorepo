//@GeneratedMicroModule;GatepassPackageModule;package:gatepass/src/di/gatepass_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:gatepass/src/providers/gatepass_provider.dart' as _i176;
import 'package:gatepass/src/services/gatepass_service.dart' as _i925;
import 'package:injectable/injectable.dart' as _i526;

class GatepassPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i925.GatePassService>(
        () => _i925.GatePassService(gh<_i633.ApiClient>()));
    gh.lazySingleton<_i176.GatePassProvider>(
        () => _i176.GatePassProvider(gh<_i925.GatePassService>()));
  }
}
