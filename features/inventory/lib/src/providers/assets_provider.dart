import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_assets.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/services/assets_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Assets and maintenance. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class AssetsProvider extends ChangeNotifier {
  AssetsProvider(this._service, this._stock);

  final AssetsService _service;
  final StockService _stock;

  List<InvAsset> assets = [];
  List<InvMaintenance> maintenance = [];
  List<InvAssignment> assignments = [];
  List<AssetEvent> history = [];
  final Map<String, InvItem> items = {};
  String? errorMessage;
  bool isLoading = false;

  String itemName(String id) => items[id]?.name ?? id;

  Future<void> _load(Future<void> Function() body) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await body();
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssets(InvAccess a, {String? status}) =>
      _load(() async => assets = await _service.assets(a, status: status));

  Future<void> loadMaintenance(InvAccess a, {String? status}) =>
      _load(() async {
        maintenance = await _service.maintenance(a, status: status);
      });

  /// Custody records and timeline of one asset.
  Future<void> loadDetail(InvAccess a, String assetId) => _load(() async {
    final r = await Future.wait([
      _service.assignments(a, assetId),
      _service.history(a, assetId),
    ]);
    assignments = r[0] as List<InvAssignment>;
    history = r[1] as List<AssetEvent>;
  });

  Future<InvAsset?> asset(String id) async {
    try {
      return await _service.asset(id);
    } catch (e) {
      errorMessage = _message(e);
      return null;
    }
  }

  /// Resolves a scanned asset ID or RFID tag; null when unknown (or the read fails, with [errorMessage] set).
  Future<InvAsset?> findByCode(InvAccess a, String code) async {
    try {
      return await _service.findByCode(a, code.trim());
    } catch (e) {
      errorMessage = _message(e);
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
    String fn,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return await _stock.call(fn, data, requestId: requestId);
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
      return null;
    }
  }

  String _message(Object e) =>
      e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();
}
