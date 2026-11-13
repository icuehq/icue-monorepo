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

  Future<List<SchoolLibrary>> libraries() =>
      _sortedByName('libraries', SchoolLibrary.fromMap, (item) => item.name);

  Future<List<LibraryCategory>> categories() => _sortedByName(
    'libraryCategories',
    LibraryCategory.fromMap,
    (item) => item.name,
  );

  Future<List<T>> _sortedByName<T>(
    String path,
    T Function(String id, Map<String, dynamic> data) parse,
    String Function(T item) name,
  ) async => (await _all(path, parse))
    ..sort(
      (left, right) =>
          name(left).toLowerCase().compareTo(name(right).toLowerCase()),
    );

  /// Titles ordered by title, optionally within [categoryIds] (a category and its subcategories),
  /// meant for class [classId] and with [status] (`active`/`inactive`); page it with `FirestorePager`.
  Future<Query<Map<String, dynamic>>> booksQuery({
    List<String>? categoryIds,
    int? classId,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'libraryCatalogue',
    );
    if (categoryIds != null) {
      query = query.where('categoryId', whereIn: categoryIds);
    }
    if (classId != null) {
      query = query.where('classIds', arrayContains: classId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.orderBy('title');
  }

  /// Whole-word search by title, author, publisher or keyword (`search` database, web only).
  Future<({List<LibraryBook> items, bool hasMore})> searchBooks(
    String query, {
    List<String>? categoryIds,
    int? classId,
    String? status,
    int offset = 0,
    int limit = 25,
  }) async {
    final page = await searchMirror(
      'libraryCatalogue',
      query,
      sortField: 'title',
      categoryIds: categoryIds,
      arrayHas: {'classIds': ?classId},
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
    ]..sort((left, right) => left.barcode.compareTo(right.barcode));
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

  Future<List<LibraryPolicy>> policies() => _sortedByName(
    'libraryBorrowingPolicies',
    LibraryPolicy.fromMap,
    (item) => item.name,
  );

  /// Members by ERP ID. [memberType] is `student` or `teacher`; a [search] is an exact ERP ID and ignores the filters.
  Future<Query<Map<String, dynamic>>> membersQuery({
    String? memberType,
    bool? blocked,
    bool onLoan = false,
    String search = '',
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'libraryMembers',
    );
    if (search.isNotEmpty) {
      query = query.where('personErpId', isEqualTo: int.tryParse(search) ?? -1);
    } else {
      if (memberType != null) {
        query = query.where('memberType', isEqualTo: memberType);
      }
      if (blocked != null) query = query.where('blocked', isEqualTo: blocked);
      if (onLoan) {
        query = query
            .where('activeLoans', isGreaterThan: 0)
            .orderBy('activeLoans');
      }
    }
    return query.orderBy('personErpId');
  }

  /// One member by ERP ID (the member document ID).
  Future<LibraryMember?> member(int personErpId) =>
      _one('libraryMembers', '$personErpId', LibraryMember.fromMap);

  /// Active loans by due date, narrowed by the Issued Books filters; page it with `FirestorePager`.
  Future<Query<Map<String, dynamic>>> activeLoansQuery({
    SchoolLibrary? library,
    int? classId,
    String? section,
    DateTimeRange? issued,
    LoanDueFilter? due,
  }) async {
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
    return query.orderBy('dueDate');
  }

  /// Active loans whose book title, member name or admission number holds every word of [query],
  /// earliest due first (`search` database, web only, then the loans themselves from Firestore).
  Future<({List<LibraryLoan> items, bool hasMore})> searchLoans(
    String query, {
    int offset = 0,
    int limit = 25,
  }) async {
    final page = await searchMirror(
      'libraryLoans',
      query,
      sortField: 'dueDate',
      equals: {'status': 'active'},
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

  /// Fines, newest first. A [search] is an exact fine ID or accession number and ignores the filters.
  Future<Query<Map<String, dynamic>>> finesQuery({
    String? status,
    String? type,
    String search = '',
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection('libraryFines');
    if (search.isNotEmpty) {
      final terms = {search, search.toUpperCase()}.toList();
      query = query.where(
        Filter.or(
          Filter(FieldPath.documentId, whereIn: terms),
          Filter('barcode', whereIn: terms),
        ),
      );
    } else {
      if (status != null) query = query.where('status', isEqualTo: status);
      if (type != null) query = query.where('type', isEqualTo: type);
    }
    return query.orderBy('createdAt', descending: true);
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
    String? status,
    String? type,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      'libraryIncidents',
    );
    if (status != null) query = query.where('status', isEqualTo: status);
    if (type != null) query = query.where('type', isEqualTo: type);
    return query.orderBy('createdAt', descending: true);
  }

  /// Incidents whose book title, member name or admission number holds every word of [query],
  /// newest first (`search` database, web only, then the incidents themselves from Firestore).
  Future<({List<LibraryIncident> items, bool hasMore})> searchIncidents(
    String query, {
    String? status,
    String? type,
    int offset = 0,
    int limit = 25,
  }) async {
    final page = await searchMirror(
      'libraryIncidents',
      query,
      sortField: 'createdAt',
      descending: true,
      equals: {'status': ?status, 'type': ?type},
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
  Stream<Map<String, num?>> dashboard({SchoolLibrary? library}) async* {
    final summary = (await branchCollection(Collections.libraryStats))
        .doc('overall');
    yield* summary.snapshots().map(
      (snapshot) =>
          overviewFigures(snapshot.data(), library?.id, today: todayIST()),
    );
  }

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
  ) async => _scoped(await branchCollection('libraryLoans'), library: library)
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

  /// KPI counts of the loans report; a [status] filter leaves the other statuses at zero.
  Future<LoanReportCounts> reportLoanCounts({
    required DateTime from,
    required DateTime to,
    SchoolLibrary? library,
    String? status,
  }) async {
    final base = await _loansBetween(library, 'issuedDate', from, to);
    Future<int> count(Query<Map<String, dynamic>> query) async =>
        (await query.count().get()).count ?? 0;
    Future<int> inStatus(String value, [String? dueBefore]) async {
      if (status != null && status != value) return 0;
      var query = base.where('status', isEqualTo: value);
      if (dueBefore != null) {
        query = query.where('dueDate', isLessThan: dayTimestamp(dueBefore));
      }
      return count(query);
    }

    final [returned, active, lost, overdue] = await Future.wait([
      inStatus('returned'),
      inStatus('active'),
      inStatus('lost'),
      inStatus('active', todayIST()),
    ]);
    return (returned: returned, active: active, overdueOrLost: overdue + lost);
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
