//@GeneratedMicroModule;InventoryPackageModule;package:inventory/src/di/inventory_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:inventory/src/providers/inventory_provider.dart' as _i532;
import 'package:inventory/src/services/inventory_service.dart' as _i241;

class InventoryPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i241.InventoryService>(() => _i241.InventoryService());
    gh.lazySingleton<_i532.InventoryProvider>(
      () => _i532.InventoryProvider(gh<_i241.InventoryService>()),
    );
  }
}
