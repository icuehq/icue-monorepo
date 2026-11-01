import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/services/inventory_service.dart';

@lazySingleton
class InventoryProvider extends ChangeNotifier {
  InventoryProvider(this._service);

  final InventoryService _service;

  InvAccess access = const InvAccess();
  List<InvCategory> categories = [];
  List<InvUnit> units = [];
  List<InvStore> stores = [];
  bool isLoading = false;
  String? errorMessage;

  // Item list (paged).
  final List<InvItem> items = [];
  bool itemsLoading = false;
  bool hasMoreItems = false;
  String itemSearch = '';
  String? itemCategoryId;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _searchOffset = 0;

  InvCategory? category(String? id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<InvCategory> get topCategories =>
      categories.where((c) => c.parentId == null).toList();

  /// Loads the user's permissions and the small master lists.
  Future<void> loadMasters() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      access = await _service.access();
      final r = await Future.wait([
        _service.categories(),
        _service.units(),
        _service.stores(access),
      ]);
      categories = r[0] as List<InvCategory>;
      units = r[1] as List<InvUnit>;
      stores = r[2] as List<InvStore>;
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// (Re)loads the first page, or the next one when [more] is true.
  Future<void> loadItems({
    bool more = false,
    String? search,
    String? categoryId,
    bool clearCategory = false,
  }) async {
    if (itemsLoading || (more && !hasMoreItems)) return;
    if (!more) {
      itemSearch = search ?? itemSearch;
      itemCategoryId = clearCategory ? null : (categoryId ?? itemCategoryId);
      _cursor = null;
      _searchOffset = 0;
    }
    itemsLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final query = itemSearch.trim();
      if (query.isEmpty) {
        final page = await _service.items(
          categoryId: itemCategoryId,
          after: _cursor,
        );
        if (!more) items.clear();
        items.addAll(page.items);
        _cursor = page.cursor;
        hasMoreItems = page.hasMore;
      } else {
        final page = await _service.searchItems(
          query,
          categoryId: itemCategoryId,
          offset: _searchOffset,
        );
        if (!more) items.clear();
        items.addAll(page.items);
        _searchOffset += page.items.length;
        hasMoreItems = page.hasMore;
      }
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      itemsLoading = false;
      notifyListeners();
    }
  }

  Future<InvItem?> item(String id) => _service.item(id);

  Future<List<InvVariant>> variants(String itemId) => _service.variants(itemId);

  // Writes return true on success, else set [errorMessage].

  Future<bool> seedDefaults() =>
      _write(_service.seedDefaults, reload: loadMasters);

  Future<bool> saveCategory(Map<String, Object?> d, {String? requestId}) =>
      _write(
        () => _service.saveCategory(d, requestId: requestId),
        reload: loadMasters,
      );

  Future<bool> setCategoryActive(String id, {required bool active}) => _write(
    () => _service.setCategoryActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> saveUnit(String code, String name) =>
      _write(() => _service.saveUnit(code, name), reload: loadMasters);

  Future<bool> saveItem(Map<String, Object?> d, {String? requestId}) => _write(
    () => _service.saveItem(d, requestId: requestId),
    reload: loadItems,
  );

  Future<bool> setItemActive(String id, {required bool active}) => _write(
    () => _service.setItemActive(id, active: active),
    reload: loadItems,
  );

  Future<bool> saveVariant(Map<String, Object?> d, {String? requestId}) =>
      _write(() => _service.saveVariant(d, requestId: requestId));

  Future<bool> saveStore(Map<String, Object?> d, {String? requestId}) => _write(
    () => _service.saveStore(d, requestId: requestId),
    reload: loadMasters,
  );

  Future<bool> setStoreActive(String id, {required bool active}) => _write(
    () => _service.setStoreActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> _write(
    Future<void> Function() call, {
    Future<void> Function()? reload,
  }) async {
    errorMessage = null;
    try {
      await call();
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
      return false;
    }
    await reload?.call();
    return true;
  }

  String _message(Object e) =>
      e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();
}
