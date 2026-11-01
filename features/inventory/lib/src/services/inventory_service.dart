import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_masters.dart';

/// Inventory masters: reads from Firestore, writes through callables.
@lazySingleton
class InventoryService {
  Future<CollectionReference<Map<String, dynamic>>> _coll(String path) async {
    final user = FirebaseAuth.instance.currentUser!;
    final sid = (await user.getIdTokenResult()).claims?['sid'];
    return FirebaseFirestore.instance.collection('schools/$sid/$path');
  }

  Future<List<T>> _all<T>(
    String path,
    T Function(String id, Map<String, dynamic> m) parse,
  ) async {
    final snap = await (await _coll(path)).get();
    return [for (final d in snap.docs) parse(d.id, d.data())];
  }

  Future<InvAccess> access() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await (await _coll('userAccess')).doc(user.uid).get();
    return InvAccess.fromMap(doc.data() ?? {});
  }

  Future<List<InvCategory>> categories() async =>
      (await _all('invCategories', InvCategory.fromMap))
        ..sort((a, b) => a.code.compareTo(b.code));

  Future<List<InvUnit>> units() async =>
      (await _all('invUnits', (id, m) => InvUnit.fromMap(id, m)))
        ..sort((a, b) => a.code.compareTo(b.code));

  /// Stores on the user's campuses (rules reject unfiltered lists).
  Future<List<InvStore>> stores(InvAccess access) async {
    final coll = await _coll('invStores');
    if (!access.all && access.campuses.isEmpty) return [];
    final snap =
        await (access.all
                ? coll
                : coll.where('campusId', whereIn: access.campuses))
            .get();
    return [for (final d in snap.docs) InvStore.fromMap(d.id, d.data())]
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  /// A page of items by name, optionally within [categoryId] (Firestore query).
  Future<PagedResult<InvItem>> items({
    String? categoryId,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> q = await _coll('invItems');
    if (categoryId != null) q = q.where('categoryId', isEqualTo: categoryId);
    return fetchPage(
      q.orderBy('name'),
      (d) => InvItem.fromMap(d.id, d.data()!),
      after: after,
    );
  }

  /// Whole-word text search (Functions, `search` database); rows carry the list fields only.
  Future<({List<InvItem> items, bool hasMore})> searchItems(
    String query, {
    String? categoryId,
    int offset = 0,
    int limit = 25,
  }) async {
    final res = await callFunction(
      'inv-item-search',
      data: {
        'q': query,
        'categoryId': ?categoryId,
        'offset': offset,
        'limit': limit,
      },
    ) as Map<Object?, Object?>;
    return (
      items: [
        for (final r in res['items']! as List<Object?>)
          InvItem.fromMap(
            (r! as Map)['id'] as String,
            Map<String, dynamic>.from(r as Map),
          ),
      ],
      hasMore: res['hasMore'] == true,
    );
  }

  Future<InvItem?> item(String id) async {
    final d = await (await _coll('invItems')).doc(id).get();
    return d.exists ? InvItem.fromMap(d.id, d.data()!) : null;
  }

  Future<List<InvVariant>> variants(String itemId) async =>
      (await _all('invItems/$itemId/variants', InvVariant.fromMap))
        ..sort((a, b) => a.sku.compareTo(b.sku));

  // --- writes: callables, same requestId on user retry --------------------

  Future<void> seedDefaults() => _call('inv-seedDefaults', {});

  Future<void> saveCategory(Map<String, Object?> data, {String? requestId}) =>
      _call('inv-category-upsert', data, requestId);

  Future<void> setCategoryActive(String id, {required bool active}) =>
      _call('inv-category-setStatus', _status(id, active));

  Future<void> saveUnit(String code, String name) =>
      _call('inv-unit-upsert', {'code': code, 'name': name});

  Future<void> saveItem(Map<String, Object?> data, {String? requestId}) =>
      _call('inv-item-upsert', data, requestId);

  Future<void> setItemActive(String id, {required bool active}) =>
      _call('inv-item-setStatus', _status(id, active));

  Future<void> saveVariant(Map<String, Object?> data, {String? requestId}) =>
      _call('inv-variant-upsert', data, requestId);

  Future<void> saveStore(Map<String, Object?> data, {String? requestId}) =>
      _call('inv-store-upsert', data, requestId);

  Future<void> setStoreActive(String id, {required bool active}) =>
      _call('inv-store-setStatus', _status(id, active));

  Map<String, Object?> _status(String id, bool active) => {
    'id': id,
    'status': active ? 'active' : 'inactive',
  };

  Future<void> _call(
    String name,
    Map<String, Object?> data, [
    String? requestId,
  ]) async {
    await callFunction(name, data: data, requestId: requestId);
  }
}
