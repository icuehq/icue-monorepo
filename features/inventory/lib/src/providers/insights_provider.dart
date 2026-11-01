import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_insights.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/services/insights_service.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Verification sessions, dashboard and reports. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class InsightsProvider extends ChangeNotifier {
  InsightsProvider(this._service, this._stock);

  final InsightsService _service;
  final StockService _stock;

  List<InvVerification> verifications = [];
  List<VerificationLine> lines = [];
  Map<String, num?> dashboard = {};
  List<ReportRow> rows = [];
  final Map<String, InvItem> items = {};
  String? errorMessage;
  bool isLoading = false;

  String itemName(Object? id) => items[id]?.name ?? '$id';

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

  Future<void> _names(Iterable<Object?> itemIds) async {
    final need = {
      for (final i in itemIds)
        if (i is String && !items.containsKey(i)) i,
    };
    if (need.isNotEmpty) items.addAll(await _stock.itemsByIds(need));
  }

  Future<void> loadVerifications(InvAccess a) =>
      _load(() async => verifications = await _service.verifications(a));

  Future<void> loadLines(InvVerification v) => _load(() async {
    lines = await _service.lines(v);
    await _names(lines.map((l) => l.itemId));
  });

  Future<InvVerification?> verification(String id) async {
    try {
      return await _service.verification(id);
    } catch (e) {
      errorMessage = _message(e);
      return null;
    }
  }

  Future<void> loadDashboard(InvAccess a, {InvStore? store}) =>
      _load(() async => dashboard = await _service.dashboard(a, store: store));

  /// Loads [def]; balance reports come back sorted by item name.
  Future<void> loadReport(
    InvAccess a,
    ReportDef def, {
    DateTime? from,
    DateTime? to,
    String? status,
  }) => _load(() async {
    rows = await _service.report(a, def, from: from, to: to, status: status);
    await _names(rows.map((r) => r['itemId']));
    if (def.collection == 'invBalances') {
      rows.sort(
        (x, y) => itemName(x['itemId']).compareTo(itemName(y['itemId'])),
      );
    }
  });

  /// Saves counts directly to Firestore; false with [errorMessage] set on failure, false without it when only queued offline.
  Future<bool> saveCounts(
    InvVerification v,
    List<(VerificationLine, num, String?)> counts,
  ) async {
    errorMessage = null;
    try {
      return await _service.saveCounts(v, counts);
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
      return false;
    }
  }

  /// Runs a callable; returns its result or null with [errorMessage] set.
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
