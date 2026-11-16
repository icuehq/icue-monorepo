import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/import/concurrent.dart';
import 'package:school_library/src/models/library_copies.dart';
import 'package:school_library/src/models/library_fines.dart';
import 'package:school_library/src/models/library_incidents.dart';
import 'package:school_library/src/models/library_insights.dart';
import 'package:school_library/src/models/library_loans.dart';
import 'package:school_library/src/models/library_masters.dart';
import 'package:school_library/src/models/library_members.dart';

/// Library reads from Firestore; its remaining writes go through callables (`LibraryWrites` and `LoanWrites` have the client ones).
@lazySingleton
class LibraryService {
  Future<List<T>> _all<T>(
    String path,
    T Function(String id, Map<String, dynamic> data) parse,
  ) async {
    final snapshot = await (await branchCollection(path)).get();
    return [
      for (final document in snapshot.docs) parse(document.id, document.data()),
    ];
  }

  /// One document by ID, or null when it does not exist.
  Future<T?> _one<T>(
    String collection,
    String id,
    T Function(String id, Map<String, dynamic> data) parse,
  ) async {
    final document = await (await branchCollection(collection)).doc(id).get();
    return document.exists ? parse(document.id, document.data()!) : null;
  }

  /// The signed-in user's module permissions.
  Future<ModuleAccess> access() async {
    // branchCollection waits for the sign-in, so read the user after it.
    final collection = await branchCollection('userAccess');
    final doc = await collection
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    return ModuleAccess.fromMap(doc.data() ?? {});
  }

  // A librarian works only in the libraries assigned to them (`libraries/{id}.librarianId`); everyone else sees all.
  String? _userId;
  bool _restricted = false;
  List<SchoolLibrary>? _assigned;

  /// Set on sign-in. A [restricted] user reads only libraries whose librarian is [userId], and every list,
  /// report and figure is narrowed to one of them (the first when no library is chosen).
  void scopeTo({required String? userId, required bool restricted}) {
    _userId = userId;
    _restricted = restricted;
    _assigned = null;
  }

  bool get restricted => _restricted;

  Future<List<SchoolLibrary>> libraries() async {
    if (!_restricted) {
      return _sortedNewest(
        'libraries',
        SchoolLibrary.fromMap,
        (item) => item.createdAt,
        (item) => item.name,
      );
    }
    final snapshot = await (await branchCollection('libraries'))
        .where('librarianId', isEqualTo: _userId)
        .get();
    return _assigned =
        [
          for (final document in snapshot.docs)
            SchoolLibrary.fromMap(document.id, document.data()),
        ]..sort((a, b) {
          final newest = (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          );
          return newest != 0
              ? newest
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
  }

  /// [selected], or for a restricted user the first assigned library; with none assigned a library that matches nothing.
  Future<SchoolLibrary?> _scopedLibrary(SchoolLibrary? selected) async {
    if (!_restricted || selected != null) return selected;
    final assigned = _assigned ?? await libraries();
    return assigned.firstOrNull ??
        const SchoolLibrary(id: '-', name: '', active: false);
  }

  /// Same as [_scopedLibrary] for a library ID.
  Future<String?> _scopedLibraryId(String? selected) async =>
      selected != null || !_restricted
      ? selected
      : (await _scopedLibrary(null))?.id;

  /// A librarian sees only the categories of the libraries assigned to them.
  Future<List<LibraryCategory>> categories() async {
    final categories = await _sortedNewest(
      'libraryCategories',
      LibraryCategory.fromMap,
      (item) => item.createdAt,
      (item) => item.name,
    );
    if (!_restricted) return categories;
    final ids = {for (final library in await libraries()) library.id};
    return [
      for (final category in categories)
        if (ids.contains(category.libraryId)) category,
    ];
  }

  /// Newest first; items without a creation time (older records) follow, by name.
  Future<List<T>> _sortedNewest<T>(
    String path,
    T Function(String id, Map<String, dynamic> data) parse,
    DateTime? Function(T item) createdAt,
    String Function(T item) name,
  ) async => (await _all(path, parse))
    ..sort((left, right) {
      final newest = (createdAt(right) ?? DateTime(0)).compareTo(
        createdAt(left) ?? DateTime(0),
      );
      return newest != 0
          ? newest
          : name(left).toLowerCase().compareTo(name(right).toLowerCase());
    });

  /// Titles, newest first, optionally within [categoryIds] (a category and its subcategories),
  /// meant for class [classId] and with [status] (`active`/`inactive`); page it with `FirestorePager`.
  Future<Query<Map<String, dynamic>>> booksQuery({
    String? libraryId,
    List<String>? categoryIds,
    int? classId,
    String? status,
  }) async {
    // Firestore allows one array-contains per query: a class filter replaces the librarian's implicit library scope.
    if (classId == null) libraryId = await _scopedLibraryId(libraryId);
    Query<Map<String, dynamic>> query = await branchCollection(
      'libraryCatalogue',
    );
    if (categoryIds != null) {
      query = query.where('categoryId', whereIn: categoryIds);
    }
    if (libraryId != null) {
      query = query.where('libraryIds', arrayContains: libraryId);
    }
    if (classId != null) {
      query = query.where('classIds', arrayContains: classId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.orderBy('createdAt', descending: true);
  }

  /// Whole-word search by title, author, publisher or keyword (`search` database, web only).
  Future<({List<LibraryBook> items, bool hasMore})> searchBooks(
    String query, {
    String? libraryId,
    List<String>? categoryIds,
    int? classId,
    String? status,
    int offset = 0,
    int limit = 25,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    final page = await searchMirror(
      'libraryCatalogue',
      query,
      sortField: 'createdAt',
      descending: true,
      categoryIds: categoryIds,
      arrayHas: {'classIds': ?classId, 'libraryIds': ?libraryId},
      equals: {'status': ?status},
      offset: offset,
      limit: limit,
    );
    return (
      items: [
        for (final row in page.rows) LibraryBook.fromMap(row.id, row.data),
      ],
      hasMore: page.hasMore,
    );
  }

  Future<LibraryBook?> book(String id) =>
      _one('libraryCatalogue', id, LibraryBook.fromMap);

  /// Copies of a title across all libraries, by barcode.
  Future<List<LibraryCopy>> copiesOf(String catalogueId) async {
    final query = (await branchCollection('libraryCopies'))
        .where('catalogueId', isEqualTo: catalogueId);
    final snapshot = await query.get();
    return [
      for (final document in snapshot.docs)
        LibraryCopy.fromMap(document.id, document.data()),
    ]..sort((left, right) {
      final newest = (right.createdAt ?? DateTime(0)).compareTo(
        left.createdAt ?? DateTime(0),
      );
      return newest != 0 ? newest : left.barcode.compareTo(right.barcode);
    });
  }

  /// A copy by barcode (its document ID).
  Future<LibraryCopy?> findCopy(String code) =>
      _one('libraryCopies', code.trim(), LibraryCopy.fromMap);

  /// Documents of [collection] with the given [ids], 30 per query (Firestore `whereIn`), 6 queries at a time.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _byIds(
    String collection,
    Iterable<String> ids,
  ) async {
    final reference = await branchCollection(collection);
    final unique = ids.toSet().toList();
    final chunks = [
      for (var start = 0; start < unique.length; start += 30)
        unique.skip(start).take(30).toList(),
    ];
    final found = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    await forEachConcurrently(chunks, 6, (chunk) async {
      found.addAll(
        (await reference.where(FieldPath.documentId, whereIn: chunk).get())
            .docs,
      );
    });
    return found;
  }

  /// The [barcodes] that already belong to a copy (its document ID).
  Future<Set<String>> existingBarcodes(List<String> barcodes) async => {
    for (final document in await _byIds('libraryCopies', barcodes)) document.id,
  };

  /// A librarian sees only the policies of the libraries assigned to them.
  Future<List<LibraryPolicy>> policies() async {
    final policies = await _sortedNewest(
      'libraryBorrowingPolicies',
      LibraryPolicy.fromMap,
      (item) => item.createdAt,
      (item) => item.name,
    );
    if (!_restricted) return policies;
    final ids = {for (final library in await libraries()) library.id};
    return [
      for (final policy in policies)
        if (ids.contains(policy.libraryId)) policy,
    ];
  }

  /// Members, newest first, narrowed by the filters. [memberType] is `student` or `teacher`.
  Future<Query<Map<String, dynamic>>> membersQuery({
    String? libraryId,
    String? memberType,
    bool? blocked,
    bool onLoan = false,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    Query<Map<String, dynamic>> query = await branchCollection(
      'libraryMembers',
    );
    if (libraryId != null) {
      query = query.where('libraryIds', arrayContains: libraryId);
    }
    if (memberType != null) {
      query = query.where('memberType', isEqualTo: memberType);
    }
    if (blocked != null) query = query.where('blocked', isEqualTo: blocked);
    if (onLoan) {
      query = query
          .where('activeLoans', isGreaterThan: 0)
          .orderBy('activeLoans');
    }
    return query.orderBy('createdAt', descending: true);
  }

  /// Members whose name or admission number matches [query] (whole words or typed prefixes), by ERP ID,
  /// narrowed by the same filters (`search` database, web only, then the members from Firestore).
  Future<({List<LibraryMember> items, bool hasMore})> searchMembers(
    String query, {
    String? libraryId,
    String? memberType,
    bool? blocked,
    bool onLoan = false,
    int offset = 0,
    int limit = 25,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    final page = await searchMirror(
      'libraryMembers',
      query,
      sortField: 'createdAt',
      descending: true,
      arrayHas: {'libraryIds': ?libraryId},
      equals: {
        'memberType': ?memberType,
        'blocked': ?blocked,
        if (onLoan) 'onLoan': true,
      },
      offset: offset,
      limit: limit,
    );
    final ids = [for (final row in page.rows) row.id];
    final found = {
      for (final document in await _byIds('libraryMembers', ids))
        document.id: LibraryMember.fromMap(document.id, document.data()),
    };
    return (items: [for (final id in ids) ?found[id]], hasMore: page.hasMore);
  }

  /// One member by ERP ID (the member document ID).
  Future<LibraryMember?> member(int personErpId) =>
      _one('libraryMembers', '$personErpId', LibraryMember.fromMap);

  /// Active loans, newest issue first, narrowed by the Issued Books filters; page it with `FirestorePager`.
  Future<Query<Map<String, dynamic>>> activeLoansQuery({
    SchoolLibrary? library,
    int? classId,
    String? section,
    DateTimeRange? issued,
    LoanDueFilter? due,
  }) async {
    library = await _scopedLibrary(library);
    var query = _scoped(
      (await branchCollection('libraryLoans'))
          .where('status', isEqualTo: 'active'),
      library: library,
    );
    if (classId != null) {
      query = query.where('memberClassId', isEqualTo: classId);
    }
    if (section != null) {
      query = query.where('memberSection', isEqualTo: section);
    }
    final today = todayIST();
    query = switch (due) {
      LoanDueFilter.overdue => query.where(
        'dueDate',
        isLessThan: dayTimestamp(today),
      ),
      LoanDueFilter.dueToday => query.where(
        'dueDate',
        isEqualTo: dayTimestamp(today),
      ),
      null => query,
    };
    if (issued != null) {
      query = query.where(
        'issuedDate',
        isGreaterThanOrEqualTo: dayTimestamp(issued.start.toApiDate()),
        isLessThanOrEqualTo: dayTimestamp(issued.end.toApiDate()),
      );
    }
    // An overdue filter is a range on dueDate, which Firestore needs as the first order.
    return due == LoanDueFilter.overdue
        ? query
              .orderBy('dueDate', descending: true)
              .orderBy('issuedDate', descending: true)
        : query.orderBy('issuedDate', descending: true);
  }

  /// Active loans whose book title, member name or admission number holds every word of [query],
  /// newest issue first (`search` database, web only, then the loans themselves from Firestore).
  Future<({List<LibraryLoan> items, bool hasMore})> searchLoans(
    String query, {
    String? libraryId,
    int offset = 0,
    int limit = 25,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    final page = await searchMirror(
      'libraryLoans',
      query,
      sortField: 'issuedDate',
      descending: true,
      equals: {'status': 'active', 'libraryId': ?libraryId},
      offset: offset,
      limit: limit,
    );
    final ids = [for (final row in page.rows) row.id];
    final found = {
      for (final document in await _byIds('libraryLoans', ids))
        document.id: LibraryLoan.fromMap(document.id, document.data()),
    };
    return (items: [for (final id in ids) ?found[id]], hasMore: page.hasMore);
  }

  /// The active loan of a copy, if it is out.
  Future<LibraryLoan?> activeLoanOf(String barcode) async {
    final snapshot = await (await branchCollection('libraryLoans'))
        .where('barcode', isEqualTo: barcode)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    return snapshot.docs.isEmpty
        ? null
        : LibraryLoan.fromMap(
            snapshot.docs.first.id,
            snapshot.docs.first.data(),
          );
  }

  /// Fines, newest first.
  Future<Query<Map<String, dynamic>>> finesQuery({
    String? libraryId,
    String? status,
    String? type,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    Query<Map<String, dynamic>> query = await branchCollection('libraryFines');
    if (libraryId != null) {
      query = query.where('libraryId', isEqualTo: libraryId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);
    if (type != null) query = query.where('type', isEqualTo: type);
    return query.orderBy('createdAt', descending: true);
  }

  /// Fines whose member name, admission number, book title or accession number matches [query]
  /// (whole words or typed prefixes), newest first, narrowed by the same filters
  /// (`search` database, web only, then the fines themselves from Firestore).
  Future<({List<LibraryFine> items, bool hasMore})> searchFines(
    String query, {
    String? libraryId,
    String? status,
    String? type,
    int offset = 0,
    int limit = 25,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    final page = await searchMirror(
      'libraryFines',
      query,
      sortField: 'createdAt',
      descending: true,
      equals: {'libraryId': ?libraryId, 'status': ?status, 'type': ?type},
      offset: offset,
      limit: limit,
    );
    final ids = [for (final row in page.rows) row.id];
    final found = {
      for (final document in await _byIds('libraryFines', ids))
        document.id: LibraryFine.fromMap(document.id, document.data()),
    };
    return (items: [for (final id in ids) ?found[id]], hasMore: page.hasMore);
  }

  /// Fines of one member that are not yet settled, newest first.
  Future<List<LibraryFine>> openFines(int personErpId) async {
    final snapshot = await (await branchCollection('libraryFines'))
        .where('personErpId', isEqualTo: personErpId)
        .where('status', whereIn: ['outstanding', 'partially_paid'])
        .get();
    final fines =
        [
          for (final document in snapshot.docs)
            LibraryFine.fromMap(document.id, document.data()),
        ]..sort(
          (first, second) => (second.createdAt ?? DateTime(0)).compareTo(
            first.createdAt ?? DateTime(0),
          ),
        );
    return fines;
  }

  /// A single fine by ID.
  Future<LibraryFine?> fine(String id) =>
      _one('libraryFines', id, LibraryFine.fromMap);

  /// Lost/damaged incidents, newest first.
  Future<Query<Map<String, dynamic>>> incidentsQuery({
    String? libraryId,
    String? status,
    String? type,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    Query<Map<String, dynamic>> query = await branchCollection(
      'libraryIncidents',
    );
    if (libraryId != null) {
      query = query.where('libraryId', isEqualTo: libraryId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);
    if (type != null) query = query.where('type', isEqualTo: type);
    return query.orderBy('createdAt', descending: true);
  }

  /// Incidents whose book title, member name or admission number holds every word of [query],
  /// newest first (`search` database, web only, then the incidents themselves from Firestore).
  Future<({List<LibraryIncident> items, bool hasMore})> searchIncidents(
    String query, {
    String? libraryId,
    String? status,
    String? type,
    int offset = 0,
    int limit = 25,
  }) async {
    libraryId = await _scopedLibraryId(libraryId);
    final page = await searchMirror(
      'libraryIncidents',
      query,
      sortField: 'createdAt',
      descending: true,
      equals: {'libraryId': ?libraryId, 'status': ?status, 'type': ?type},
      offset: offset,
      limit: limit,
    );
    final ids = [for (final row in page.rows) row.id];
    final found = {
      for (final document in await _byIds('libraryIncidents', ids))
        document.id: LibraryIncident.fromMap(document.id, document.data()),
    };
    return (items: [for (final id in ids) ?found[id]], hasMore: page.hasMore);
  }

  // --- writes: masters are plain client CRUD (`firestore.rules`); books and copy status are callables, same requestId on user retry ---

  /// Returns the new copies' barcodes.
  Future<List<String>> createBook(
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    final result = await callFunction(
      'library-book-create',
      data: data,
      requestId: requestId,
    ) as Map<Object?, Object?>;
    return [
      for (final row in result['barcodes']! as List<Object?>) row! as String,
    ];
  }

  // ---- Dashboard and reports (Lib-8) ----

  /// The branch's records, narrowed to one [library] when given.
  Query<Map<String, dynamic>> _scoped(
    Query<Map<String, dynamic>> query, {
    SchoolLibrary? library,
  }) =>
      library == null ? query : query.where('libraryId', isEqualTo: library.id);

  /// Live dashboard figures for the branch (or one [library]), from the analytics summary the audit triggers keep
  /// (`libraryStats/overall`). A summary nothing has written yet reads as zeros.
  Stream<Map<String, num?>> dashboard({SchoolLibrary? library}) =>
      // Multi-listener: a rebuilt page subscribes again, which an `async*` stream would refuse.
      Stream.multi((controller) async {
        StreamSubscription<Object?>? subscription;
        controller.onCancel = () => subscription?.cancel();
        final summary = (await branchCollection(Collections.libraryStats))
            .doc('overall');
        final scoped = await _scopedLibrary(library);
        if (controller.isClosed) return;
        subscription = summary.snapshots().listen(
          (snapshot) => controller.add(
            overviewFigures(snapshot.data(), scoped?.id, today: todayIST()),
          ),
          onError: controller.addError,
        );
      });

  /// Titles by ID (for report cells).
  Future<Map<String, LibraryBook>> titlesByIds(Iterable<String> ids) async => {
    for (final document in await _byIds('libraryCatalogue', ids))
      document.id: LibraryBook.fromMap(document.id, document.data()),
  };

  static const loanLimit = 5000;

  /// Loans of [library] whose [field] (`issuedDate` / `returnedDate`) falls from [from] to [to].
  Future<Query<Map<String, dynamic>>> _loansBetween(
    SchoolLibrary? library,
    String field,
    DateTime from,
    DateTime to,
  ) async =>
      _scoped(
            await branchCollection('libraryLoans'),
            library: await _scopedLibrary(library),
          )
          .where(field, isGreaterThanOrEqualTo: dayTimestamp(from.toApiDate()))
          .where(field, isLessThanOrEqualTo: dayTimestamp(to.toApiDate()));

  /// The loans report: loans issued in the range, newest first, in [status] when given;
  /// page it with `FirestorePager`.
  Future<Query<Map<String, dynamic>>> reportLoansQuery({
    required DateTime from,
    required DateTime to,
    SchoolLibrary? library,
    String? status,
  }) async {
    var query = await _loansBetween(library, 'issuedDate', from, to);
    if (status != null) query = query.where('status', isEqualTo: status);
    return query.orderBy('issuedDate', descending: true);
  }

  /// Up to [loanLimit] loans in the range, newest first; `capped` when the limit cut some off.
  Future<({List<ReportRow> rows, bool capped})> _loanRows(
    SchoolLibrary? library,
    String field,
    DateTime from,
    DateTime to,
  ) async {
    final snapshot = await (await _loansBetween(
      library,
      field,
      from,
      to,
    )).orderBy(field, descending: true).limit(loanLimit).get();
    return (
      rows: [for (final document in snapshot.docs) document.data()],
      capped: snapshot.docs.length >= loanLimit,
    );
  }

  /// Rows of the summary report [def] (monthly, student or staff) over the loans issued (and,
  /// monthly, returned) from [from] to [to]; the loans report pages [reportLoansQuery] instead.
  Future<({List<ReportRow> rows, bool capped})> report(
    LibraryReportDef def, {
    required DateTime from,
    required DateTime to,
    SchoolLibrary? library,
  }) async {
    final issuedRows = await _loanRows(library, 'issuedDate', from, to);
    final issued = issuedRows.rows;
    if (def.kind == LibraryReportKind.monthly) {
      final returnedRows = await _loanRows(library, 'returnedDate', from, to);
      final months = <String, Map<String, int>>{};
      void add(ReportRow loan, String field, String counter) {
        final month = readDay(loan[field]).substring(0, 7);
        months
            .putIfAbsent(month, () => {'issued': 0, 'returned': 0})
            .update(counter, (total) => total + 1);
      }

      for (final loan in issued) {
        add(loan, 'issuedDate', 'issued');
      }
      for (final loan in returnedRows.rows) {
        add(loan, 'returnedDate', 'returned');
      }
      return (
        rows: [
          for (final month in months.keys.toList()..sort())
            {'month': month, ...months[month]!},
        ],
        capped: issuedRows.capped || returnedRows.capped,
      );
    }
    final memberType = def.kind == LibraryReportKind.student
        ? 'STUDENT'
        : 'EMPLOYEE';
    final today = dayTimestamp(todayIST());
    final members = <Object?, ReportRow>{};
    for (final loan in issued) {
      if (loan['memberType'] != memberType) continue;
      final row = members.putIfAbsent(
        loan['personErpId'],
        () => {
          'personErpId': loan['personErpId'],
          'memberType': memberType,
          'memberName': loan['memberName'],
          'admissionNumber': loan['admissionNumber'],
          'memberClassId': loan['memberClassId'],
          'memberSection': loan['memberSection'],
          'issued': 0,
          'returned': 0,
          'active': 0,
          'overdue': 0,
        },
      );
      row['issued'] = (row['issued'] as int) + 1;
      if (loan['status'] == 'returned') {
        row['returned'] = (row['returned'] as int) + 1;
      }
      if (loan['status'] == 'active') {
        row['active'] = (row['active'] as int) + 1;
        if ((loan['dueDate'] as Timestamp).compareTo(today) < 0) {
          row['overdue'] = (row['overdue'] as int) + 1;
        }
      }
    }
    return (
      rows: members.values.toList()
        ..sort(
          (left, right) =>
              (right['issued'] as int).compareTo(left['issued'] as int),
        ),
      capped: issuedRows.capped,
    );
  }
}
