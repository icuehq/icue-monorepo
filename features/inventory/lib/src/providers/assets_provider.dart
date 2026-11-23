import 'dart:async';

import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_assets.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/services/assets_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Assets and maintenance. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class AssetsProvider extends LoadingProvider {
  AssetsProvider(this._service, this._stock);

  final AssetsService _service;
  final StockService _stock;

  /// Assets and maintenance jobs: server-side status filter, search, paging.
  late final assetList = ListState<InventoryAsset>(
    query: (status, search) =>
        _service.assetsQuery(status, search, storeId: storeId),
    fromDocument: (document) =>
        InventoryAsset.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
    afterPage: (assets) => loadItemNames(assets.map((asset) => asset.itemId)),
  );
  late final maintenanceList = ListState<InventoryMaintenance>(
    query: _service.maintenanceQuery,
    fromDocument: (document) =>
        InventoryMaintenance.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
    afterPage: (jobs) => loadItemNames(
      jobs.expand((job) => job.parts.map((partUsed) => partUsed.itemId)),
    ),
  );

  /// The asset list's Store filter; null shows every visible store.
  String? storeId;

  Future<void> setStore(String? value) {
    storeId = value;
    return assetList.load();
  }

  Future<void> clearFilters() {
    storeId = null;
    return assetList.clear();
  }

  List<InventoryAssignment> assignments = [];
  List<AssetEvent> history = [];
  final Map<String, InventoryItem> items = {};

  String itemName(String id) => items[id]?.name ?? id;

  /// Custody records and timeline of one asset.
  Future<void> loadDetail(String assetId) => load(() async {
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
      final result = await _stock.call(value, data, requestId: requestId);
      // Registering or changing an asset must show in the list without a page refresh.
      unawaited(assetList.load());
      return result;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }
}
