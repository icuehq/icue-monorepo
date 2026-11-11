import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/services/inventory_service.dart';

@lazySingleton
class InventoryProvider extends ChangeNotifier implements ErrorReporting {
  InventoryProvider(this._service);

  final InventoryService _service;

  ModuleAccess access = const ModuleAccess();
  List<InventoryCategory> categories = [];
  List<InventoryUnit> units = [];
  List<InventoryStore> stores = [];
  bool isLoading = false;
  @override
  String? errorMessage;

  // Item list (paged).
  final List<InventoryItem> items = [];
  bool itemsLoading = false;
  bool hasMoreItems = false;
  String itemSearch = '';
  String? itemCategoryId;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _searchOffset = 0;

  InventoryCategory? category(String? id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  List<InventoryCategory> get topCategories =>
      categories.where((category) => category.parentId == null).toList();

  /// Loads the user's permissions and the small master lists.
  Future<void> loadMasters() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      access = await _service.access();
      final masterLists = await Future.wait([
        _service.categories(),
        _service.units(),
        _service.stores(),
      ]);
      categories = masterLists[0] as List<InventoryCategory>;
      units = masterLists[1] as List<InventoryUnit>;
      stores = masterLists[2] as List<InventoryStore>;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
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
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      itemsLoading = false;
      notifyListeners();
    }
  }

  Future<InventoryItem?> item(String id) => _service.item(id);

  Future<List<InventoryVariant>> variants(String itemId) =>
      _service.variants(itemId);

  // Writes return true on success, else set [errorMessage].

  Future<bool> seedDefaults() =>
      _write(_service.seedDefaults, reload: loadMasters);

  Future<bool> saveCategory(Map<String, Object?> data) =>
      _write(() => _service.saveCategory(data), reload: loadMasters);

  Future<bool> setCategoryActive(String id, {required bool active}) => _write(
    () => _service.setCategoryActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> saveUnit(String code, String name) =>
      _write(() => _service.saveUnit(code, name), reload: loadMasters);

  Future<bool> saveItem(Map<String, Object?> data) =>
      _write(() => _service.saveItem(data), reload: loadItems);

  Future<bool> setItemActive(String id, {required bool active}) => _write(
    () => _service.setItemActive(id, active: active),
    reload: loadItems,
  );

  Future<bool> saveVariant(Map<String, Object?> data) =>
      _write(() => _service.saveVariant(data));

  Future<bool> saveStore(Map<String, Object?> data) =>
      _write(() => _service.saveStore(data), reload: loadMasters);

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
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
      return false;
    }
    await reload?.call();
    return true;
  }
}
