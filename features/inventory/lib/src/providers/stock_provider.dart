import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/models/inv_stock.dart';
import 'package:inventory/src/services/stock_service.dart';

/// Stock lists and actions. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class StockProvider extends ChangeNotifier {
  StockProvider(this._service);

  final StockService _service;

  /// Item names for every id seen in a list (balances, requests, transfers…).
  final Map<String, InvItem> items = {};
  String? errorMessage;
  bool isLoading = false;

  InvStore? store;
  final List<InvBalance> balances = [];
  bool hasMoreBalances = false;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  List<InvIssueRequest> requests = [];
  List<InvTransfer> transfers = [];
  List<InvUnavailable> unavailable = [];
  List<InvStore> allStores = [];

  String get uid => _service.uid;

  String itemName(String id, [String? variantId]) => items[id]?.name ?? id;

  Future<T?> _load<T>(Future<T> Function() body) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await body();
    } catch (e) {
      errorMessage = _message(e);
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _names(Iterable<String> ids) async {
    final need = ids.where((i) => !items.containsKey(i));
    if (need.isNotEmpty) items.addAll(await _service.itemsByIds(need));
  }

  Future<void> loadBalances(InvStore s, {bool more = false}) async {
    if (isLoading || (more && !hasMoreBalances)) return;
    if (!more) {
      store = s;
      _cursor = null;
    }
    await _load(() async {
      final page = await _service.balances(s, after: _cursor);
      if (!more) balances.clear();
      balances.addAll(page.items);
      _cursor = page.cursor;
      hasMoreBalances = page.hasMore;
      await _names(page.items.map((b) => b.itemId));
    });
  }

  Future<List<InvMovement>> movements(InvBalance b) async =>
      (await _load(() => _service.movements(b, store!.campusId))) ?? [];

  Future<void> loadRequests(InvAccess a, {String? status}) => _load(() async {
    requests = await _service.requests(a, status: status);
    await _names(requests.expand((r) => r.lines.map((l) => l.itemId)));
  });

  Future<void> loadAllStores() async {
    if (allStores.isNotEmpty) return;
    await _load(() async => allStores = await _service.allStores());
  }

  Future<List<InvIssue>> issuesOf(InvIssueRequest r) async =>
      (await _load(() => _service.issuesOf(r))) ?? [];

  Future<void> loadTransfers(InvAccess a) => _load(() async {
    transfers = await _service.transfers(a);
    await _names(transfers.expand((t) => t.requested.map((l) => l.itemId)));
  });

  Future<void> loadUnavailable(InvAccess a) => _load(() async {
    unavailable = await _service.unavailable(a);
    await _names(unavailable.map((u) => u.itemId));
  });

  /// Runs a callable; returns its result (`id`, `number`) or null with [errorMessage] set.
  Future<Map<String, dynamic>?> act(
    String fn,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return await _service.call(fn, data, requestId: requestId);
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
      return null;
    }
  }

  String _message(Object e) =>
      e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();
}
