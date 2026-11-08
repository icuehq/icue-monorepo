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

@lazySingleton
class LibraryProvider extends ChangeNotifier implements ErrorReporting {
  LibraryProvider(this._service, this._people, this._writes);

  final LibraryService _service;
  final LibraryWrites _writes;
  final LibraryPeopleService _people;

  /// Latest load per list; an older response never overwrites a newer filter's list.
  final Map<String, int> _generation = {};

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

  // Member list (paged, one type at a time).
  final List<LibraryMember> members = [];
  bool membersLoading = false;
  bool hasMoreMembers = false;
  String memberType = 'student';
  DocumentSnapshot<Map<String, dynamic>>? _memberCursor;

  // Active loans (paged, earliest due first).
  final List<LibraryLoan> loans = [];
  bool loansLoading = false;
  bool hasMoreLoans = false;
  DocumentSnapshot<Map<String, dynamic>>? _loanCursor;

  // Reservations (paged, by status).
  final List<LibraryReservation> reservations = [];
  bool reservationsLoading = false;
  bool hasMoreReservations = false;
  String reservationStatus = 'waiting';
  DocumentSnapshot<Map<String, dynamic>>? _reservationCursor;

  // Fines (paged, by status: 'outstanding', 'partially_paid', 'paid', 'waived', or 'all').
  final List<LibraryFine> fines = [];
  bool finesLoading = false;
  bool hasMoreFines = false;
  String fineStatus = 'outstanding';
  DocumentSnapshot<Map<String, dynamic>>? _fineCursor;

  // Incidents (paged, by status: 'open', 'resolved', or 'all').
  final List<LibraryIncident> incidents = [];
  bool incidentsLoading = false;
  bool hasMoreIncidents = false;
  String incidentStatus = 'open';
  DocumentSnapshot<Map<String, dynamic>>? _incidentCursor;

  /// The student (`student`) or staff member (`teacher`) with [admissionNumber] in the ERP, or null.
  Future<LibraryPerson?> findPerson(String type, String admissionNumber) =>
      _people.findByAdmissionNumber(type, admissionNumber);

  Future<List<Standards>> classes() => _people.classes();

  Future<List<StudentData>> studentsOf(int classId, String section) =>
      _people.studentsOf(classId, section);

  Future<List<StudentData>> searchStudents(String text) =>
      _people.searchStudents(text);

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
  Future<void> loadMasters() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      access = await _service.access();
      final masterLists = await Future.wait([
        _service.libraries(),
        _service.categories(),
        _service.policies(),
      ]);
      libraries = masterLists[0] as List<SchoolLibrary>;
      categories = masterLists[1] as List<LibraryCategory>;
      policies = masterLists[2] as List<LibraryPolicy>;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
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
    int? classId,
    bool clearClass = false,
  }) async {
    if (more && (booksLoading || !hasMoreBooks)) return;
    final generation = _generation['books'] = (_generation['books'] ?? 0) + 1;
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
        if (generation != _generation['books']) return;
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
        if (generation != _generation['books']) return;
        if (!more) books.clear();
        books.addAll(page.items);
        _searchOffset += page.items.length;
        hasMoreBooks = page.hasMore;
      }
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == _generation['books']) {
        booksLoading = false;
        notifyListeners();
      }
    }
  }

  /// (Re)loads the first page of [type] members, or the next one when [more] is true.
  Future<void> loadMembers({bool more = false, String? type}) async {
    if (more && (membersLoading || !hasMoreMembers)) return;
    final generation = _generation['members'] =
        (_generation['members'] ?? 0) + 1;
    if (!more) {
      memberType = type ?? memberType;
      _memberCursor = null;
    }
    membersLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.members(memberType, after: _memberCursor);
      if (generation != _generation['members']) return;
      if (!more) members.clear();
      members.addAll(page.items);
      _memberCursor = page.cursor;
      hasMoreMembers = page.hasMore;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == _generation['members']) {
        membersLoading = false;
        notifyListeners();
      }
    }
  }

  /// (Re)loads the first page of active loans, or the next one when [more] is true.
  Future<void> loadLoans({bool more = false}) async {
    if (more && (loansLoading || !hasMoreLoans)) return;
    final generation = _generation['loans'] = (_generation['loans'] ?? 0) + 1;
    if (!more) _loanCursor = null;
    loansLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.loans('active', after: _loanCursor);
      if (generation != _generation['loans']) return;
      if (!more) loans.clear();
      loans.addAll(page.items);
      _loanCursor = page.cursor;
      hasMoreLoans = page.hasMore;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == _generation['loans']) {
        loansLoading = false;
        notifyListeners();
      }
    }
  }

  /// (Re)loads the first page of reservations, or the next one when [more] is true.
  Future<void> loadReservations({bool more = false, String? status}) async {
    if (more && (reservationsLoading || !hasMoreReservations)) return;
    final generation = _generation['reservations'] =
        (_generation['reservations'] ?? 0) + 1;
    if (!more) {
      reservationStatus = status ?? reservationStatus;
      _reservationCursor = null;
    }
    reservationsLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.reservations(
        reservationStatus,
        after: _reservationCursor,
      );
      if (generation != _generation['reservations']) return;
      if (!more) reservations.clear();
      reservations.addAll(page.items);
      _reservationCursor = page.cursor;
      hasMoreReservations = page.hasMore;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == _generation['reservations']) {
        reservationsLoading = false;
        notifyListeners();
      }
    }
  }

  /// (Re)loads the first page of fines, or the next one when [more] is true.
  Future<void> loadFines({bool more = false, String? status}) async {
    if (more && (finesLoading || !hasMoreFines)) return;
    final generation = _generation['fines'] = (_generation['fines'] ?? 0) + 1;
    if (!more) {
      fineStatus = status ?? fineStatus;
      _fineCursor = null;
    }
    finesLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.fines(
        status: fineStatus == 'all' ? null : fineStatus,
        after: _fineCursor,
      );
      if (generation != _generation['fines']) return;
      if (!more) fines.clear();
      fines.addAll(page.items);
      _fineCursor = page.cursor;
      hasMoreFines = page.hasMore;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == _generation['fines']) {
        finesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<LibraryFine?> fine(String id) => _service.fine(id);

  /// (Re)loads the first page of incidents, or the next one when [more] is true.
  Future<void> loadIncidents({bool more = false, String? status}) async {
    if (more && (incidentsLoading || !hasMoreIncidents)) return;
    final generation = _generation['incidents'] =
        (_generation['incidents'] ?? 0) + 1;
    if (!more) {
      incidentStatus = status ?? incidentStatus;
      _incidentCursor = null;
    }
    incidentsLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final page = await _service.incidents(
        status: incidentStatus == 'all' ? null : incidentStatus,
        after: _incidentCursor,
      );
      if (generation != _generation['incidents']) return;
      if (!more) incidents.clear();
      incidents.addAll(page.items);
      _incidentCursor = page.cursor;
      hasMoreIncidents = page.hasMore;
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      if (generation == _generation['incidents']) {
        incidentsLoading = false;
        notifyListeners();
      }
    }
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

  Future<bool> seedDefaults() =>
      _write(_service.seedDefaults, reload: loadMasters);

  /// Debug only: fills the emulator with sample data. Returns an error message, or null on success.
  Future<String?> fillMockData() async {
    if (await _write(_service.fillMockData, reload: loadMasters)) return null;
    final message = errorMessage;
    errorMessage = null;
    notifyListeners();
    return message;
  }

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
      await _service.createAcquisition({
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

  Future<bool> savePolicy(Map<String, Object?> data, {String? requestId}) =>
      _write(
        () => _service.savePolicy(data, requestId: requestId),
        reload: loadMasters,
      );

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
      await _service.savePolicy({
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
    () => _service.setPolicyActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> issueLoan(Map<String, Object?> data, {String? requestId}) =>
      _write(
        () => _service.issueLoan(data, requestId: requestId),
        reload: loadLoans,
      );

  Future<bool> returnLoan(Map<String, Object?> data, {String? requestId}) =>
      _write(
        () => _service.returnLoan(data, requestId: requestId),
        reload: loadLoans,
      );

  Future<bool> renewLoan(String id, {String? requestId}) => _write(
    () => _service.renewLoan(id, requestId: requestId),
    reload: loadLoans,
  );

  Future<bool> createReservation(
    Map<String, Object?> data, {
    String? requestId,
  }) => _write(
    () => _service.createReservation(data, requestId: requestId),
    reload: loadReservations,
  );

  Future<bool> cancelReservation(String id, {String? requestId}) => _write(
    () => _service.cancelReservation(id, requestId: requestId),
    reload: loadReservations,
  );

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

  Future<bool> markLoanLost(Map<String, Object?> data, {String? requestId}) =>
      _write(
        () => _service.markLoanLost(data, requestId: requestId),
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

  Future<void> _insights(Future<void> Function() body) async {
    insightsLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await body();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      insightsLoading = false;
      notifyListeners();
    }
  }

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
