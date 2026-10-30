//@GeneratedMicroModule;RoutesPackageModule;package:routes/src/di/routes_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:injectable/injectable.dart' as _i526;
import 'package:routes/src/providers/routes_provider.dart' as _i677;
import 'package:routes/src/services/route_service.dart' as _i564;

class RoutesPackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i564.RouteService>(
        () => _i564.RouteService(gh<_i633.ApiClient>()));
    gh.lazySingleton<_i677.RoutesProvider>(
        () => _i677.RoutesProvider(gh<_i564.RouteService>()));
  }
}
