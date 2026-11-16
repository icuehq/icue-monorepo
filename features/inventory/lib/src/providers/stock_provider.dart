import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_stock.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/providers/loading_provider.dart';
import 'package:inventory/src/services/stock_service.dart';
import 'package:inventory/src/services/stock_writes.dart';

/// Stock lists and actions. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class StockProvider extends LoadingProvider {
  StockProvider(this._service);

  final StockService _service;
  final _writes = StockWrites();

  /// Item names for every id seen in a list (balances, requests…).
  final Map<String, InventoryItem> items = {};

  InventoryStore? store;
  final List<InventoryBalance> balances = [];
  bool hasMoreBalances = false;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  /// Issue requests: server-side status filter, request-number search, paging.
  late final issueRequests = ListState<InventoryIssueRequest>(
    query: _service.requestsQuery,
    fromDocument: (document) =>
        InventoryIssueRequest.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
    afterPage: (requests) => _names(
      requests.expand(
        (issueRequest) =>
            issueRequest.lineItems.map((requestLine) => requestLine.itemId),
      ),
    ),
  );
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
      (await _load(() => _service.movements(balance), quiet: true)) ?? [];

  /// One request, fresh from Firestore; also refreshes its row in [issueRequests].
  Future<InventoryIssueRequest?> loadRequest(String id) async {
    final loaded = await _load(() async {
      final request = await _service.requestById(id);
      if (request == null) {
        errorMessage = 'Request not found';
        return null;
      }
      await _names(request.lineItems.map((requestLine) => requestLine.itemId));
      final rows = issueRequests.pager.items;
      final index = rows.indexWhere((existing) => existing.id == id);
      if (index >= 0) rows[index] = request;
      return request;
    }, quiet: true);
    return loaded;
  }

  Future<void> loadAllStores() async {
    await _load(() async => allStores = await _service.allStores());
  }

  Future<List<InventoryIssue>> issuesOf(
    InventoryIssueRequest issueRequest,
  ) async =>
      (await _load(() => _service.issuesOf(issueRequest), quiet: true)) ?? [];

  Future<void> loadUnavailable() => _load(() async {
    unavailable = await _service.unavailable();
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
