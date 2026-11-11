import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_assets.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/services/assets_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Assets and maintenance. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class AssetsProvider extends ChangeNotifier {
  AssetsProvider(this._service, this._stock);

  final AssetsService _service;
  final StockService _stock;

  List<InventoryAsset> assets = [];
  List<InventoryMaintenance> maintenance = [];
  List<InventoryAssignment> assignments = [];
  List<AssetEvent> history = [];
  final Map<String, InventoryItem> items = {};
  String? errorMessage;
  bool isLoading = false;

  String itemName(String id) => items[id]?.name ?? id;

  Future<void> _load(Future<void> Function() body) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await body();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssets({String? status}) =>
      _load(() async => assets = await _service.assets(status: status));

  Future<void> loadMaintenance({String? status}) => _load(() async {
    maintenance = await _service.maintenance(status: status);
  });

  /// Custody records and timeline of one asset.
  Future<void> loadDetail(String assetId) => _load(() async {
    final masterLists = await Future.wait([
      _service.assignments(assetId),
      _service.history(assetId),
    ]);
    assignments = masterLists[0] as List<InventoryAssignment>;
    history = masterLists[1] as List<AssetEvent>;
  });

  Future<InventoryAsset?> asset(String id) async {
    try {
      return await _service.asset(id);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      return null;
    }
  }

  /// Resolves a scanned asset ID or RFID tag; null when unknown (or the read fails, with [errorMessage] set).
  Future<InventoryAsset?> findByCode(String code) async {
    try {
      return await _service.findByCode(code.trim());
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      return null;
    }
  }

  /// Names for [itemIds] (parts and registered items).
  Future<void> loadItemNames(Iterable<String> itemIds) async {
    final need = itemIds.where((i) => !items.containsKey(i));
    if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
    notifyListeners();
  }

  /// Runs a callable; returns its result (`id`, `number`) or null with [errorMessage] set.
  Future<Map<String, dynamic>?> act(
    String value,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return await _stock.call(value, data, requestId: requestId);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }
}
