import 'package:core_ui/core_ui.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/library_copies.dart';
import 'package:school_library/src/models/library_fines.dart';
import 'package:school_library/src/models/library_incidents.dart';
import 'package:school_library/src/models/library_insights.dart';
import 'package:school_library/src/models/library_loans.dart';
import 'package:school_library/src/models/library_masters.dart';
import 'package:school_library/src/models/library_members.dart';
import 'package:school_library/src/models/library_reservations.dart';
import 'package:school_library/src/models/library_transfers.dart';
import 'package:school_library/src/models/library_verifications.dart';

/// Library masters: reads from Firestore, writes through callables.
@lazySingleton
class LibraryService {
  Future<List<T>> _all<T>(
    String path,
    T Function(String id, Map<String, dynamic> data) parse,
  ) async {
    final snapshot = await (await schoolCollection(path)).get();
    return [
      for (final document in snapshot.docs) parse(document.id, document.data()),
    ];
  }

  Future<ModuleAccess> access() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await (await schoolCollection('userAccess'))
        .doc(user.uid)
        .get();
    return ModuleAccess.fromMap(doc.data() ?? {});
  }

  Future<List<SchoolLibrary>> libraries() async =>
      (await _all('libraries', SchoolLibrary.fromMap))..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );

  Future<List<LibraryCategory>> categories() async =>
      (await _all('libraryCategories', LibraryCategory.fromMap))..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );

  /// A page of titles by title, optionally within [categoryId] (Firestore query).
  Future<PagedResult<LibraryBook>> books({
    String? categoryId,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> query = await schoolCollection(
      'libraryCatalogue',
    );
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    return fetchPage(
      query.orderBy('title'),
      (document) => LibraryBook.fromMap(document.id, document.data()!),
      after: after,
    );
  }

  /// Whole-word search by title, author, publisher or keyword, or an exact ISBN (Functions).
  Future<({List<LibraryBook> items, bool hasMore})> searchBooks(
    String query, {
    String? categoryId,
    int offset = 0,
    int limit = 25,
  }) async {
    final result = await callFunction(
      'library-catalogue-search',
      data: {
        'q': query,
        'categoryId': ?categoryId,
        'offset': offset,
        'limit': limit,
      },
    ) as Map<Object?, Object?>;
    return (
      items: [
        for (final row in result['items']! as List<Object?>)
          LibraryBook.fromMap(
            (row! as Map)['id'] as String,
            Map<String, dynamic>.from(row as Map),
          ),
      ],
      hasMore: result['hasMore'] == true,
    );
  }

  Future<LibraryBook?> book(String id) async {
    final document = await (await schoolCollection('libraryCatalogue'))
        .doc(id)
        .get();
    return document.exists
        ? LibraryBook.fromMap(document.id, document.data()!)
        : null;
  }

  /// Copies of a title across all libraries, by accession number.
  Future<List<LibraryCopy>> copiesOf(String catalogueId) async {
    final query = (await schoolCollection('libraryCopies'))
        .where('catalogueId', isEqualTo: catalogueId);
    final snapshot = await query.get();
    return [
      for (final document in snapshot.docs)
        LibraryCopy.fromMap(document.id, document.data()),
    ]..sort(
      (left, right) => left.accessionNumber.compareTo(right.accessionNumber),
    );
  }

  /// A copy by accession number, barcode or RFID tag (what a scanner reads).
  Future<LibraryCopy?> findCopy(String code) async {
    final value = code.trim();
    final collection = await schoolCollection('libraryCopies');
    final byId = await collection.doc(value.toUpperCase()).get();
    if (byId.exists) return LibraryCopy.fromMap(byId.id, byId.data()!);
    for (final field in const ['barcode', 'rfidTag']) {
      final snapshot = await collection
          .where(field, isEqualTo: value)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return LibraryCopy.fromMap(
          snapshot.docs.first.id,
          snapshot.docs.first.data(),
        );
      }
    }
    return null;
  }

  /// Latest acquisitions (newest first).
  Future<List<LibraryAcquisition>> acquisitions({int limit = 100}) async {
    final snapshot = await (await schoolCollection('libraryAcquisitions'))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final document in snapshot.docs)
        LibraryAcquisition.fromMap(document.id, document.data()),
    ];
  }

  Future<List<LibraryPolicy>> policies() async =>
      (await _all('libraryBorrowingPolicies', LibraryPolicy.fromMap))
        ..sort((left, right) => left.name.compareTo(right.name));

  /// A page of members of one type by ERP ID.
  Future<PagedResult<LibraryMember>> members(
    String memberType, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await schoolCollection('libraryMembers'))
        .where('memberType', isEqualTo: memberType)
        .orderBy('personErpId'),
    (document) => LibraryMember.fromMap(document.id, document.data()!),
    after: after,
  );

  /// One member by type and ERP ID (the member ID is `<type>_<personErpId>`).
  Future<LibraryMember?> member(String memberType, int personErpId) async {
    final document = await (await schoolCollection('libraryMembers'))
        .doc('${memberType}_$personErpId')
        .get();
    return document.exists
        ? LibraryMember.fromMap(document.id, document.data()!)
        : null;
  }

  /// A page of loans in [status], earliest due first.
  Future<PagedResult<LibraryLoan>> loans(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await schoolCollection('libraryLoans'))
        .where('status', isEqualTo: status)
        .orderBy('dueDate'),
    (document) => LibraryLoan.fromMap(document.id, document.data()!),
    after: after,
  );

  /// The active loan of a copy, if it is out.
  Future<LibraryLoan?> activeLoanOf(String copyId) async {
    final snapshot = await (await schoolCollection('libraryLoans'))
        .where('copyId', isEqualTo: copyId)
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

  /// A page of reservations in [status], ordered by [createdAt].
  Future<PagedResult<LibraryReservation>> reservations(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await schoolCollection('libraryReservations'))
        .where('status', isEqualTo: status)
        .orderBy('createdAt'),
    (document) => LibraryReservation.fromMap(document.id, document.data()!),
    after: after,
  );

  /// A page of fines, optionally filtered by [status] ('outstanding', 'paid', 'waived').
  Future<PagedResult<LibraryFine>> fines({
    String? status,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> query = await schoolCollection('libraryFines');
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return fetchPage(
      query.orderBy('createdAt', descending: true),
      (document) => LibraryFine.fromMap(document.id, document.data()!),
      after: after,
    );
  }

  /// A single fine by ID.
  Future<LibraryFine?> fine(String id) async {
    final document = await (await schoolCollection('libraryFines'))
        .doc(id)
        .get();
    return document.exists
        ? LibraryFine.fromMap(document.id, document.data()!)
        : null;
  }

  /// A page of lost/damaged incidents, optionally filtered by [status] ('open', 'resolved').
  Future<PagedResult<LibraryIncident>> incidents({
    String? status,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> query = await schoolCollection(
      'libraryIncidents',
    );
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return fetchPage(
      query.orderBy('createdAt', descending: true),
      (document) => LibraryIncident.fromMap(document.id, document.data()!),
      after: after,
    );
  }

  /// Transfers leaving or arriving on the user's campuses, newest first.
  Future<List<LibraryTransfer>> transfers(ModuleAccess access) async =>
      fetchCampusBothSides(
        await schoolCollection('libraryTransfers'),
        access,
        LibraryTransfer.fromMap,
        (transfer) => transfer.createdAt,
      );

  /// A page of stock verification sessions, newest first.
  Future<PagedResult<LibraryVerification>> verifications({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await schoolCollection('libraryVerifications'))
        .orderBy('createdAt', descending: true),
    (document) => LibraryVerification.fromMap(document.id, document.data()!),
    after: after,
  );

  Future<LibraryVerification?> verification(String id) async {
    final document = await (await schoolCollection('libraryVerifications'))
        .doc(id)
        .get();
    return document.exists
        ? LibraryVerification.fromMap(document.id, document.data()!)
        : null;
  }

  // --- writes: masters are plain client CRUD (`firestore.rules`); the rest are callables, same requestId on user retry --------------------

  Future<void> seedDefaults() => _call('library-seedDefaults', {});

  Future<void> saveLibrary(Map<String, Object?> data) =>
      saveMasterDocument('libraries', data);

  Future<void> setLibraryActive(String id, {required bool active}) =>
      setMasterActive('libraries', id, active: active);

  Future<void> saveCategory(Map<String, Object?> data) =>
      saveMasterDocument('libraryCategories', data);

  Future<void> setCategoryActive(String id, {required bool active}) =>
      setMasterActive('libraryCategories', id, active: active);

  Future<void> saveBook(Map<String, Object?> data, {String? requestId}) =>
      _call('library-catalogue-upsert', data, requestId);

  Future<void> setBookActive(String id, {required bool active}) =>
      _call('library-catalogue-setStatus', _status(id, active));

  /// Returns the new accession numbers.
  Future<List<String>> createAcquisition(
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    final result = await callFunction(
      'library-acquisition-create',
      data: data,
      requestId: requestId,
    ) as Map<Object?, Object?>;
    return [
      for (final row in result['copyIds']! as List<Object?>) row! as String,
    ];
  }

  Future<void> updateCopy(Map<String, Object?> data) =>
      _call('library-copy-update', data);

  Future<void> moveCopy(String id, String libraryId, String? shelf) => _call(
    'library-copy-move',
    {'id': id, 'libraryId': libraryId, 'shelf': ?shelf},
  );

  Future<void> setCopyStatus(String id, String status, String? reason) => _call(
    'library-copy-setStatus',
    {'id': id, 'status': status, 'reason': ?reason},
  );

  Future<void> savePolicy(Map<String, Object?> data, {String? requestId}) =>
      _call('library-policy-upsert', data, requestId);

  Future<void> setPolicyActive(String id, {required bool active}) =>
      _call('library-policy-setStatus', _status(id, active));

  Future<void> issueLoan(Map<String, Object?> data, {String? requestId}) =>
      _call('library-loan-issue', data, requestId);

  Future<void> returnLoan(Map<String, Object?> data, {String? requestId}) =>
      _call('library-loan-return', data, requestId);

  Future<void> renewLoan(String id, {String? requestId}) =>
      _call('library-loan-renew', {'id': id}, requestId);

  Future<void> createReservation(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('library-reservation-create', data, requestId);

  Future<void> cancelReservation(String id, {String? requestId}) =>
      _call('library-reservation-cancel', {'id': id}, requestId);

  Future<void> waiveFine(Map<String, Object?> data, {String? requestId}) =>
      _call('library-fine-waive', data, requestId);

  Future<void> setFinePayment(Map<String, Object?> data, {String? requestId}) =>
      _call('library-fine-setPayment', data, requestId);

  Future<void> reportIncident(Map<String, Object?> data, {String? requestId}) =>
      _call('library-incident-report', data, requestId);

  Future<void> resolveIncident(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('library-incident-resolve', data, requestId);

  Future<void> requestTransfer(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('library-transfer-request', data, requestId);

  Future<void> approveTransfer(String id, {String? requestId}) =>
      _call('library-transfer-approve', {'id': id}, requestId);

  Future<void> dispatchTransfer(String id, {String? requestId}) =>
      _call('library-transfer-dispatch', {'id': id}, requestId);

  Future<void> cancelTransfer(String id, String reason, {String? requestId}) =>
      _call('library-transfer-cancel', {'id': id, 'reason': reason}, requestId);

  Future<void> closeTransferShort(
    String id,
    String reason, {
    String? requestId,
  }) => _call('library-transfer-closeShort', {
    'id': id,
    'reason': reason,
  }, requestId);

  Future<void> setMemberBlocked(
    String id, {
    required bool blocked,
    String? reason,
  }) => _call('library-member-setBlocked', {
    'id': id,
    'blocked': blocked,
    'reason': ?reason,
  });

  Future<void> receiveTransfer(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('library-transfer-receive', data, requestId);

  Future<void> createVerification(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('library-verification-create', data, requestId);

  Future<void> scanVerification(String id, List<String> accessionNumbers) =>
      _call('library-verification-scan', {
        'id': id,
        'accessionNumbers': accessionNumbers,
      });

  Future<void> submitVerification(String id, {String? requestId}) =>
      _call('library-verification-submit', {'id': id}, requestId);

  Future<void> approveVerification(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('library-verification-approve', data, requestId);

  Future<void> markLoanLost(Map<String, Object?> data, {String? requestId}) =>
      _call('library-loan-markLost', data, requestId);

  Map<String, Object?> _status(String id, bool active) => {
    'id': id,
    'status': active ? 'active' : 'inactive',
  };

  Future<void> _call(
    String name,
    Map<String, Object?> data, [
    String? requestId,
  ]) async {
    await callFunction(name, data: data, requestId: requestId);
  }

  // ---- Dashboard and reports (Lib-8) ----

  /// Rules need the campus filter on every list (`all` users need none); null when the user has no campus.
  Query<Map<String, dynamic>>? _scoped(
    Query<Map<String, dynamic>> query,
    ModuleAccess access, {
    SchoolLibrary? library,
  }) {
    final scoped = library != null
        ? query.where('campusId', isEqualTo: library.campusId)
        : access.restrictToCampuses(query);
    return library == null
        ? scoped
        : scoped?.where('libraryId', isEqualTo: library.id);
  }

  /// Dashboard figures for the user's campuses (or one [library]). A figure the user cannot read is null.
  Future<Map<String, num?>> dashboard(
    ModuleAccess access, {
    SchoolLibrary? library,
  }) async {
    final today = todayIST();
    Future<num?> count(
      String collection,
      Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)
      f, {
      bool scoped = true,
    }) async {
      try {
        final base = scoped
            ? _scoped(
                await schoolCollection(collection),
                access,
                library: library,
              )
            : await schoolCollection(collection);
        return base == null ? 0 : (await f(base).count().get()).count;
      } catch (_) {
        return null;
      }
    }

    Future<num?> copies(String status) => count(
      'libraryCopies',
      (query) => query.where('status', isEqualTo: status),
    );
    Future<num?> members(String type) async {
      try {
        var query = (await schoolCollection('libraryMembers'))
            .where('memberType', isEqualTo: type);
        if (library != null) {
          query = query.where('campusIds', arrayContains: library.campusId);
        }
        return (await query.count().get()).count;
      } catch (_) {
        return null;
      }
    }

    Future<num?> fines() async {
      try {
        final query = _scoped(
          await schoolCollection('libraryFines'),
          access,
          library: library,
        );
        return query == null
            ? 0
            : (await query
                      .where(
                        'status',
                        whereIn: ['outstanding', 'partially_paid'],
                      )
                      .aggregate(sum('outstanding'))
                      .get())
                  .getSum('outstanding');
      } catch (_) {
        return null;
      }
    }

    final figures = <String, Future<num?>>{
      // The catalogue is school-wide; a library has no titles of its own.
      'titles': library == null
          ? count('libraryCatalogue', (query) => query, scoped: false)
          : Future.value(),
      'copies': count('libraryCopies', (query) => query),
      'available': copies('available'),
      'issued': copies('issued'),
      'lost': copies('lost'),
      'damaged': copies('damaged'),
      'overdue': count(
        'libraryLoans',
        (query) => query
            .where('status', isEqualTo: 'active')
            .where('dueDate', isLessThan: dayTimestamp(today)),
      ),
      'pending': count(
        'libraryLoans',
        (query) => query.where('status', isEqualTo: 'active'),
      ),
      'reserved': count(
        'libraryReservations',
        (query) => query.where('status', whereIn: ['waiting', 'ready']),
      ),
      'students': members('student'),
      'teachers': members('teacher'),
      'fines': fines(),
    };
    final values = await Future.wait(figures.values);
    return {
      for (final (index, key) in figures.keys.indexed) key: values[index],
    };
  }

  /// Titles by ID (for report cells); 30 per Firestore `whereIn`.
  Future<Map<String, LibraryBook>> titlesByIds(Iterable<String> ids) async {
    final collection = await schoolCollection('libraryCatalogue');
    final need = ids.toSet().toList();
    final out = <String, LibraryBook>{};
    for (var i = 0; i < need.length; i += 30) {
      final snapshot = await collection
          .where(
            FieldPath.documentId,
            whereIn: need.sublist(i, (i + 30).clamp(0, need.length)),
          )
          .get();
      for (final document in snapshot.docs) {
        out[document.id] = LibraryBook.fromMap(document.id, document.data());
      }
    }
    return out;
  }

  static const reportLimit = 500;

  /// Rows of [def] for the user's campuses; `popular` / `inactive` are computed over up to [rankLimit] loans.
  Future<List<ReportRow>> report(
    ModuleAccess access,
    LibraryReportDef def, {
    SchoolLibrary? library,
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final fromS = from?.toApiDate();
    final toS = to?.toApiDate();
    if (def.type != LibraryReportType.query) {
      return _ranking(access, def, library, fromS, toS);
    }
    final collection = await schoolCollection(def.collection);
    final base = def.schoolWide
        ? collection
        : _scoped(collection, access, library: def.hasLibrary ? library : null);
    if (base == null) return [];
    var query = base;
    for (final mapEntry in def.where.entries) {
      query = query.where(mapEntry.key, isEqualTo: mapEntry.value);
    }
    if (status != null) {
      query = query.where(
        def.collection == 'libraryAcquisitions' ? 'type' : 'status',
        isEqualTo: status,
      );
    }
    if (def.overdue) {
      query = query
          .where('dueDate', isLessThan: dayTimestamp(todayIST()))
          .orderBy('dueDate');
    } else if (def.dateField != null) {
      final currentValue = def.dateField!;
      final isTimestamp = const {'createdAt'}.contains(currentValue);
      Object bound(String value, {bool end = false}) => isTimestamp
          ? Timestamp.fromDate(
              DateTime.parse(value).add(Duration(days: end ? 1 : 0)),
            )
          : dayTimestamp(value);
      if (fromS != null) {
        query = query.where(currentValue, isGreaterThanOrEqualTo: bound(fromS));
      }
      if (toS != null) {
        query = isTimestamp
            ? query.where(currentValue, isLessThan: bound(toS, end: true))
            : query.where(currentValue, isLessThanOrEqualTo: dayTimestamp(toS));
      }
      query = query.orderBy(currentValue, descending: true);
    } else if (def.schoolWide) {
      query = query.orderBy('title');
    }
    final snapshot = await query.limit(reportLimit).get();
    return [for (final document in snapshot.docs) document.data()];
  }

  static const rankLimit = 5000;

  Future<List<ReportRow>> _ranking(
    ModuleAccess access,
    LibraryReportDef def,
    SchoolLibrary? library,
    String? from,
    String? to,
  ) async {
    Future<List<ReportRow>> fetch(String name, {String? dateField}) async {
      var query = _scoped(
        await schoolCollection(name),
        access,
        library: library,
      );
      if (query == null) return [];
      if (dateField != null) {
        if (from != null) {
          query = query.where(
            dateField,
            isGreaterThanOrEqualTo: dayTimestamp(from),
          );
        }
        if (to != null) {
          query = query.where(dateField, isLessThanOrEqualTo: dayTimestamp(to));
        }
        query = query.orderBy(dateField, descending: true);
      }
      return [
        for (final document in (await query.limit(rankLimit).get()).docs)
          document.data(),
      ];
    }

    final loans = await fetch('libraryLoans', dateField: 'issuedDate');
    final loanCount = <String, int>{};
    for (final data in loans) {
      loanCount.update(
        '${data['catalogueId']}',
        (number) => number + 1,
        ifAbsent: () => 1,
      );
    }
    if (def.type == LibraryReportType.popular) {
      return [
        for (final mapEntry
            in loanCount.entries.toList()..sort(
              (currentMapEntry, mapEntry) =>
                  mapEntry.value.compareTo(currentMapEntry.value),
            ))
          {'catalogueId': mapEntry.key, 'count': mapEntry.value},
      ];
    }
    final copyCount = <String, int>{};
    for (final data in await fetch('libraryCopies')) {
      if (data['status'] == 'withdrawn') continue;
      copyCount.update(
        '${data['catalogueId']}',
        (number) => number + 1,
        ifAbsent: () => 1,
      );
    }
    return [
      for (final mapEntry in copyCount.entries)
        if (!loanCount.containsKey(mapEntry.key))
          {'catalogueId': mapEntry.key, 'count': mapEntry.value},
    ];
  }
}
