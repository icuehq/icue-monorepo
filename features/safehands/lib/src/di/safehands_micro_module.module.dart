//@GeneratedMicroModule;SafehandsPackageModule;package:safehands/src/di/safehands_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/auth.dart' as _i662;
import 'package:injectable/injectable.dart' as _i526;
import 'package:safehands/src/providers/escort_provider.dart' as _i1060;
import 'package:safehands/src/providers/safehands_provider.dart' as _i25;
import 'package:safehands/src/services/safehands_service.dart' as _i126;

class SafehandsPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i126.SafeHandsService>(
      () => _i126.SafeHandsService(gh<_i633.ApiClient>()),
    );
    gh.lazySingleton<_i1060.EscortProvider>(
      () => _i1060.EscortProvider(
        gh<_i126.SafeHandsService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
    gh.lazySingleton<_i25.SafeHandsProvider>(
      () => _i25.SafeHandsProvider(
        gh<_i126.SafeHandsService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
  }
}
