import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_stock.dart';
import 'package:inventory/src/providers/list_state.dart';
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

  /// The store whose balances are shown; null means all stores (once [balancesLoaded]).
  InventoryStore? store;
  bool balancesLoaded = false;

  /// Server-side filters of the balances: text search (web only) and low stock.
  String balanceSearch = '';
  bool lowOnly = false;
  int _searchOffset = 0;
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

  /// Damaged / expired stock (all statuses at first): server-side status filter, item-name search, paging.
  late final unavailableRecords = ListState<InventoryUnavailable>(
    query: _service.unavailableQuery,
    fromDocument: (document) =>
        InventoryUnavailable.fromMap(document.id, document.data()!),
    onChange: notifyListeners,
    afterPage: (records) => _names(records.map((record) => record.itemId)),
  );
  List<InventoryStore> allStores = [];

  String get uid => _service.uid;

  String itemName(String id, [String? variantId]) => items[id]?.name ?? id;

  /// The newest pending issue requests (dashboard), with their item names loaded.
  Future<List<InventoryIssueRequest>> pendingRequests({int limit = 5}) async {
    final snapshot = await (await _service.requestsQuery(
      'pending',
      '',
    )).limit(limit).get();
    final requests = [
      for (final document in snapshot.docs)
        InventoryIssueRequest.fromMap(document.id, document.data()),
    ];
    await _names(
      requests.expand(
        (request) => request.lineItems.map((line) => line.itemId),
      ),
    );
    notifyListeners();
    return requests;
  }

  Future<void> _names(Iterable<String> ids) async {
    final need = ids.where((i) => !items.containsKey(i));
    if (need.isNotEmpty) items.addAll(await _service.itemsByIds(need));
  }

  var _balancesLoad = 0;

  /// Reloads the shown store's balances (or all stores'), once they have been loaded.
  Future<void> reloadBalances() async {
    if (balancesLoaded) await loadBalances(store);
  }

  Future<void> loadMoreBalances() async {
    if (balancesLoaded) await loadBalances(store, more: true);
  }

  /// Loads the balances of [store] (null: every store's), keeping the current search and low-stock filters unless given.
  Future<void> loadBalances(
    InventoryStore? store, {
    bool more = false,
    String? search,
    bool? lowOnly,
  }) async {
    if (more && (isLoading || !hasMoreBalances)) return;
    final load = ++_balancesLoad;
    if (!more) {
      this.store = store;
      balancesLoaded = true;
      balanceSearch = search?.trim() ?? balanceSearch;
      this.lowOnly = lowOnly ?? this.lowOnly;
      _cursor = null;
      _searchOffset = 0;
    }
    final query = balanceSearch;
    await run(() async {
      final List<InventoryBalance> rows;
      if (query.isEmpty) {
        final page = await _service.balances(
          this.store,
          lowOnly: this.lowOnly,
          after: _cursor,
        );
        _cursor = page.cursor;
        hasMoreBalances = page.hasMore;
        rows = page.items;
      } else {
        final page = await _service.searchBalances(
          query,
          store: this.store,
          lowOnly: this.lowOnly,
          offset: _searchOffset,
        );
        _searchOffset += page.balances.length;
        hasMoreBalances = page.hasMore;
        rows = page.balances;
      }
      if (load != _balancesLoad) return;
      if (!more) balances.clear();
      balances.addAll(rows);
      await _names(rows.map((balance) => balance.itemId));
    });
  }

  Future<List<InventoryMovement>> movements(InventoryBalance balance) async =>
      (await run(() => _service.movements(balance), quiet: true)) ?? [];

  /// One request, fresh from Firestore; also refreshes its row in [issueRequests].
  Future<InventoryIssueRequest?> loadRequest(String id) async {
    final loaded = await run(() async {
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
    await run(() async => allStores = await _service.allStores());
  }

  Future<List<InventoryIssue>> issuesOf(
    InventoryIssueRequest issueRequest,
  ) async =>
      (await run(() => _service.issuesOf(issueRequest), quiet: true)) ?? [];

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
