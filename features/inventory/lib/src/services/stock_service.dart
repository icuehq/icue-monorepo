import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_stock.dart';
import 'package:inventory/src/providers/list_state.dart';
import 'package:inventory/src/services/inventory_service.dart';

/// Stock (Inv-2): reads from Firestore, every write is a callable.
@lazySingleton
class StockService {
  StockService(this._inventory);

  /// Knows which stores a store manager works in.
  final InventoryService _inventory;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// Balances of [store], or of every store the user may see when [store] is null; [lowOnly] keeps those below their reorder level.
  Future<PagedResult<InventoryBalance>> balances(
    InventoryStore? store, {
    bool lowOnly = false,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'inventoryBalances',
    );
    if (store != null) {
      query = query.where('storeId', isEqualTo: store.id);
    } else {
      final assigned = await _inventory.assignedStoreIds();
      if (assigned != null) query = _inventory.inStores(query, assigned);
    }
    if (lowOnly) query = query.where('isBelowReorderLevel', isEqualTo: true);
    return fetchPage(
      query.orderBy('itemId'),
      (document) => InventoryBalance.fromMap(document.id, document.data()!),
      after: after,
      limit: 50,
    );
  }

  /// Text search over item name (`search` database, web only): the matching balances, read in full from Firestore.
  Future<({List<InventoryBalance> balances, bool hasMore})> searchBalances(
    String query, {
    InventoryStore? store,
    bool lowOnly = false,
    int offset = 0,
    int limit = 50,
  }) async {
    final page = await searchMirror(
      'inventoryBalances',
      query,
      sortField: 'itemName',
      equals: {
        if (store != null) 'storeId': store.id,
        if (lowOnly) 'isBelowReorderLevel': true,
      },
      offset: offset,
      limit: limit,
    );
    final assigned = await _inventory.assignedStoreIds();
    final ids = [
      for (final row in page.rows)
        if (assigned == null || assigned.contains(row.data['storeId'])) row.id,
    ];
    final collection = await branchCollection('inventoryBalances');
    final found = <String, InventoryBalance>{};
    for (var start = 0; start < ids.length; start += 30) {
      final snapshot = await collection
          .where(
            FieldPath.documentId,
            whereIn: ids.skip(start).take(30).toList(),
          )
          .get();
      for (final document in snapshot.docs) {
        found[document.id] = InventoryBalance.fromMap(
          document.id,
          document.data(),
        );
      }
    }
    return (
      balances: [
        for (final id in ids)
          if (found[id] != null) found[id]!,
      ],
      hasMore: page.hasMore,
    );
  }

  Future<List<InventoryMovement>> movements(InventoryBalance balance) async {
    final snapshot = await (await branchCollection('inventoryMovements'))
        .where('balanceId', isEqualTo: balance.id)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryMovement.fromMap(document.data()),
    ];
  }

  /// The branch's issue requests (approvers, stock users): [status] filter, request-number prefix [search].
  Future<ListQuery> requestsQuery(String? status, String search) async {
    ListQuery query = await branchCollection('inventoryIssueRequests');
    final assigned = await _inventory.assignedStoreIds();
    if (assigned != null) query = _inventory.inStores(query, assigned);
    return filteredQuery(query, status: status, search: search);
  }

  Future<InventoryIssueRequest?> requestById(String id) async {
    final document = await (await branchCollection('inventoryIssueRequests'))
        .doc(id)
        .get();
    final data = document.data();
    return data == null ? null : InventoryIssueRequest.fromMap(id, data);
  }

  Future<List<InventoryIssue>> issuesOf(
    InventoryIssueRequest issueRequest,
  ) async {
    final snapshot = await (await branchCollection('inventoryIssues'))
        .where('issueRequestId', isEqualTo: issueRequest.id)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryIssue.fromMap(document.id, document.data()),
    ];
  }

  /// Damaged / expired records, newest first: [status] filter and item-name [search] (the matching items' IDs, up to 30).
  Future<ListQuery> unavailableQuery(String? status, String search) async {
    ListQuery query = await branchCollection('inventoryUnavailableStock');
    if (status != null) query = query.where('status', isEqualTo: status);
    if (search.isEmpty) {
      final assigned = await _inventory.assignedStoreIds();
      if (assigned != null) query = _inventory.inStores(query, assigned);
    } else {
      // The matching items already belong to the user's stores (`searchItems`).
      final matches = await _inventory.searchItems(search, limit: 30);
      query = query.where(
        'itemId',
        whereIn: matches.items.isEmpty
            ? ['-']
            : [for (final item in matches.items) item.id],
      );
    }
    return query.orderBy('createdAt', descending: true);
  }

  /// Every store the user may see: all of the branch, or a store manager's own.
  Future<List<InventoryStore>> allStores() => _inventory.stores();

  /// Item docs by id (30 per Firestore `in` query).
  Future<Map<String, InventoryItem>> itemsByIds(Iterable<String> ids) async {
    final out = <String, InventoryItem>{};
    final list = ids.toSet().toList();
    for (var i = 0; i < list.length; i += 30) {
      final snapshot = await (await branchCollection('inventoryItems'))
          .where(FieldPath.documentId, whereIn: list.skip(i).take(30).toList())
          .get();
      for (final document in snapshot.docs) {
        out[document.id] = InventoryItem.fromMap(document.id, document.data());
      }
    }
    return out;
  }

  /// Calls [value] (e.g. `inventory-receipt-confirm`); [requestId] makes a retry idempotent.
  Future<Map<String, dynamic>> call(
    String value,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    final result = await callFunction(value, data: data, requestId: requestId);
    return result is Map ? Map<String, dynamic>.from(result) : {};
  }
}
