import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_stock.dart';

/// Stock (Inv-2): reads from Firestore, every write is a callable.
@lazySingleton
class StockService {
  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Future<PagedResult<InventoryBalance>> balances(
    InventoryStore store, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await schoolCollection('inventoryBalances'))
        .where('campusId', isEqualTo: store.campusId)
        .where('storeId', isEqualTo: store.id)
        .orderBy('itemId'),
    (document) => InventoryBalance.fromMap(document.id, document.data()!),
    after: after,
    limit: 50,
  );

  Future<List<InventoryMovement>> movements(
    InventoryBalance balance,
    int campusId,
  ) async {
    final snapshot = await (await schoolCollection('inventoryMovements'))
        .where('campusId', isEqualTo: campusId)
        .where('balanceId', isEqualTo: balance.id)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryMovement.fromMap(document.data()),
    ];
  }

  /// [mine]: the signed-in user's own requests; otherwise the campus's (approvers, stock users).
  Future<List<InventoryIssueRequest>> requests(
    ModuleAccess access, {
    required bool mine,
    String? status,
  }) async {
    final base = await schoolCollection('inventoryIssueRequests');
    var query = mine
        ? base.where('createdBy', isEqualTo: uid)
        : access.restrictToCampuses(base);
    if (query == null) return [];
    if (status != null) query = query.where('status', isEqualTo: status);
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryIssueRequest.fromMap(document.id, document.data()),
    ];
  }

  Future<InventoryIssueRequest?> requestById(String id) async {
    final document = await (await schoolCollection('inventoryIssueRequests'))
        .doc(id)
        .get();
    final data = document.data();
    return data == null ? null : InventoryIssueRequest.fromMap(id, data);
  }

  Future<List<InventoryIssue>> issuesOf(
    InventoryIssueRequest issueRequest,
  ) async {
    final snapshot = await (await schoolCollection('inventoryIssues'))
        .where('campusId', isEqualTo: issueRequest.campusId)
        .where('issueRequestId', isEqualTo: issueRequest.id)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryIssue.fromMap(document.id, document.data()),
    ];
  }

  Future<List<InventoryUnavailable>> unavailable(ModuleAccess access) async {
    final query = access
        .restrictToCampuses(await schoolCollection('inventoryUnavailableStock'))
        ?.where('status', whereIn: ['open', 'in_repair']);
    if (query == null) return [];
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryUnavailable.fromMap(document.id, document.data()),
    ];
  }

  /// Every store in the school (transfer destinations may be on another campus).
  Future<List<InventoryStore>> allStores() async {
    final snapshot = await (await schoolCollection('inventoryStores')).get();
    return [
      for (final document in snapshot.docs)
        InventoryStore.fromMap(document.id, document.data()),
    ]..sort((left, right) => left.name.compareTo(right.name));
  }

  /// Item docs by id (30 per Firestore `in` query).
  Future<Map<String, InventoryItem>> itemsByIds(Iterable<String> ids) async {
    final out = <String, InventoryItem>{};
    final list = ids.toSet().toList();
    for (var i = 0; i < list.length; i += 30) {
      final snapshot = await (await schoolCollection('inventoryItems'))
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
