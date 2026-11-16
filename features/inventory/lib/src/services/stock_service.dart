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

  Future<PagedResult<InventoryBalance>> balances(
    InventoryStore store, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await branchCollection('inventoryBalances'))
        .where('storeId', isEqualTo: store.id)
        .orderBy('itemId'),
    (document) => InventoryBalance.fromMap(document.id, document.data()!),
    after: after,
    limit: 50,
  );

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

  Future<List<InventoryUnavailable>> unavailable() async {
    var query = (await branchCollection('inventoryUnavailableStock'))
        .where('status', whereIn: ['open', 'in_repair']);
    final assigned = await _inventory.assignedStoreIds();
    if (assigned != null) query = _inventory.inStores(query, assigned);
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryUnavailable.fromMap(document.id, document.data()),
    ];
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
