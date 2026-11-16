import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/services/inventory_service.dart';

@lazySingleton
class InventoryProvider extends ChangeNotifier implements ErrorReporting {
  InventoryProvider(this._service);

  final InventoryService _service;

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

  /// How many of each loaded item are in stock (by item ID); missing until loaded.
  final Map<String, double> inStock = {};

  /// Restricts the loaded items to one store (set per load, e.g. by the item picker).
  String? itemStoreId;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _searchOffset = 0;

  InventoryCategory? category(String? id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  String? _scopedUserId;

  /// Restricts the module to the stores assigned to [userId] (a store manager); set by the app on every sign-in.
  void scopeTo({required String? userId, required bool restricted}) {
    if (userId == _scopedUserId && restricted == _service.restricted) return;
    _scopedUserId = userId;
    _service.scopeTo(userId: userId, restricted: restricted);
    categories = [];
    units = [];
    stores = [];
    items.clear();
    notifyListeners();
  }

  /// A store manager never sees "All stores": the lists are always of their assigned stores.
  bool get restricted => _service.restricted;

  /// The Store filter is pointless with a single store.
  bool get showStoreFilter => stores.length > 1;

  /// The store's name, or `null` when the store is unknown.
  String? storeName(String? id) {
    for (final store in stores) {
      if (store.id == id) return store.name;
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
    String? storeId,
  }) async {
    if (itemsLoading || (more && !hasMoreItems)) return;
    if (!more) {
      itemSearch = search ?? itemSearch;
      itemCategoryId = clearCategory ? null : (categoryId ?? itemCategoryId);
      itemStoreId = storeId;
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
          storeId: itemStoreId,
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
        items.addAll(
          page.items.where(
            (item) => itemStoreId == null || item.storeId == itemStoreId,
          ),
        );
        _searchOffset += page.items.length;
        hasMoreItems = page.hasMore;
      }
      await _loadInStock();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      itemsLoading = false;
      notifyListeners();
    }
  }

  /// Stock figures for the loaded items; the list works without them if this fails.
  Future<void> _loadInStock() async {
    final missing = items.where((item) => !inStock.containsKey(item.id));
    if (missing.isEmpty) return;
    try {
      inStock.addAll(await _service.inStock(missing.toList()));
    } catch (error, stack) {
      logError(error, stack, 'Loading stock figures');
      // Shown as "—".
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

  Future<bool> saveUnit({
    required String storeId,
    required String name,
    InventoryUnit? unit,
  }) => _write(
    () => _service.saveUnit(storeId: storeId, name: name, unit: unit),
    reload: loadMasters,
  );

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
