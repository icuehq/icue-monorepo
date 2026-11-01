import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/lib_masters.dart';
import 'package:school_library/src/services/library_service.dart';

@lazySingleton
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._service);

  final LibraryService _service;

  LibAccess access = const LibAccess();
  List<LibLibrary> libraries = [];
  List<LibCategory> categories = [];
  bool isLoading = false;
  String? errorMessage;

  // Catalogue list (paged).
  final List<LibBook> books = [];
  bool booksLoading = false;
  bool hasMoreBooks = false;
  String bookSearch = '';
  String? bookCategoryId;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _searchOffset = 0;

  LibCategory? category(String? id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<LibCategory> get topCategories =>
      categories.where((c) => c.parentId == null).toList();

  /// Loads the user's permissions and the small master lists.
  Future<void> loadMasters() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      access = await _service.access();
      final r = await Future.wait([
        _service.libraries(),
        _service.categories(),
      ]);
      libraries = r[0] as List<LibLibrary>;
      categories = r[1] as List<LibCategory>;
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// (Re)loads the first page, or the next one when [more] is true.
  Future<void> loadBooks({
    bool more = false,
    String? search,
    String? categoryId,
    bool clearCategory = false,
  }) async {
    if (booksLoading || (more && !hasMoreBooks)) return;
    if (!more) {
      bookSearch = search ?? bookSearch;
      bookCategoryId = clearCategory ? null : (categoryId ?? bookCategoryId);
      _cursor = null;
      _searchOffset = 0;
    }
    booksLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final query = bookSearch.trim();
      if (query.isEmpty) {
        final page = await _service.books(
          categoryId: bookCategoryId,
          after: _cursor,
        );
        if (!more) books.clear();
        books.addAll(page.items);
        _cursor = page.cursor;
        hasMoreBooks = page.hasMore;
      } else {
        final page = await _service.searchBooks(
          query,
          categoryId: bookCategoryId,
          offset: _searchOffset,
        );
        if (!more) books.clear();
        books.addAll(page.items);
        _searchOffset += page.items.length;
        hasMoreBooks = page.hasMore;
      }
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      booksLoading = false;
      notifyListeners();
    }
  }

  Future<LibBook?> book(String id) => _service.book(id);

  // Writes return true on success, else set [errorMessage].

  Future<bool> seedDefaults() =>
      _write(_service.seedDefaults, reload: loadMasters);

  Future<bool> saveLibrary(Map<String, Object?> d, {String? requestId}) =>
      _write(
        () => _service.saveLibrary(d, requestId: requestId),
        reload: loadMasters,
      );

  Future<bool> setLibraryActive(String id, {required bool active}) => _write(
    () => _service.setLibraryActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> saveCategory(Map<String, Object?> d, {String? requestId}) =>
      _write(
        () => _service.saveCategory(d, requestId: requestId),
        reload: loadMasters,
      );

  Future<bool> setCategoryActive(String id, {required bool active}) => _write(
    () => _service.setCategoryActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> saveBook(Map<String, Object?> d, {String? requestId}) => _write(
    () => _service.saveBook(d, requestId: requestId),
    reload: loadBooks,
  );

  Future<bool> setBookActive(String id, {required bool active}) => _write(
    () => _service.setBookActive(id, active: active),
    reload: loadBooks,
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
