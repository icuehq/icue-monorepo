//@GeneratedMicroModule;AuthPackageModule;package:auth/src/di/auth_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/src/providers/auth_provider.dart' as _i44;
import 'package:auth/src/services/auth_service.dart' as _i822;
import 'package:auth/src/storage/session_token_provider.dart' as _i516;
import 'package:auth/src/storage/user_local_storage.dart' as _i578;
import 'package:injectable/injectable.dart' as _i526;
import 'package:local_storage/local_storage.dart' as _i486;

class AuthPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    final authModule = _$AuthModule();
    gh.lazySingleton<_i578.UserLocalStorage>(
      () => _i578.UserLocalStorage(gh<_i486.StorageService>()),
    );
    gh.lazySingleton<_i516.SessionTokenProvider>(
      () => _i516.SessionTokenProvider(gh<_i578.UserLocalStorage>()),
    );
    gh.lazySingleton<_i633.TokenProvider>(
      () => authModule.tokenProvider(gh<_i516.SessionTokenProvider>()),
    );
    gh.lazySingleton<_i822.AuthService>(
      () => _i822.AuthService(
        gh<_i633.ApiClient>(),
        gh<_i516.SessionTokenProvider>(),
        gh<_i578.UserLocalStorage>(),
      ),
    );
    gh.lazySingleton<_i44.AuthProvider>(
      () => _i44.AuthProvider(
        gh<_i822.AuthService>(),
        gh<_i578.UserLocalStorage>(),
        gh<_i516.SessionTokenProvider>(),
      ),
    );
  }
}

class _$AuthModule extends _i516.AuthModule {}
