//@GeneratedMicroModule;ApiClientPackageModule;package:api_client/src/di/api_client_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/src/client/api_client.dart' as _i307;
import 'package:api_client/src/di/api_client_micro_module.dart' as _i983;
import 'package:injectable/injectable.dart' as _i526;

class ApiClientPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    final apiClientModule = _$ApiClientModule();
    gh.lazySingleton<_i307.ApiClient>(() => apiClientModule.apiClient());
  }
}

class _$ApiClientModule extends _i983.ApiClientModule {}
