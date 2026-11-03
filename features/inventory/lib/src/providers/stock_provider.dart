import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_stock.dart';
import 'package:inventory/src/services/stock_service.dart';
import 'package:inventory/src/services/stock_writes.dart';

/// Stock lists and actions. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class StockProvider extends ChangeNotifier {
  StockProvider(this._service);

  final StockService _service;
  final _writes = StockWrites();

  /// Item names for every id seen in a list (balances, requests, transfers…).
  final Map<String, InventoryItem> items = {};
  String? errorMessage;
  bool isLoading = false;

  InventoryStore? store;
  final List<InventoryBalance> balances = [];
  bool hasMoreBalances = false;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  List<InventoryIssueRequest> requests = [];
  List<InventoryTransfer> transfers = [];
  List<InventoryUnavailable> unavailable = [];
  List<InventoryStore> allStores = [];

  String get uid => _service.uid;

  String itemName(String id, [String? variantId]) => items[id]?.name ?? id;

  /// [quiet] skips the loading notifications, for fetches triggered from a widget's build (FutureBuilder).
  Future<T?> _load<T>(Future<T> Function() body, {bool quiet = false}) async {
    if (!quiet) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      return await body();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      return null;
    } finally {
      if (!quiet) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _names(Iterable<String> ids) async {
    final need = ids.where((i) => !items.containsKey(i));
    if (need.isNotEmpty) items.addAll(await _service.itemsByIds(need));
  }

  var _balancesLoad = 0;

  Future<void> loadBalances(InventoryStore store, {bool more = false}) async {
    if (more && (isLoading || !hasMoreBalances)) return;
    final load = ++_balancesLoad;
    if (!more) {
      this.store = store;
      _cursor = null;
    }
    await _load(() async {
      final page = await _service.balances(store, after: _cursor);
      if (load != _balancesLoad) return;
      if (!more) balances.clear();
      balances.addAll(page.items);
      _cursor = page.cursor;
      hasMoreBalances = page.hasMore;
      await _names(page.items.map((balance) => balance.itemId));
    });
  }

  Future<List<InventoryMovement>> movements(InventoryBalance balance) async =>
      (await _load(
        () => _service.movements(balance, store!.campusId),
        quiet: true,
      )) ??
      [];

  var _requestsLoad = 0;

  /// Newer calls win, so quickly switching a status filter never shows an older answer.
  Future<void> loadRequests(ModuleAccess access, {String? status}) {
    final load = ++_requestsLoad;
    return _load(() async {
      final loaded = await _service.requests(access, status: status);
      await _names(
        loaded.expand(
          (issueRequest) =>
              issueRequest.lineItems.map((requestLine) => requestLine.itemId),
        ),
      );
      if (load == _requestsLoad) requests = loaded;
    });
  }

  /// One request, fresh from Firestore; also refreshes its row in [requests].
  Future<InventoryIssueRequest?> loadRequest(String id) async {
    final loaded = await _load(() async {
      final request = await _service.requestById(id);
      if (request == null) {
        errorMessage = 'Request not found';
        return null;
      }
      await _names(request.lineItems.map((requestLine) => requestLine.itemId));
      final index = requests.indexWhere((existing) => existing.id == id);
      if (index >= 0) requests[index] = request;
      return request;
    }, quiet: true);
    return loaded;
  }

  Future<void> loadAllStores() async {
    if (allStores.isNotEmpty) return;
    await _load(() async => allStores = await _service.allStores());
  }

  Future<List<InventoryIssue>> issuesOf(
    InventoryIssueRequest issueRequest,
  ) async =>
      (await _load(() => _service.issuesOf(issueRequest), quiet: true)) ?? [];

  Future<void> loadTransfers(ModuleAccess access) => _load(() async {
    transfers = await _service.transfers(access);
    await _names(
      transfers.expand(
        (transfer) => transfer.requested.map((line) => line.itemId),
      ),
    );
  });

  Future<void> loadUnavailable(ModuleAccess access) => _load(() async {
    unavailable = await _service.unavailable(access);
    await _names(unavailable.map((unavailable) => unavailable.itemId));
  });

  /// Runs a client write (Receive Stock) or else a callable; returns its result (`id`, `number`) or null with [errorMessage] set.
  Future<Map<String, dynamic>?> act(
    String value,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return StockWrites.names.contains(value)
          ? await _writes.run(value, data)
          : await _service.call(value, data, requestId: requestId);
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return null;
    }
  }
}
