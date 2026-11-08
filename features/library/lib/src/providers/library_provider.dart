import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:routes/routes.dart';
import 'package:school_library/src/models/library_copies.dart';
import 'package:school_library/src/models/library_fines.dart';
import 'package:school_library/src/models/library_incidents.dart';
import 'package:school_library/src/models/library_insights.dart';
import 'package:school_library/src/models/library_loans.dart';
import 'package:school_library/src/models/library_masters.dart';
import 'package:school_library/src/models/library_members.dart';
import 'package:school_library/src/models/library_person.dart';
import 'package:school_library/src/models/library_reservations.dart';
import 'package:school_library/src/services/library_people_service.dart';
import 'package:school_library/src/services/library_service.dart';
import 'package:school_library/src/services/library_writes.dart';
import 'package:school_library/src/services/loan_writes.dart';

@lazySingleton
class LibraryProvider extends ChangeNotifier implements ErrorReporting {
  LibraryProvider(this._service, this._people, this._writes, this._loanWrites);

  final LibraryService _service;
  final LibraryWrites _writes;
  final LoanWrites _loanWrites;
  final LibraryPeopleService _people;

  ModuleAccess access = const ModuleAccess();
  List<SchoolLibrary> libraries = [];
  List<LibraryCategory> categories = [];
  List<LibraryPolicy> policies = [];
  bool isLoading = false;
  @override
  String? errorMessage;

  // Catalogue list (paged).
  final List<LibraryBook> books = [];
  bool booksLoading = false;
  bool hasMoreBooks = false;
  String bookSearch = '';
  String? bookCategoryId;
  int? bookClassId;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  int _searchOffset = 0;
  int _bookGeneration = 0;

  // Paged lists; each is a `_Paged` holder behind the getters below.
  final _members = _Paged<LibraryMember>();
  final _loans = _Paged<LibraryLoan>();
  final _reservations = _Paged<LibraryReservation>();
  final _fines = _Paged<LibraryFine>();
  final _incidents = _Paged<LibraryIncident>();

  /// Members of [memberType], one type at a time.
  List<LibraryMember> get members => _members.items;
  bool get membersLoading => _members.loading;
  bool get hasMoreMembers => _members.hasMore;
  String memberType = 'student';

  /// Active loans, earliest due first.
  List<LibraryLoan> get loans => _loans.items;
  bool get loansLoading => _loans.loading;
  bool get hasMoreLoans => _loans.hasMore;

  List<LibraryReservation> get reservations => _reservations.items;
  bool get reservationsLoading => _reservations.loading;
  bool get hasMoreReservations => _reservations.hasMore;
  String reservationStatus = 'waiting';

  /// Fines by status: 'outstanding', 'partially_paid', 'paid', 'waived', or 'all'.
  List<LibraryFine> get fines => _fines.items;
  bool get finesLoading => _fines.loading;
  bool get hasMoreFines => _fines.hasMore;
  String fineStatus = 'outstanding';

  /// Incidents by status: 'open', 'resolved', or 'all'.
  List<LibraryIncident> get incidents => _incidents.items;
  bool get incidentsLoading => _incidents.loading;
  bool get hasMoreIncidents => _incidents.hasMore;
  String incidentStatus = 'open';

  /// The student (`student`) or staff member (`teacher`) with [admissionNumber] in the ERP, or null.
  Future<LibraryPerson?> findPerson(String type, String admissionNumber) =>
      _people.findByAdmissionNumber(type, admissionNumber);

  Future<List<Standards>> classes() => _people.classes();

  Future<List<StudentData>> studentsOf(int classId, String section) =>
      _people.studentsOf(classId, section);

  LibraryPerson studentPerson(StudentData student) =>
      _people.personFrom('student', student);

  LibraryCategory? category(String? id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// [id] and its subcategories, so filtering by a parent also finds books filed under a child.
  List<String>? categoryScope(String? id) => id == null
      ? null
      : [
          id,
          for (final category in categories)
            if (category.parentId == id) category.id,
        ];

  /// ERP classes (with sections, which books ignore), loaded once for pickers and labels.
  List<Standards> standards = [];

  Future<void> loadStandards() async {
    if (standards.isNotEmpty) return;
    try {
      standards = await _people.classes();
      notifyListeners();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      notifyListeners();
    }
  }

  /// The ERP class name; a class missing from the ERP shows as `Class <id>`.
  String className(int id) =>
      standards.where((standard) => standard.id == id).firstOrNull?.name ??
      'Class $id';

  List<LibraryCategory> get topCategories =>
      categories.where((category) => category.parentId == null).toList();

  /// Loads the user's campus scope and the small master lists.
  Future<void> loadMasters() =>
      _busy((loading) => isLoading = loading, () async {
        access = await _service.access();
        final masterLists = await Future.wait([
          _service.libraries(),
          _service.categories(),
          _service.policies(),
        ]);
        libraries = masterLists[0] as List<SchoolLibrary>;
        categories = masterLists[1] as List<LibraryCategory>;
        policies = masterLists[2] as List<LibraryPolicy>;
      });

  /// (Re)loads the first page, or the next one when [more] is true.
  Future<void> loadBooks({
    bool more = false,
    String? search,
    String? categoryId,
    bool clearCategory = false,
    int? classId,
    bool clearClass = false,
  }) async {
    if (more && (booksLoading || !hasMoreBooks)) return;
    final generation = ++_bookGeneration;
    if (!more) {
      bookSearch = search ?? bookSearch;
      bookCategoryId = clearCategory ? null : (categoryId ?? bookCategoryId);
      bookClassId = clearClass ? null : (classId ?? bookClassId);
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
          categoryIds: categoryScope(bookCategoryId),
          classId: bookClassId,
          after: _cursor,
        );
        if (generation != _bookGeneration) return;
        if (!more) books.clear();
        books.addAll(page.items);
        _cursor = page.cursor;
        hasMoreBooks = page.hasMore;
      } else {
        final page = await _service.searchBooks(
          query,
          categoryIds: categoryScope(bookCategoryId),
          classId: bookClassId,
          offset: _searchOffset,
        );
        if (generation != _bookGeneration) return;
        if (!more) books.clear();
        books.addAll(page.items);
        _searchOffset += page.items.length;
        hasMoreBooks = page.hasMore;
      }
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == _bookGeneration) {
        booksLoading = false;
        notifyListeners();
      }
    }
  }

  /// Loads the first page of a paged list, or the next one when [more] is true; an older
  /// response never overwrites a newer one.
  Future<void> _loadPage<T>(
    _Paged<T> paged,
    Future<PagedResult<T>> Function(
      DocumentSnapshot<Map<String, dynamic>>? after,
    )
    fetch, {
    required bool more,
  }) async {
    if (more && (paged.loading || !paged.hasMore)) return;
    final generation = ++paged.generation;
    if (!more) paged.cursor = null;
    paged.loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await fetch(paged.cursor);
      if (generation != paged.generation) return;
      if (!more) paged.items.clear();
      paged.items.addAll(page.items);
      paged.cursor = page.cursor;
      paged.hasMore = page.hasMore;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == paged.generation) {
        paged.loading = false;
        notifyListeners();
      }
    }
  }

  /// (Re)loads the first page of [type] members, or the next one when [more] is true.
  Future<void> loadMembers({bool more = false, String? type}) {
    if (!more) memberType = type ?? memberType;
    return _loadPage(
      _members,
      (after) => _service.members(memberType, after: after),
      more: more,
    );
  }

  /// (Re)loads the first page of active loans, or the next one when [more] is true.
  Future<void> loadLoans({bool more = false}) => _loadPage(
    _loans,
    (after) => _service.loans('active', after: after),
    more: more,
  );

  /// (Re)loads the first page of reservations, or the next one when [more] is true.
  Future<void> loadReservations({bool more = false, String? status}) {
    if (!more) reservationStatus = status ?? reservationStatus;
    return _loadPage(
      _reservations,
      (after) => _service.reservations(reservationStatus, after: after),
      more: more,
    );
  }

  /// (Re)loads the first page of fines, or the next one when [more] is true.
  Future<void> loadFines({bool more = false, String? status}) {
    if (!more) fineStatus = status ?? fineStatus;
    return _loadPage(
      _fines,
      (after) => _service.fines(status: fineStatus, after: after),
      more: more,
    );
  }

  Future<LibraryFine?> fine(String id) => _service.fine(id);

  /// (Re)loads the first page of incidents, or the next one when [more] is true.
  Future<void> loadIncidents({bool more = false, String? status}) {
    if (!more) incidentStatus = status ?? incidentStatus;
    return _loadPage(
      _incidents,
      (after) => _service.incidents(status: incidentStatus, after: after),
      more: more,
    );
  }

  Future<LibraryLoan?> activeLoanOf(String barcode) =>
      _service.activeLoanOf(barcode);

  Future<LibraryMember?> member(int personErpId) =>
      _service.member(personErpId);

  Future<LibraryBook?> book(String id) => _service.book(id);

  Future<({List<LibraryBook> items, bool hasMore})> searchBooks(
    String query, {
    List<String>? categoryIds,
    int? classId,
    int offset = 0,
    int limit = 25,
  }) => _service.searchBooks(
    query,
    categoryIds: categoryIds,
    classId: classId,
    offset: offset,
    limit: limit,
  );

  Future<List<LibraryCopy>> copiesOf(String catalogueId) =>
      _service.copiesOf(catalogueId);

  Future<LibraryCopy?> findCopy(String code) => _service.findCopy(code);

  SchoolLibrary? library(String? id) {
    for (final schoolLibrary in libraries) {
      if (schoolLibrary.id == id) return schoolLibrary;
    }
    return null;
  }

  // Writes return true on success, else set [errorMessage].

  Future<bool> saveLibrary(Map<String, Object?> data) =>
      _write(() => _service.saveLibrary(data), reload: loadMasters);

  Future<bool> setLibraryActive(String id, {required bool active}) => _write(
    () => _service.setLibraryActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> saveCategory(Map<String, Object?> data) =>
      _write(() => _service.saveCategory(data), reload: loadMasters);

  Future<bool> setCategoryActive(String id, {required bool active}) => _write(
    () => _service.setCategoryActive(id, active: active),
    reload: loadMasters,
  );

  /// Saves a book; for a new one, [copies] (`libraryId`, `quantity`, `shelf`) also creates its copies.
  Future<bool> saveBook(
    Map<String, Object?> data, {
    Map<String, Object?>? copies,
    String? copiesRequestId,
  }) => _write(() async {
    final id = await _writes.saveBook(data);
    if (copies != null) {
      await _service.createBook({
        'catalogueId': id,
        ...copies,
      }, requestId: copiesRequestId);
    }
  }, reload: loadBooks);

  Future<String?> findTitleId(Map<String, Object?> data) =>
      _writes.findTitleId(data);

  Future<bool> setBookActive(String id, {required bool active}) => _write(
    () => _writes.setBookActive(id, active: active),
    reload: loadBooks,
  );

  Future<bool> updateCopy(Map<String, Object?> data) =>
      _write(() => _writes.updateCopy(data));

  Future<bool> moveCopy(String id, String libraryId, String? shelf) =>
      _write(() => _writes.moveCopy(id, libraryId, shelf));

  Future<bool> setCopyStatus(String id, String status, String? reason) =>
      _write(() => _service.setCopyStatus(id, status, reason));

  Future<bool> savePolicy(Map<String, Object?> data) =>
      _write(() => _writes.savePolicy(data), reload: loadMasters);

  /// Starter borrowing rules for everyone, in each active library that has no default yet.
  Future<bool> seedDefaultPolicies() => _write(() async {
    for (final schoolLibrary in libraries) {
      final hasDefault = policies.any(
        (policy) =>
            policy.libraryId == schoolLibrary.id &&
            policy.memberType == 'all' &&
            policy.categoryIds.isEmpty,
      );
      if (!schoolLibrary.active || hasDefault) continue;
      await _writes.savePolicy({
        'libraryId': schoolLibrary.id,
        'memberType': 'all',
        'name': 'Default policy',
        'maxBooks': 3,
        'loanDays': 14,
        'maxRenewals': 1,
        'fineType': 'per_day',
        'fineAmount': 1,
        'graceDays': 1,
        'maxFine': 100,
        'categoryIds': <String>[],
      });
    }
  }, reload: loadMasters);

  Future<bool> setPolicyActive(String id, {required bool active}) => _write(
    () => _writes.setPolicyActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> issueLoan(Map<String, Object?> data) => _write(
    () => _loanWrites.issue(
      person: data['person']! as Map<String, Object?>,
      barcode: data['barcode']! as String,
      remarks: data['remarks'] as String?,
    ),
    reload: loadLoans,
  );

  Future<bool> returnLoan(Map<String, Object?> data) => _write(
    () => _loanWrites.returnLoan(
      id: data['id']! as String,
      condition: data['condition']! as String,
      remarks: data['remarks'] as String?,
    ),
    reload: loadLoans,
  );

  Future<bool> renewLoan(String id) =>
      _write(() => _loanWrites.renew(id), reload: loadLoans);

  Future<bool> createReservation(Map<String, Object?> data) => _write(
    () => _loanWrites.reserve(
      person: data['person']! as Map<String, Object?>,
      catalogueId: data['catalogueId']! as String,
      libraryId: data['libraryId']! as String,
    ),
    reload: loadReservations,
  );

  Future<bool> cancelReservation(String id) =>
      _write(() => _loanWrites.cancelReservation(id), reload: loadReservations);

  Future<bool> waiveFine(Map<String, Object?> data, {String? requestId}) =>
      _write(
        () => _service.waiveFine(data, requestId: requestId),
        reload: loadFines,
      );

  Future<bool> setFinePayment(Map<String, Object?> data, {String? requestId}) =>
      _write(
        () => _service.setFinePayment(data, requestId: requestId),
        reload: loadFines,
      );

  Future<bool> reportIncident(Map<String, Object?> data, {String? requestId}) =>
      _write(
        () => _service.reportIncident(data, requestId: requestId),
        reload: loadIncidents,
      );

  Future<bool> resolveIncident(
    Map<String, Object?> data, {
    String? requestId,
  }) => _write(
    () => _service.resolveIncident(data, requestId: requestId),
    reload: loadIncidents,
  );

  Future<bool> setMemberBlocked(
    String id, {
    required bool blocked,
    String? reason,
  }) => _write(
    () => _writes.setMemberBlocked(id, blocked: blocked, reason: reason),
    reload: loadMembers,
  );

  Future<bool> markLoanLost(Map<String, Object?> data) => _write(
    () => _loanWrites.markLost(
      id: data['id']! as String,
      reason: data['reason'] as String?,
      charge: data['charge'] as double?,
    ),
    reload: loadLoans,
  );

  // Dashboard and reports (Lib-8).
  Map<String, num?> dashboard = {};
  List<ReportRow> reportRows = [];
  final Map<String, LibraryBook> _titles = {};
  bool insightsLoading = false;

  String titleName(Object? id) => _titles[id]?.title ?? '$id';

  String libraryName(Object? id) =>
      libraries
          .where((schoolLibrary) => schoolLibrary.id == id)
          .firstOrNull
          ?.name ??
      '$id';

  /// Who and which books a policy covers, e.g. `Students · Fiction, Science`.
  String policyScope(LibraryPolicy policy) =>
      '${policy.appliesTo} · ${policy.categoryIds.isEmpty ? 'All other categories' : policy.categoryIds.map(categoryName).join(', ')}';

  String categoryName(Object? id) =>
      categories.where((category) => category.id == id).firstOrNull?.name ??
      '$id';

  /// Runs [body] with [setLoading] flagged around it; a failure becomes [errorMessage].
  Future<void> _busy(
    void Function(bool loading) setLoading,
    Future<void> Function() body,
  ) async {
    setLoading(true);
    errorMessage = null;
    notifyListeners();
    try {
      await body();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _insights(Future<void> Function() body) =>
      _busy((loading) => insightsLoading = loading, body);

  Future<void> loadDashboard({SchoolLibrary? library}) => _insights(
    () async => dashboard = await _service.dashboard(access, library: library),
  );

  Future<void> loadReport(
    LibraryReportDef def, {
    SchoolLibrary? library,
    DateTime? from,
    DateTime? to,
    String? status,
  }) => _insights(() async {
    reportRows = await _service.report(
      access,
      def,
      library: library,
      from: from,
      to: to,
      status: status,
    );
    final need = {
      for (final row in reportRows)
        if (row['catalogueId'] is String &&
            !_titles.containsKey(row['catalogueId']))
          row['catalogueId'] as String,
    };
    if (need.isNotEmpty) _titles.addAll(await _service.titlesByIds(need));
  });

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

/// One paged list: its items, cursor and the latest load generation.
class _Paged<T> {
  final items = <T>[];
  bool loading = false;
  bool hasMore = false;
  DocumentSnapshot<Map<String, dynamic>>? cursor;
  int generation = 0;
}
