//@GeneratedMicroModule;SchoolConnectPackageModule;package:school_connect/src/di/school_connect_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:auth/auth.dart' as _i662;
import 'package:injectable/injectable.dart' as _i526;
import 'package:school_connect/src/providers/complaints_provider.dart' as _i47;
import 'package:school_connect/src/providers/events_provider.dart' as _i472;
import 'package:school_connect/src/services/school_connect_service.dart'
    as _i917;

class SchoolConnectPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i917.SchoolConnectService>(
      () => _i917.SchoolConnectService(gh<_i633.ApiClient>()),
    );
    gh.lazySingleton<_i47.ComplaintsProvider>(
      () => _i47.ComplaintsProvider(
        gh<_i917.SchoolConnectService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
    gh.lazySingleton<_i472.EventsProvider>(
      () => _i472.EventsProvider(
        gh<_i917.SchoolConnectService>(),
        gh<_i662.ParentAuthProvider>(),
      ),
    );
  }
}
