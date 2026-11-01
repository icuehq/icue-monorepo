import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/lib_copies.dart';
import 'package:school_library/src/models/lib_loans.dart';
import 'package:school_library/src/models/lib_masters.dart';
import 'package:school_library/src/models/lib_members.dart';
import 'package:school_library/src/services/library_service.dart';

@lazySingleton
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._service);

  final LibraryService _service;

  LibAccess access = const LibAccess();
  List<LibLibrary> libraries = [];
  List<LibCategory> categories = [];
  List<LibPolicy> policies = [];
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

  // Member list (paged, one type at a time).
  final List<LibMember> members = [];
  bool membersLoading = false;
  bool hasMoreMembers = false;
  String memberType = 'student';
  DocumentSnapshot<Map<String, dynamic>>? _memberCursor;

  // Active loans (paged, earliest due first).
  final List<LibLoan> loans = [];
  bool loansLoading = false;
  bool hasMoreLoans = false;
  DocumentSnapshot<Map<String, dynamic>>? _loanCursor;

  /// The policy a member of [category] gets in [libraryId], if one is set up.
  LibPolicy? policyFor(String libraryId, String category) {
    for (final p in policies) {
      if (p.libraryId == libraryId && p.memberCategory == category) return p;
    }
    return null;
  }

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
        if (access.can('lib.members.view')) _service.policies(),
      ]);
      libraries = r[0] as List<LibLibrary>;
      categories = r[1] as List<LibCategory>;
      policies = r.length > 2 ? r[2] as List<LibPolicy> : [];
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

  /// (Re)loads the first page of [type] members, or the next one when [more] is true.
  Future<void> loadMembers({bool more = false, String? type}) async {
    if (membersLoading || (more && !hasMoreMembers)) return;
    if (!more) {
      memberType = type ?? memberType;
      _memberCursor = null;
    }
    membersLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.members(memberType, after: _memberCursor);
      if (!more) members.clear();
      members.addAll(page.items);
      _memberCursor = page.cursor;
      hasMoreMembers = page.hasMore;
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      membersLoading = false;
      notifyListeners();
    }
  }

  /// (Re)loads the first page of active loans, or the next one when [more] is true.
  Future<void> loadLoans({bool more = false}) async {
    if (loansLoading || (more && !hasMoreLoans)) return;
    if (!more) _loanCursor = null;
    loansLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.loans('active', after: _loanCursor);
      if (!more) loans.clear();
      loans.addAll(page.items);
      _loanCursor = page.cursor;
      hasMoreLoans = page.hasMore;
    } catch (e) {
      errorMessage = _message(e);
    } finally {
      loansLoading = false;
      notifyListeners();
    }
  }

  Future<LibLoan?> activeLoanOf(String copyId) => _service.activeLoanOf(copyId);

  Future<LibMember?> member(String type, int erpId) =>
      _service.member(type, erpId);

  Future<LibBook?> book(String id) => _service.book(id);

  Future<List<LibCopy>> copiesOf(String catalogueId) =>
      _service.copiesOf(catalogueId);

  Future<LibCopy?> findCopy(String code) => _service.findCopy(code);

  Future<List<LibAcquisition>> acquisitions() => _service.acquisitions();

  LibLibrary? library(String? id) {
    for (final l in libraries) {
      if (l.id == id) return l;
    }
    return null;
  }

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

  /// Accession numbers of the new copies, or null (with [errorMessage]) on failure.
  Future<List<String>?> createAcquisition(
    Map<String, Object?> d, {
    String? requestId,
  }) async {
    errorMessage = null;
    try {
      return await _service.createAcquisition(d, requestId: requestId);
    } catch (e) {
      errorMessage = _message(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCopy(Map<String, Object?> d) =>
      _write(() => _service.updateCopy(d));

  Future<bool> moveCopy(String id, String libraryId, String? shelf) =>
      _write(() => _service.moveCopy(id, libraryId, shelf));

  Future<bool> setCopyStatus(String id, String status, String? reason) =>
      _write(() => _service.setCopyStatus(id, status, reason));

  Future<bool> savePolicy(Map<String, Object?> d, {String? requestId}) =>
      _write(
        () => _service.savePolicy(d, requestId: requestId),
        reload: loadMasters,
      );

  Future<bool> setPolicyActive(String id, {required bool active}) => _write(
    () => _service.setPolicyActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> saveMember(Map<String, Object?> d, {String? requestId}) =>
      _write(
        () => _service.saveMember(d, requestId: requestId),
        reload: loadMembers,
      );

  Future<bool> setMemberActive(String id, {required bool active}) => _write(
    () => _service.setMemberActive(id, active: active),
    reload: loadMembers,
  );

  Future<bool> issueLoan(Map<String, Object?> d, {String? requestId}) => _write(
    () => _service.issueLoan(d, requestId: requestId),
    reload: loadLoans,
  );

  Future<bool> returnLoan(Map<String, Object?> d, {String? requestId}) =>
      _write(
        () => _service.returnLoan(d, requestId: requestId),
        reload: loadLoans,
      );

  Future<bool> renewLoan(String id, {String? requestId}) => _write(
    () => _service.renewLoan(id, requestId: requestId),
    reload: loadLoans,
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
