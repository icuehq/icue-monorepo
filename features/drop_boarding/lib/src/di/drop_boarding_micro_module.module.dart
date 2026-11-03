//@GeneratedMicroModule;DropBoardingPackageModule;package:drop_boarding/src/di/drop_boarding_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:drop_boarding/src/providers/drop_boarding_provider.dart'
    as _i739;
import 'package:drop_boarding/src/services/drop_boarding_service.dart' as _i959;
import 'package:drop_boarding/src/services/drop_boarding_socket_service.dart'
    as _i903;
import 'package:injectable/injectable.dart' as _i526;
import 'package:routes/routes.dart' as _i678;

class DropBoardingPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i903.DropBoardingSocketService>(
      () => _i903.DropBoardingSocketService(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i959.DropBoardingService>(
      () => _i959.DropBoardingService(gh<_i633.ApiClient>()),
    );
    gh.factory<_i739.DropBoardingProvider>(
      () => _i739.DropBoardingProvider(
        gh<_i959.DropBoardingService>(),
        gh<_i903.DropBoardingSocketService>(),
        gh<_i678.RouteService>(),
      ),
    );
  }
}
