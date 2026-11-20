import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// Inventory masters: reads and master writes go to Firestore; defaults seed through a callable.
@lazySingleton
class InventoryService {
  // A store manager works only in the stores assigned to them (`inventoryStores/{id}.managerId`); everyone else sees all.
  String? _userId;
  bool _restricted = false;
  List<InventoryStore>? _assigned;

  /// Set on sign-in. A [restricted] user reads only stores whose manager is [userId], and every list is
  /// narrowed to those stores.
  void scopeTo({required String? userId, required bool restricted}) {
    _userId = userId;
    _restricted = restricted;
    _assigned = null;
  }

  bool get restricted => _restricted;

  /// The IDs of the stores a restricted user works in; null for everyone else (no narrowing).
  Future<List<String>?> assignedStoreIds() async => _restricted
      ? [for (final store in _assigned ?? await stores()) store.id]
      : null;

  /// `storeId` equals or is one of [ids] (Firestore allows 30 values); a user with no store matches nothing.
  Query<Map<String, dynamic>> inStores(
    Query<Map<String, dynamic>> query,
    List<String> ids,
  ) => ids.length == 1
      ? query.where('storeId', isEqualTo: ids.single)
      : query.where(
          'storeId',
          whereIn: ids.isEmpty ? ['-'] : ids.take(30).toList(),
        );

  Future<List<T>> _all<T>(
    String path,
    T Function(String id, Map<String, dynamic> data) parse,
  ) async {
    final snapshot = await (await branchCollection(path)).get();
    return [
      for (final document in snapshot.docs) parse(document.id, document.data()),
    ];
  }

  /// [documents] newest first; a just-written one has no server time yet, so it sorts first.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _newestFirst(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) => [...documents]
    ..sort((left, right) {
      final leftAt = left.data()['createdAt'] as Timestamp?;
      final rightAt = right.data()['createdAt'] as Timestamp?;
      if (leftAt == null || rightAt == null) {
        return leftAt == rightAt ? 0 : (leftAt == null ? -1 : 1);
      }
      return rightAt.compareTo(leftAt);
    });

  /// Categories newest first; search and filters run in the client.
  Future<List<InventoryCategory>> categories() async {
    final assigned = await assignedStoreIds();
    final snapshot = await (await branchCollection('inventoryCategories'))
        .get();
    return [
      for (final document in _newestFirst(snapshot.docs))
        if (assigned == null || assigned.contains(document.data()['storeId']))
          InventoryCategory.fromMap(document.id, document.data()),
    ];
  }

  /// Units newest first; search and filters run in the client.
  Future<List<InventoryUnit>> units() async {
    final assigned = await assignedStoreIds();
    final snapshot = await (await branchCollection('inventoryUnits')).get();
    return [
      for (final document in _newestFirst(snapshot.docs))
        if (assigned == null || assigned.contains(document.data()['storeId']))
          InventoryUnit.fromMap(document.id, document.data()),
    ];
  }

  /// Stores of the branch; a store manager gets only their own.
  Future<List<InventoryStore>> stores() async {
    final collection = await branchCollection('inventoryStores');
    final snapshot =
        await (_restricted
                ? collection.where('managerId', isEqualTo: _userId)
                : collection)
            .get();
    final stores = [
      for (final document in _newestFirst(snapshot.docs))
        InventoryStore.fromMap(document.id, document.data()),
    ];
    if (_restricted) _assigned = stores;
    return stores;
  }

  Future<Query<Map<String, dynamic>>> _itemsQuery({
    String? categoryId,
    String? storeId,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'inventoryItems',
    );
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    final assigned = storeId != null ? [storeId] : await assignedStoreIds();
    if (assigned != null) query = inStores(query, assigned);
    return query.orderBy('createdAt', descending: true);
  }

  /// A page of items, newest first, optionally within [categoryId] (Firestore query).
  Future<PagedResult<InventoryItem>> items({
    String? categoryId,
    String? storeId,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    await _itemsQuery(categoryId: categoryId, storeId: storeId),
    (document) => InventoryItem.fromMap(document.id, document.data()!),
    after: after,
  );

  /// Text search: whole words and typed prefixes through the `search` database on web; elsewhere (no text search)
  /// the items are read and matched by name in the client, so it fits a few thousand items.
  Future<({List<InventoryItem> items, bool hasMore})> searchItems(
    String query, {
    String? categoryId,
    int offset = 0,
    int limit = 25,
  }) async {
    if (!textSearchSupported) {
      final needle = query.trim().toLowerCase();
      final snapshot = await (await _itemsQuery(categoryId: categoryId)).get();
      final matches = [
        for (final document in snapshot.docs)
          if ('${document.data()['name']}'.toLowerCase().contains(needle))
            InventoryItem.fromMap(document.id, document.data()),
      ];
      return (
        items: matches.skip(offset).take(limit).toList(),
        hasMore: matches.length > offset + limit,
      );
    }
    final assigned = await assignedStoreIds();
    final page = await searchMirror(
      'inventoryItems',
      query,
      sortField: 'createdAt',
      descending: true,
      categoryIds: categoryId == null ? null : [categoryId],
      offset: offset,
      limit: limit,
    );
    return (
      items: [
        for (final row in page.rows)
          if (assigned == null || assigned.contains(row.data['storeId']))
            InventoryItem.fromMap(row.id, row.data),
      ],
      hasMore: page.hasMore,
    );
  }

  /// How many of each item are in stock: the available balances of counted items, the assets still in use for individually tracked ones.
  Future<Map<String, double>> inStock(Iterable<InventoryItem> items) async {
    final totals = {for (final item in items) item.id: 0.0};
    final counted = [
      for (final item in items)
        if (item.tracking != Tracking.asset) item.id,
    ];
    final tracked = [
      for (final item in items)
        if (item.tracking == Tracking.asset) item.id,
    ];
    for (var start = 0; start < counted.length; start += 30) {
      final balances = await (await branchCollection('inventoryBalances'))
          .where('itemId', whereIn: counted.skip(start).take(30).toList())
          .get();
      for (final balance in balances.docs) {
        final data = balance.data();
        totals[data['itemId'] as String] =
            totals[data['itemId']]! + readDouble(data['quantityAvailable']);
      }
    }
    for (var start = 0; start < tracked.length; start += 30) {
      final assets = await (await branchCollection('inventoryAssets'))
          .where('itemId', whereIn: tracked.skip(start).take(30).toList())
          .get();
      for (final asset in assets.docs) {
        final data = asset.data();
        if (data['status'] == 'retired' || data['status'] == 'disposed') {
          continue;
        }
        totals[data['itemId'] as String] = totals[data['itemId']]! + 1;
      }
    }
    return totals;
  }

  Future<InventoryItem?> item(String id) async {
    final document = await (await branchCollection('inventoryItems'))
        .doc(id)
        .get();
    return document.exists
        ? InventoryItem.fromMap(document.id, document.data()!)
        : null;
  }

  Future<List<InventoryVariant>> variants(String itemId) async =>
      (await _all('inventoryItems/$itemId/variants', InventoryVariant.fromMap))
        ..sort((left, right) => left.sku.compareTo(right.sku));

  // --- writes: masters are plain client CRUD (`firestore.rules`); defaults seed through a callable ---

  Future<void> seedDefaults() => _call('inventory-seedDefaults', {});

  Future<void> saveCategory(Map<String, Object?> data) =>
      saveMasterDocument('inventoryCategories', data);

  Future<void> setCategoryActive(String id, {required bool active}) =>
      setMasterActive('inventoryCategories', id, active: active);

  /// Units have no code: a new unit gets the Firestore auto ID and items store its name.
  /// Renaming a unit renames it on the store's items too, so they keep pointing at it.
  Future<void> saveUnit({
    required String storeId,
    required String name,
    InventoryUnit? unit,
  }) async {
    if (unit == null) {
      await saveMasterDocument('inventoryUnits', {
        'storeId': storeId,
        'name': name,
      });
      return;
    }
    await saveMasterDocument('inventoryUnits', {'id': unit.id, 'name': name});
    if (unit.name == name) return;
    final items = await (await branchCollection('inventoryItems'))
        .where('storeId', isEqualTo: storeId)
        .where('stockUnit', isEqualTo: unit.name)
        .get();
    for (var start = 0; start < items.docs.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in items.docs.skip(start).take(400)) {
        batch.update(item.reference, {
          'stockUnit': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> saveItem(Map<String, Object?> data) =>
      saveMasterDocument('inventoryItems', data, onCreate: {'imagePath': null});

  Future<void> setItemActive(String id, {required bool active}) =>
      setMasterActive('inventoryItems', id, active: active);

  Future<void> saveVariant(Map<String, Object?> data) {
    final fields = {...data};
    final itemId = fields.remove('itemId')! as String;
    return saveMasterDocument('inventoryItems/$itemId/variants', {
      ...fields,
      'itemId': itemId,
      if (fields['code'] != null) 'sku': fields['code'],
    });
  }

  /// Stores have no code: a new store gets the Firestore auto ID.
  Future<void> saveStore(Map<String, Object?> data) async {
    final fields = {...data};
    final id = fields.remove('id') as String?;
    final collection = await branchCollection('inventoryStores');
    final now = FieldValue.serverTimestamp();
    if (id != null) {
      await collection.doc(id).update({...fields, 'updatedAt': now});
      return;
    }
    await collection.add({
      'status': 'active',
      ...fields,
      'createdBy': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> setStoreActive(String id, {required bool active}) =>
      setMasterActive('inventoryStores', id, active: active);

  Future<void> _call(
    String name,
    Map<String, Object?> data, [
    String? requestId,
  ]) async {
    await callFunction(name, data: data, requestId: requestId);
  }
}
