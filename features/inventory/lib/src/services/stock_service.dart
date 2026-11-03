import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_stock.dart';

/// Stock (Inv-2): reads from Firestore, every write is a callable.
@lazySingleton
class StockService {
  Future<Query<Map<String, dynamic>>> _q(String path) async {
    final claims =
        (await FirebaseAuth.instance.currentUser!.getIdTokenResult()).claims;
    return FirebaseFirestore.instance.collection(
      'schools/${claims?['schoolId']}/$path',
    );
  }

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// Rules require the campus filter on every list (`all` users need none).
  Query<Map<String, dynamic>>? _scoped(
    Query<Map<String, dynamic>> query,
    ModuleAccess access, [
    String field = 'campusId',
  ]) {
    return access.restrictToCampuses(query, field: field);
  }

  Future<PagedResult<InventoryBalance>> balances(
    InventoryStore store, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await _q('inventoryBalances'))
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
    final snapshot = await (await _q('inventoryMovements'))
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

  /// Approvers and stock users see the campus's requests; everyone else their own.
  Future<List<InventoryIssueRequest>> requests(
    ModuleAccess access, {
    String? status,
  }) async {
    final base = await _q('inventoryIssueRequests');
    final wide =
        access.can('inventory.stock.view') ||
        access.can('inventory.issue.approve');
    var query = wide
        ? _scoped(base, access)
        : base.where('createdBy', isEqualTo: uid);
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
    final snapshot = await (await _q('inventoryIssues'))
        .where('campusId', isEqualTo: issueRequest.campusId)
        .where('issueRequestId', isEqualTo: issueRequest.id)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryIssue.fromMap(document.id, document.data()),
    ];
  }

  /// Transfers leaving or arriving on the user's campuses.
  Future<List<InventoryTransfer>> transfers(ModuleAccess access) async {
    final base = await _q('inventoryTransfers');
    final queries = [
      _scoped(base, access),
      if (!access.hasAllCampuses) _scoped(base, access, 'toCampusId'),
    ];
    final byId = <String, InventoryTransfer>{};
    for (final query in queries.whereType<Query<Map<String, dynamic>>>()) {
      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      for (final document in snapshot.docs) {
        byId[document.id] = InventoryTransfer.fromMap(
          document.id,
          document.data(),
        );
      }
    }
    return byId.values.toList()..sort(
      (currentTransfer, transfer) => (transfer.createdAt ?? DateTime(0))
          .compareTo(currentTransfer.createdAt ?? DateTime(0)),
    );
  }

  Future<List<InventoryUnavailable>> unavailable(ModuleAccess access) async {
    final query = _scoped(
      await _q('inventoryUnavailableStock'),
      access,
    )?.where('status', whereIn: ['open', 'in_repair']);
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
    final snapshot = await (await _q('inventoryStores')).get();
    return [
      for (final document in snapshot.docs)
        InventoryStore.fromMap(document.id, document.data()),
    ]..sort((left, right) => left.code.compareTo(right.code));
  }

  /// Item docs by id (30 per Firestore `in` query).
  Future<Map<String, InventoryItem>> itemsByIds(Iterable<String> ids) async {
    final out = <String, InventoryItem>{};
    final list = ids.toSet().toList();
    for (var i = 0; i < list.length; i += 30) {
      final snapshot = await (await _q('inventoryItems'))
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
