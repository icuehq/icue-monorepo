import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_insights.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/services/insights_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Verification sessions, dashboard and reports. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class InsightsProvider extends ChangeNotifier {
  InsightsProvider(this._service, this._stock);

  final InsightsService _service;
  final StockService _stock;

  List<InventoryVerification> verifications = [];
  List<VerificationLine> lineItems = [];
  Map<String, num?> dashboard = {};
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

  Future<void> loadVerifications(ModuleAccess access) =>
      _load(() async => verifications = await _service.verifications(access));

  Future<void> loadLines(InventoryVerification verification) => _load(() async {
    lineItems = await _service.lineItems(verification);
    await _names(lineItems.map((verificationLine) => verificationLine.itemId));
  });

  Future<InventoryVerification?> verification(String id) async {
    try {
      return await _service.verification(id);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      return null;
    }
  }

  Future<void> loadDashboard(ModuleAccess access, {InventoryStore? store}) =>
      _load(
        () async => dashboard = await _service.dashboard(access, store: store),
      );

  /// Loads [def]; balance reports come back sorted by item name.
  Future<void> loadReport(
    ModuleAccess access,
    ReportDef def, {
    DateTime? from,
    DateTime? to,
    String? status,
  }) => _load(() async {
    rows = await _service.report(
      access,
      def,
      from: from,
      to: to,
      status: status,
    );
    await _names(rows.map((row) => row['itemId']));
    if (def.collection == 'inventoryBalances') {
      rows.sort(
        (currentData, data) =>
            itemName(currentData['itemId']).compareTo(itemName(data['itemId'])),
      );
    }
  });

  /// Saves counts directly to Firestore; false with [errorMessage] set on failure, false without it when only queued offline.
  Future<bool> saveCounts(
    InventoryVerification verification,
    List<(VerificationLine, num, String?)> counts,
  ) async {
    errorMessage = null;
    try {
      return await _service.saveCounts(verification, counts);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

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
