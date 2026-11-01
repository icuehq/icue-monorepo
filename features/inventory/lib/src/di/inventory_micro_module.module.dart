//@GeneratedMicroModule;InventoryPackageModule;package:inventory/src/di/inventory_micro_module.module.dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:inventory/src/providers/assets_provider.dart' as _i827;
import 'package:inventory/src/providers/inventory_provider.dart' as _i532;
import 'package:inventory/src/providers/procurement_provider.dart' as _i204;
import 'package:inventory/src/providers/stock_provider.dart' as _i940;
import 'package:inventory/src/services/assets_service.dart' as _i22;
import 'package:inventory/src/services/inventory_service.dart' as _i241;
import 'package:inventory/src/services/procurement_service.dart' as _i8;
import 'package:inventory/src/services/stock_service.dart' as _i878;

class InventoryPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i22.AssetsService>(() => _i22.AssetsService());
    gh.lazySingleton<_i241.InventoryService>(() => _i241.InventoryService());
    gh.lazySingleton<_i8.ProcurementService>(() => _i8.ProcurementService());
    gh.lazySingleton<_i878.StockService>(() => _i878.StockService());
    gh.lazySingleton<_i204.ProcurementProvider>(
      () => _i204.ProcurementProvider(
        gh<_i8.ProcurementService>(),
        gh<_i878.StockService>(),
      ),
    );
    gh.lazySingleton<_i532.InventoryProvider>(
      () => _i532.InventoryProvider(gh<_i241.InventoryService>()),
    );
    gh.lazySingleton<_i827.AssetsProvider>(
      () => _i827.AssetsProvider(
        gh<_i22.AssetsService>(),
        gh<_i878.StockService>(),
      ),
    );
    gh.lazySingleton<_i940.StockProvider>(
      () => _i940.StockProvider(gh<_i878.StockService>()),
    );
  }
}
