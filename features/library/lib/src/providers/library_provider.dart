import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:routes/routes.dart';
import 'package:school_library/src/models/library_fines.dart';
import 'package:school_library/src/models/library_incidents.dart';
import 'package:school_library/src/models/library_insights.dart';
import 'package:school_library/src/models/library_loans.dart';
import 'package:school_library/src/models/library_masters.dart';
import 'package:school_library/src/models/library_members.dart';
import 'package:school_library/src/models/library_person.dart';
import 'package:school_library/src/services/library_people_service.dart';
import 'package:school_library/src/services/library_service.dart';
import 'package:school_library/src/services/library_writes.dart';
import 'package:school_library/src/services/loan_writes.dart';

@lazySingleton
class LibraryProvider extends ChangeNotifier implements ErrorReporting {
  LibraryProvider(this._service, this._people, this._writes, this._loanWrites);

  /// Read-side lookups (single records, scans) that need no provider state.
  LibraryService get service => _service;

  final LibraryService _service;
  final LibraryWrites _writes;
  final LoanWrites _loanWrites;
  final LibraryPeopleService _people;

  ModuleAccess access = const ModuleAccess();
  List<SchoolLibrary> libraries = [];
  List<LibraryCategory> categories = [];
  List<LibraryPolicy> policies = [];

  /// True until the first [loadMasters] finishes, so a page never flashes its empty state first.
  bool isLoading = true;
  @override
  String? errorMessage;

  // Catalogue list: a Firestore query by title, or the search callable while [bookSearch] is set.
  late final books = _pager<LibraryBook>();
  String bookSearch = '';
  String? bookCategoryId;
  int? bookClassId;

  /// Only titles with copies in this library; exclusive with [bookClassId] (Firestore allows one array filter).
  String? bookLibraryId;

  /// `active`, `inactive`, or null for both.
  String? bookStatus;

  /// Everyone who has borrowed, by ERP ID, filtered in Firestore by the fields below.
  late final members = _pager<LibraryMember>();
  MemberKind memberKind = MemberKind.all;

  /// Only members who borrowed from this library (null = every library).
  String? memberLibraryId;

  /// True for blocked members, false for those who can borrow, null for both.
  bool? memberBlocked;

  /// Only members with books out.
  bool memberOnLoan = false;

  /// Words of the member's name or admission number (web only), within the filters.
  String memberSearch = '';

  bool get membersFiltered =>
      memberSearch.isNotEmpty ||
      memberLibraryId != null ||
      memberKind != MemberKind.all ||
      memberBlocked != null ||
      memberOnLoan;

  /// Issued Books: active loans, earliest due first, filtered in Firestore by the fields below.
  late final loans = _pager<LibraryLoan>();
  String? loanLibraryId;
  int? loanClassId;

  /// Section name within [loanClassId].
  String? loanSection;

  /// Issue-date period of the list; [loanRange] holds its days (null = any time).
  LibraryDatePreset? loanPeriod;
  DateTimeRange? loanRange;
  LoanDueFilter? loanDue;

  /// Words of a book title, member name or admission number; overrides the other filters.
  String loanSearch = '';

  bool get loansFiltered =>
      loanSearch.isNotEmpty ||
      loanLibraryId != null ||
      loanClassId != null ||
      loanSection != null ||
      loanRange != null ||
      loanDue != null;

  /// The next active loans due, for the overview (ignores the Issued Books filters).
  List<LibraryLoan> dueNext = [];
  bool dueNextLoading = false;
  String? dueNextError;

  /// Fines, newest first, filtered in Firestore by the fields below.
  late final fines = _pager<LibraryFine>();

  String? fineLibraryId;

  /// `outstanding`, `partially_paid`, `paid`, `waived`, or null for every status.
  String? fineStatus;

  /// `overdue`, `lost`, `damaged`, or null for every type.
  String? fineType;

  /// Exact fine ID or accession number; overrides the other filters.
  String fineSearch = '';

  bool get finesFiltered =>
      fineSearch.isNotEmpty ||
      fineLibraryId != null ||
      fineStatus != null ||
      fineType != null;

  /// Lost and damaged incidents, newest first, filtered in Firestore by the fields below.
  late final incidents = _pager<LibraryIncident>();

  String? incidentLibraryId;

  /// `open`, `resolved`, or null for both.
  String? incidentStatus;

  /// `lost`, `damaged`, or null for both.
  String? incidentType;

  /// Words of the book title, member name or admission number (web only), combined with the filters.
  String incidentSearch = '';

  bool get incidentsFiltered =>
      incidentSearch.isNotEmpty ||
      incidentLibraryId != null ||
      incidentStatus != null ||
      incidentType != null;

  /// The student (`STUDENT`) or staff member (`EMPLOYEE`) with [identifier] (student admission number or RFID, staff number or RFID) in the ERP, or null.
  Future<LibraryPerson?> findPerson(String type, String identifier) =>
      _people.findByIdentifier(type, identifier);

  Future<List<StudentData>> studentsOf(int classId, String? section) =>
      _people.studentsOf(classId, section);

  LibraryPerson studentPerson(StudentData student, {bool staff = false}) =>
      _people.personFrom(student, memberType: staff ? 'EMPLOYEE' : 'STUDENT');

  LibraryCategory? category(String? id) =>
      categories.where((category) => category.id == id).firstOrNull;

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

  String? _scopedUserId;

  /// Restricts the module to the libraries assigned to [userId] (a librarian); set by the app on every sign-in.
  void scopeTo({required String? userId, required bool restricted}) {
    if (userId == _scopedUserId && restricted == _service.restricted) return;
    _scopedUserId = userId;
    _service.scopeTo(userId: userId, restricted: restricted);
    libraries = [];
    categories = [];
    policies = [];
    notifyListeners();
  }

  /// A librarian never sees "All libraries": the lists are always of one assigned library.
  bool get restricted => _service.restricted;

  /// The Library filter is pointless with a single library.
  bool get showLibraryFilter => libraries.length > 1;

  /// Drops the cached ERP classes (sign-out or branch change).
  void clearSession() {
    _people.clearCache();
    standards = [];
    notifyListeners();
  }

  /// The ERP class name; a class missing from the ERP shows as `Class <id>`.
  String className(int id) =>
      standards.where((standard) => standard.id == id).firstOrNull?.name ??
      'Class $id';

  /// Class and section as shown in lists, e.g. `Class 5 A`; `-` for staff.
  String classLabel(int? classId, String? section) => classId == null
      ? '-'
      : section == null || section.isEmpty
      ? className(classId)
      : '${className(classId)} ($section)';

  List<LibraryCategory> get topCategories =>
      categories.where((category) => category.parentId == null).toList();

  /// Loads the user's permissions and the small master lists.
  Future<void> loadMasters() =>
      _busy((loading) => isLoading = loading, () async {
        access = await _service.access();
        final (loadedLibraries, loadedCategories, loadedPolicies) = await (
          _service.libraries(),
          _service.categories(),
          _service.policies(),
        ).wait;
        libraries = loadedLibraries;
        categories = loadedCategories;
        policies = loadedPolicies;
      });

  /// Applies the given filters and reloads the catalogue from its first page.
  Future<void> loadBooks({
    String? search,
    String? categoryId,
    bool clearCategory = false,
    int? classId,
    bool clearClass = false,
    String? libraryId,
    bool clearLibrary = false,
    String? status,
    bool clearStatus = false,
  }) async {
    bookSearch = (search ?? bookSearch).trim();
    bookCategoryId = clearCategory ? null : (categoryId ?? bookCategoryId);
    bookClassId = clearClass ? null : (classId ?? bookClassId);
    bookLibraryId = clearLibrary ? null : (libraryId ?? bookLibraryId);
    if (classId != null) bookLibraryId = null;
    if (libraryId != null) bookClassId = null;
    bookStatus = clearStatus ? null : (status ?? bookStatus);
    final categoryIds = categoryScope(bookCategoryId);
    final query = bookSearch;
    if (query.isEmpty) {
      await books.loadQuery(
        await _service.booksQuery(
          libraryId: bookLibraryId,
          categoryIds: categoryIds,
          classId: bookClassId,
          status: bookStatus,
        ),
        (document) => LibraryBook.fromMap(document.id, document.data()!),
      );
    } else {
      await books.load(({
        required after,
        required offset,
        required limit,
      }) async {
        final page = await _service.searchBooks(
          query,
          libraryId: bookLibraryId,
          categoryIds: categoryIds,
          classId: bookClassId,
          status: bookStatus,
          offset: offset,
          limit: limit,
        );
        return PagedResult(page.items, null, hasMore: page.hasMore);
      });
    }
  }

  /// Loads the first page of members for the current filters.
  Future<void> loadMembers() => _loadSearchable(
    members,
    memberSearch,
    (query, {required offset, required limit}) => _service.searchMembers(
      query,
      libraryId: memberLibraryId,
      memberType: memberKind.memberType,
      blocked: memberBlocked,
      onLoan: memberOnLoan,
      offset: offset,
      limit: limit,
    ),
    () => _service.membersQuery(
      libraryId: memberLibraryId,
      memberType: memberKind.memberType,
      blocked: memberBlocked,
      onLoan: memberOnLoan,
    ),
    (document) => LibraryMember.fromMap(document.id, document.data()!),
  );

  /// Clears every members filter and reloads.
  Future<void> clearMemberFilters() {
    memberKind = MemberKind.all;
    memberLibraryId = null;
    memberBlocked = null;
    memberOnLoan = false;
    memberSearch = '';
    return loadMembers();
  }

  /// Reloads Issued Books from its first page with the current filters.
  Future<void> loadLoans() => _loadSearchable(
    loans,
    loanSearch,
    (query, {required offset, required limit}) => _service.searchLoans(
      query,
      libraryId: loanLibraryId,
      offset: offset,
      limit: limit,
    ),
    () async => _service.activeLoansQuery(
      library: library(loanLibraryId),
      classId: loanClassId,
      section: loanSection,
      issued: loanRange,
      due: loanDue,
    ),
    (document) => LibraryLoan.fromMap(document.id, document.data()!),
  );

  /// Clears every Issued Books filter and reloads.
  Future<void> clearLoanFilters() {
    loanLibraryId = null;
    loanClassId = null;
    loanSection = null;
    loanPeriod = null;
    loanRange = null;
    loanDue = null;
    loanSearch = '';
    return loadLoans();
  }

  /// Loads the first [count] active loans by due date into [dueNext], of one [library] when given.
  Future<void> loadDueNext({SchoolLibrary? library, int count = 8}) async {
    dueNextLoading = true;
    dueNextError = null;
    notifyListeners();
    try {
      final snapshot = await (await _service.activeLoansQuery(library: library))
          .limit(count)
          .get();
      dueNext = [
        for (final document in snapshot.docs)
          LibraryLoan.fromMap(document.id, document.data()),
      ];
    } catch (error) {
      dueNextError = callableErrorMessage(error);
    } finally {
      dueNextLoading = false;
      notifyListeners();
    }
  }

  /// Loads [pager] from the text search when [search] is set, else from the filtered [query].
  Future<void> _loadSearchable<T>(
    FirestorePager<T> pager,
    String search,
    Future<({List<T> items, bool hasMore})> Function(
      String query, {
      required int offset,
      required int limit,
    })
    searchPage,
    Future<Query<Map<String, dynamic>>> Function() query,
    T Function(DocumentSnapshot<Map<String, dynamic>> document) fromDocument,
  ) async {
    if (search.isEmpty) {
      return pager.loadQuery(await query(), fromDocument);
    }
    await pager.load(({required after, required offset, required limit}) async {
      final page = await searchPage(search, offset: offset, limit: limit);
      return PagedResult(page.items, null, hasMore: page.hasMore);
    });
  }

  /// A pager whose failures become [errorMessage] and whose changes rebuild listeners.
  FirestorePager<T> _pager<T>() {
    // Loading until the page's first load, so lists show a skeleton, not the empty state.
    final pager = FirestorePager<T>()..loading = true;
    pager.addListener(() {
      final error = pager.error;
      if (error != null) errorMessage = callableErrorMessage(error);
      notifyListeners();
    });
    return pager;
  }

  /// Loads the first page of fines and their totals for the current filters.
  Future<void> loadFines() async {
    final query = await _service.finesQuery(
      libraryId: fineLibraryId,
      status: fineStatus,
      type: fineType,
      search: fineSearch,
    );
    await fines.loadQuery(
      query,
      (document) => LibraryFine.fromMap(document.id, document.data()!),
    );
  }

  /// Clears every fines filter and reloads.
  Future<void> clearFineFilters() {
    fineLibraryId = null;
    fineStatus = null;
    fineType = null;
    fineSearch = '';
    return loadFines();
  }

  /// Loads the first page of incidents for the current filters.
  Future<void> loadIncidents() {
    final libraryId = incidentLibraryId;
    final status = incidentStatus;
    final type = incidentType;
    return _loadSearchable(
      incidents,
      incidentSearch,
      (query, {required offset, required limit}) => _service.searchIncidents(
        query,
        libraryId: libraryId,
        status: status,
        type: type,
        offset: offset,
        limit: limit,
      ),
      () async => _service.incidentsQuery(
        libraryId: libraryId,
        status: status,
        type: type,
      ),
      (document) => LibraryIncident.fromMap(document.id, document.data()!),
    );
  }

  /// Clears every incident filter and reloads.
  Future<void> clearIncidentFilters() {
    incidentLibraryId = null;
    incidentStatus = null;
    incidentType = null;
    incidentSearch = '';
    return loadIncidents();
  }

  SchoolLibrary? library(String? id) =>
      libraries.where((library) => library.id == id).firstOrNull;

  // Writes return true on success, else set [errorMessage].

  Future<bool> saveLibrary(Map<String, Object?> data) =>
      _write(() => saveMasterDocument('libraries', data), reload: loadMasters);

  Future<bool> setLibraryActive(String id, {required bool active}) => _write(
    () => setMasterActive('libraries', id, active: active),
    reload: loadMasters,
  );

  Future<bool> saveCategory(Map<String, Object?> data) => _write(
    () => saveMasterDocument('libraryCategories', data),
    reload: loadMasters,
  );

  Future<bool> setCategoryActive(String id, {required bool active}) => _write(
    () => setMasterActive('libraryCategories', id, active: active),
    reload: loadMasters,
  );

  /// Barcodes of the copies the last [saveBook] / [addCopies] created, for printing their labels.
  List<String> createdBarcodes = const [];

  /// Saves a book; for a new one, [copies] (`libraryId`, `quantity`, `shelf`, optional `barcodes`) also creates its copies.
  Future<bool> saveBook(
    Map<String, Object?> data, {
    Map<String, Object?>? copies,
    String? copiesRequestId,
  }) => _write(() async {
    createdBarcodes = const [];
    final id = await _writes.saveBook(data);
    if (copies != null) {
      createdBarcodes = await _service.createBook({
        'catalogueId': id,
        ...copies,
      }, requestId: copiesRequestId);
    }
  }, reload: loadBooks);

  /// Adds [copies] (as for [saveBook]) to an existing title.
  Future<bool> addCopies(
    String catalogueId,
    Map<String, Object?> copies, {
    required String requestId,
  }) => _write(() async {
    createdBarcodes = await _service.createBook({
      'catalogueId': catalogueId,
      ...copies,
    }, requestId: requestId);
  }, reload: loadBooks);

  /// Imports one book of a checked sheet: the title (an existing one with the same details gets the
  /// copies instead), then its copies in [copyBatches]. [requestId] names a new title and prefixes
  /// each batch's request ID, so importing the same book again after a failure adds no duplicate.
  /// The books list reloads with [loadBooks] afterwards.
  Future<BookImportResult> importBook(
    Map<String, Object?> book,
    List<Map<String, Object?>> copyBatches,
    String requestId,
  ) async {
    var created = false;
    var added = 0;
    try {
      var id = await _writes.findTitleId(book);
      if (id == null) {
        id = await _writes.saveBook({'id': requestId, ...book});
        created = true;
      }
      for (var index = 0; index < copyBatches.length; index++) {
        await _service.createBook({
          'catalogueId': id,
          ...copyBatches[index],
        }, requestId: '$requestId-$index');
        added += copyBatches[index]['quantity']! as int;
      }
      return BookImportResult(created: created, copiesAdded: added);
    } on Object catch (error) {
      return BookImportResult(
        created: created,
        copiesAdded: added,
        error: callableErrorMessage(error),
      );
    }
  }

  Future<String?> findTitleId(Map<String, Object?> data) =>
      _writes.findTitleId(data);

  Future<bool> setBookActive(String id, {required bool active}) => _write(
    () => _writes.setBookActive(id, active: active),
    reload: loadBooks,
  );

  Future<bool> updateCopy(Map<String, Object?> data) =>
      _write(() => _writes.updateCopy(data));

  Future<bool> setCopyStatus(String id, String status, String? reason) =>
      _write(() => _loanWrites.setCopyStatus(id, status, reason));

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
        ...defaultPolicy,
        'libraryId': schoolLibrary.id,
      });
    }
  }, reload: loadMasters);

  Future<bool> setPolicyActive(String id, {required bool active}) => _write(
    () => _writes.setPolicyActive(id, active: active),
    reload: loadMasters,
  );

  Future<bool> issueLoan(
    LibraryPerson person,
    String barcode, {
    String? remarks,
  }) => _write(
    () => _loanWrites.issue(
      person: person.toPayload(),
      barcode: barcode,
      remarks: remarks,
    ),
    reload: loadLoans,
  );

  Future<bool> returnLoan({
    required String id,
    required String condition,
    String? remarks,
  }) => _write(
    () =>
        _loanWrites.returnLoan(id: id, condition: condition, remarks: remarks),
    reload: loadLoans,
  );

  Future<bool> renewLoan(String id) =>
      _write(() => _loanWrites.renew(id), reload: loadLoans);

  Future<bool> resolveIncident({
    required String id,
    required String resolution,
    double? repairCost,
    double? charge,
    String? remarks,
  }) => _write(
    () => _loanWrites.resolveIncident(
      id: id,
      resolution: resolution,
      repairCost: repairCost,
      charge: charge,
      remarks: remarks,
    ),
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

  Future<bool> markLoanLost({
    required String id,
    String? reason,
    double? charge,
  }) => _write(
    () => _loanWrites.markLost(id: id, reason: reason, charge: charge),
    reload: loadLoans,
  );

  // Dashboard and reports (Lib-8).
  /// Rows of the summary reports (monthly, student, staff).
  List<ReportRow> reportRows = [];

  /// True when the summary report stopped at [LibraryService.loanLimit] loans.
  bool reportCapped = false;

  /// The loans report, newest first, paged in Firestore.
  late final reportLoans = _pager<ReportRow>();
  Query<Map<String, dynamic>>? _reportLoansQuery;
  final Map<String, LibraryBook> _titles = {};
  bool insightsLoading = false;

  String titleName(Object? id) => _titles[id]?.title ?? '$id';

  String libraryName(Object? id) => library('$id')?.name ?? '$id';

  /// Who and which books a policy covers, e.g. `Students · Fiction, Science`.
  String policyScope(LibraryPolicy policy) =>
      '${policy.appliesTo} · ${policy.categoryIds.isEmpty ? 'All other categories' : policy.categoryIds.map(categoryName).join(', ')}';

  String categoryName(Object? id) => category('$id')?.name ?? '$id';

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

  /// Live overview figures; the caller listens for as long as it is on screen.
  Stream<Map<String, num?>> watchDashboard({SchoolLibrary? library}) =>
      _service.dashboard(library: library);

  Future<void> loadReport(
    LibraryReportDef def, {
    required DateTime from,
    required DateTime to,
    SchoolLibrary? library,
    String? status,
  }) async {
    if (def.kind != LibraryReportKind.loans) {
      return _busy((loading) => insightsLoading = loading, () async {
        final report = await _service.report(
          def,
          library: library,
          from: from,
          to: to,
        );
        reportRows = report.rows;
        reportCapped = report.capped;
      });
    }
    final query = _reportLoansQuery = await _service.reportLoansQuery(
      from: from,
      to: to,
      library: library,
      status: status,
    );
    await reportLoans.load(({
      required after,
      required offset,
      required limit,
    }) async {
      final page = await fetchPage(
        query,
        (document) => {...document.data()!, 'id': document.id},
        after: after,
        limit: limit,
      );
      await _loadTitles(page.items);
      return page;
    }, count: () async => (await query.count().get()).count ?? 0);
  }

  /// Every loan of the current loans report (up to [LibraryService.loanLimit]), for CSV export.
  Future<List<ReportRow>> exportReportLoans() async {
    final snapshot = await _reportLoansQuery!
        .limit(LibraryService.loanLimit)
        .get();
    final rows = [
      for (final document in snapshot.docs)
        {...document.data(), 'id': document.id},
    ];
    await _loadTitles(rows);
    return rows;
  }

  Future<void> _loadTitles(List<ReportRow> rows) async {
    final need = {
      for (final row in rows)
        if (row['catalogueId'] is String &&
            !_titles.containsKey(row['catalogueId']))
          row['catalogueId'] as String,
    };
    if (need.isNotEmpty) _titles.addAll(await _service.titlesByIds(need));
  }

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

/// What importing one book did: whether its title was new, how many copies were added, and why it stopped, if it did.
class BookImportResult {
  const BookImportResult({
    required this.created,
    required this.copiesAdded,
    this.error,
  });

  final bool created;
  final int copiesAdded;
  final String? error;
}
