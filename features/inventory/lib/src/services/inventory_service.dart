import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// Inventory masters: reads and master writes go to Firestore; defaults seed through a callable.
@lazySingleton
class InventoryService {
  Future<List<T>> _all<T>(
    String path,
    T Function(String id, Map<String, dynamic> data) parse,
  ) async {
    final snapshot = await (await branchCollection(path)).get();
    return [
      for (final document in snapshot.docs) parse(document.id, document.data()),
    ];
  }

  Future<ModuleAccess> access() async {
    // branchCollection waits for the sign-in, so read the user after it.
    final collection = await branchCollection('userAccess');
    final doc = await collection
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    return ModuleAccess.fromMap(doc.data() ?? {});
  }

  Future<List<InventoryCategory>> categories() async =>
      (await _all('inventoryCategories', InventoryCategory.fromMap))
        ..sort((left, right) => left.code.compareTo(right.code));

  Future<List<InventoryUnit>> units() async => (await _all(
    'inventoryUnits',
    (id, data) => InventoryUnit.fromMap(id, data),
  ))..sort((left, right) => left.code.compareTo(right.code));

  /// Stores of the branch.
  Future<List<InventoryStore>> stores() async {
    final snapshot = await (await branchCollection('inventoryStores')).get();
    return [
      for (final document in snapshot.docs)
        InventoryStore.fromMap(document.id, document.data()),
    ]..sort((left, right) => left.name.compareTo(right.name));
  }

  /// A page of items by name, optionally within [categoryId] (Firestore query).
  Future<PagedResult<InventoryItem>> items({
    String? categoryId,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'inventoryItems',
    );
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    return fetchPage(
      query.orderBy('name'),
      (document) => InventoryItem.fromMap(document.id, document.data()!),
      after: after,
    );
  }

  /// Whole-word text search (`search` database, web only); rows carry the list fields only.
  Future<({List<InventoryItem> items, bool hasMore})> searchItems(
    String query, {
    String? categoryId,
    int offset = 0,
    int limit = 25,
  }) async {
    final page = await searchMirror(
      'inventoryItems',
      query,
      sortField: 'name',
      categoryIds: categoryId == null ? null : [categoryId],
      offset: offset,
      limit: limit,
    );
    return (
      items: [
        for (final row in page.rows) InventoryItem.fromMap(row.id, row.data),
      ],
      hasMore: page.hasMore,
    );
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

  Future<void> saveUnit(String code, String name) async {
    final collection = await branchCollection('inventoryUnits');
    final exists =
        (await collection.doc(code.trim().toLowerCase()).get()).exists;
    await saveMasterDocument('inventoryUnits', {
      if (exists) 'id': code.trim().toLowerCase() else 'code': code,
      'name': name,
    });
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
