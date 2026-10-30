//@GeneratedMicroModule;TrackingPackageModule;package:tracking/src/di/tracking_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:injectable/injectable.dart' as _i526;
import 'package:tracking/src/providers/tracking_provider.dart' as _i97;
import 'package:tracking/src/services/tracking_service.dart' as _i384;
import 'package:tracking/src/services/tracking_socket_service.dart' as _i317;

class TrackingPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i317.TrackingSocketService>(
      () => _i317.TrackingSocketService(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i384.TrackingService>(
        () => _i384.TrackingService(gh<_i633.ApiClient>()));
    gh.lazySingleton<_i97.TrackingProvider>(() => _i97.TrackingProvider(
          gh<_i384.TrackingService>(),
          gh<_i317.TrackingSocketService>(),
        ));
  }
}
