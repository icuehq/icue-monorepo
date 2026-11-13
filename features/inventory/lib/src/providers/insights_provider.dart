import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_insights.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/services/insights_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Dashboard and reports. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class InsightsProvider extends ChangeNotifier {
  InsightsProvider(this._service, this._stock);

  final InsightsService _service;
  final StockService _stock;

  List<ReportRow> rows = [];
  final Map<String, InventoryItem> items = {};
  String? errorMessage;
  bool isLoading = false;

  String itemName(Object? id) => items[id]?.name ?? '$id';

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

  Future<void> _names(Iterable<Object?> itemIds) async {
    final need = {
      for (final i in itemIds)
        if (i is String && !items.containsKey(i)) i,
    };
    if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
  }

  /// Live overview figures; the caller listens for as long as it is on screen.
  Stream<Map<String, num?>> watchDashboard({InventoryStore? store}) =>
      _service.dashboard(store: store);

  /// Loads [def]; balance reports come back sorted by item name.
  Future<void> loadReport(
    ReportDef def, {
    DateTime? from,
    DateTime? to,
    String? status,
  }) => _load(() async {
    rows = await _service.report(def, from: from, to: to, status: status);
    await _names(rows.map((row) => row['itemId']));
    if (def.collection == 'inventoryBalances') {
      rows.sort(
        (currentData, data) =>
            itemName(currentData['itemId']).compareTo(itemName(data['itemId'])),
      );
    }
  });

  /// Runs a callable; returns its result or null with [errorMessage] set.
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
