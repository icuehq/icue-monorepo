//@GeneratedMicroModule;LocalStoragePackageModule;package:local_storage/src/di/local_storage_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:local_storage/src/service/storage_service.dart' as _i166;

class LocalStoragePackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i166.StorageService>(() => _i166.StorageService());
  }
}
