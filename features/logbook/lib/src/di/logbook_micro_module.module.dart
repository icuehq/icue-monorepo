//@GeneratedMicroModule;LogbookPackageModule;package:logbook/src/di/logbook_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:api_client/api_client.dart' as _i633;
import 'package:injectable/injectable.dart' as _i526;
import 'package:logbook/src/providers/logbook_provider.dart' as _i468;
import 'package:logbook/src/services/logbook_service.dart' as _i747;

class LogbookPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i747.LogBookService>(
      () => _i747.LogBookService(gh<_i633.ApiClient>()),
    );
    gh.lazySingleton<_i468.LogBookProvider>(
      () => _i468.LogBookProvider(gh<_i747.LogBookService>()),
    );
  }
}
