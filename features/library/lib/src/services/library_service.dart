import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/lib_copies.dart';
import 'package:school_library/src/models/lib_fines.dart';
import 'package:school_library/src/models/lib_incidents.dart';
import 'package:school_library/src/models/lib_insights.dart';
import 'package:school_library/src/models/lib_loans.dart';
import 'package:school_library/src/models/lib_masters.dart';
import 'package:school_library/src/models/lib_members.dart';
import 'package:school_library/src/models/lib_reservations.dart';
import 'package:school_library/src/models/lib_transfers.dart';
import 'package:school_library/src/models/lib_verifications.dart';

/// Library masters: reads from Firestore, writes through callables.
@lazySingleton
class LibraryService {
  Future<CollectionReference<Map<String, dynamic>>> _coll(String path) async {
    final user = FirebaseAuth.instance.currentUser!;
    final sid = (await user.getIdTokenResult()).claims?['sid'];
    return FirebaseFirestore.instance.collection('schools/$sid/$path');
  }

  Future<List<T>> _all<T>(
    String path,
    T Function(String id, Map<String, dynamic> m) parse,
  ) async {
    final snap = await (await _coll(path)).get();
    return [for (final d in snap.docs) parse(d.id, d.data())];
  }

  Future<LibAccess> access() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await (await _coll('userAccess')).doc(user.uid).get();
    return LibAccess.fromMap(doc.data() ?? {});
  }

  Future<List<LibLibrary>> libraries() async =>
      (await _all('libLibraries', LibLibrary.fromMap))
        ..sort((a, b) => a.code.compareTo(b.code));

  Future<List<LibCategory>> categories() async =>
      (await _all('libCategories', LibCategory.fromMap))
        ..sort((a, b) => a.code.compareTo(b.code));

  /// A page of titles by title, optionally within [categoryId] (Firestore query).
  Future<PagedResult<LibBook>> books({
    String? categoryId,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> q = await _coll('libCatalogue');
    if (categoryId != null) q = q.where('categoryId', isEqualTo: categoryId);
    return fetchPage(
      q.orderBy('title'),
      (d) => LibBook.fromMap(d.id, d.data()!),
      after: after,
    );
  }

  /// Whole-word search by title, author, publisher or keyword, or an exact ISBN (Functions).
  Future<({List<LibBook> items, bool hasMore})> searchBooks(
    String query, {
    String? categoryId,
    int offset = 0,
    int limit = 25,
  }) async {
    final res = await callFunction(
      'lib-catalogue-search',
      data: {
        'q': query,
        'categoryId': ?categoryId,
        'offset': offset,
        'limit': limit,
      },
    ) as Map<Object?, Object?>;
    return (
      items: [
        for (final r in res['items']! as List<Object?>)
          LibBook.fromMap(
            (r! as Map)['id'] as String,
            Map<String, dynamic>.from(r as Map),
          ),
      ],
      hasMore: res['hasMore'] == true,
    );
  }

  Future<LibBook?> book(String id) async {
    final d = await (await _coll('libCatalogue')).doc(id).get();
    return d.exists ? LibBook.fromMap(d.id, d.data()!) : null;
  }

  /// Copies of a title across all libraries, by accession number.
  Future<List<LibCopy>> copiesOf(String catalogueId) async {
    final q = (await _coll('libCopies'))
        .where('catalogueId', isEqualTo: catalogueId);
    final snap = await q.get();
    return [for (final d in snap.docs) LibCopy.fromMap(d.id, d.data())]
      ..sort((a, b) => a.accessionNo.compareTo(b.accessionNo));
  }

  /// A copy by accession number, barcode or RFID tag (what a scanner reads).
  Future<LibCopy?> findCopy(String code) async {
    final c = code.trim();
    final coll = await _coll('libCopies');
    final byId = await coll.doc(c.toUpperCase()).get();
    if (byId.exists) return LibCopy.fromMap(byId.id, byId.data()!);
    for (final field in const ['barcode', 'rfidTag']) {
      final r = await coll.where(field, isEqualTo: c).limit(1).get();
      if (r.docs.isNotEmpty) {
        return LibCopy.fromMap(r.docs.first.id, r.docs.first.data());
      }
    }
    return null;
  }

  /// Latest acquisitions (newest first).
  Future<List<LibAcquisition>> acquisitions({int limit = 100}) async {
    final snap = await (await _coll('libAcquisitions'))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs) LibAcquisition.fromMap(d.id, d.data())];
  }

  Future<List<LibPolicy>> policies() async =>
      (await _all('libPolicies', LibPolicy.fromMap))
        ..sort((a, b) => a.name.compareTo(b.name));

  /// A page of members of one type by ERP ID.
  Future<PagedResult<LibMember>> members(
    String memberType, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await _coll('libMembers'))
        .where('memberType', isEqualTo: memberType)
        .orderBy('erpId'),
    (d) => LibMember.fromMap(d.id, d.data()!),
    after: after,
  );

  /// One member by type and ERP ID (the member ID is `<type>_<erpId>`).
  Future<LibMember?> member(String memberType, int erpId) async {
    final d = await (await _coll('libMembers'))
        .doc('${memberType}_$erpId')
        .get();
    return d.exists ? LibMember.fromMap(d.id, d.data()!) : null;
  }

  /// A page of loans in [status], earliest due first.
  Future<PagedResult<LibLoan>> loans(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await _coll('libLoans'))
        .where('status', isEqualTo: status)
        .orderBy('dueOn'),
    (d) => LibLoan.fromMap(d.id, d.data()!),
    after: after,
  );

  /// The active loan of a copy, if it is out.
  Future<LibLoan?> activeLoanOf(String copyId) async {
    final r = await (await _coll('libLoans'))
        .where('copyId', isEqualTo: copyId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    return r.docs.isEmpty
        ? null
        : LibLoan.fromMap(r.docs.first.id, r.docs.first.data());
  }

  /// A page of reservations in [status], ordered by [createdAt].
  Future<PagedResult<LibReservation>> reservations(
    String status, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await _coll('libReservations'))
        .where('status', isEqualTo: status)
        .orderBy('createdAt'),
    (d) => LibReservation.fromMap(d.id, d.data()!),
    after: after,
  );

  /// A page of fines, optionally filtered by [status] ('outstanding', 'paid', 'waived').
  Future<PagedResult<LibFine>> fines({
    String? status,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> q = await _coll('libFines');
    if (status != null && status != 'all') {
      q = q.where('status', isEqualTo: status);
    }
    return fetchPage(
      q.orderBy('createdAt', descending: true),
      (d) => LibFine.fromMap(d.id, d.data()!),
      after: after,
    );
  }

  /// A single fine by ID.
  Future<LibFine?> fine(String id) async {
    final d = await (await _coll('libFines')).doc(id).get();
    return d.exists ? LibFine.fromMap(d.id, d.data()!) : null;
  }

  /// A page of lost/damaged incidents, optionally filtered by [status] ('open', 'resolved').
  Future<PagedResult<LibIncident>> incidents({
    String? status,
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> q = await _coll('libIncidents');
    if (status != null && status != 'all') {
      q = q.where('status', isEqualTo: status);
    }
    return fetchPage(
      q.orderBy('createdAt', descending: true),
      (d) => LibIncident.fromMap(d.id, d.data()!),
      after: after,
    );
  }

  /// A page of inter-library transfers, newest first.
  Future<PagedResult<LibTransfer>> transfers({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await _coll('libTransfers')).orderBy('createdAt', descending: true),
    (d) => LibTransfer.fromMap(d.id, d.data()!),
    after: after,
  );

  /// A page of stock verification sessions, newest first.
  Future<PagedResult<LibVerification>> verifications({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await _coll('libVerifications')).orderBy('createdAt', descending: true),
    (d) => LibVerification.fromMap(d.id, d.data()!),
    after: after,
  );

  Future<LibVerification?> verification(String id) async {
    final d = await (await _coll('libVerifications')).doc(id).get();
    return d.exists ? LibVerification.fromMap(d.id, d.data()!) : null;
  }

  // --- writes: callables, same requestId on user retry --------------------

  Future<void> seedDefaults() => _call('lib-seedDefaults', {});

  Future<void> saveLibrary(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-library-upsert', data, requestId);

  Future<void> setLibraryActive(String id, {required bool active}) =>
      _call('lib-library-setStatus', _status(id, active));

  Future<void> saveCategory(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-category-upsert', data, requestId);

  Future<void> setCategoryActive(String id, {required bool active}) =>
      _call('lib-category-setStatus', _status(id, active));

  Future<void> saveBook(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-catalogue-upsert', data, requestId);

  Future<void> setBookActive(String id, {required bool active}) =>
      _call('lib-catalogue-setStatus', _status(id, active));

  /// Returns the new accession numbers.
  Future<List<String>> createAcquisition(
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    final res = await callFunction(
      'lib-acquisition-create',
      data: data,
      requestId: requestId,
    ) as Map<Object?, Object?>;
    return [for (final c in res['copyIds']! as List<Object?>) c! as String];
  }

  Future<void> updateCopy(Map<String, Object?> data) =>
      _call('lib-copy-update', data);

  Future<void> moveCopy(String id, String libraryId, String? shelf) => _call(
    'lib-copy-move',
    {'id': id, 'libraryId': libraryId, 'shelf': ?shelf},
  );

  Future<void> setCopyStatus(String id, String status, String? reason) => _call(
    'lib-copy-setStatus',
    {'id': id, 'status': status, 'reason': ?reason},
  );

  Future<void> savePolicy(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-policy-upsert', data, requestId);

  Future<void> setPolicyActive(String id, {required bool active}) =>
      _call('lib-policy-setStatus', _status(id, active));

  Future<void> saveMember(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-member-upsert', data, requestId);

  Future<void> setMemberActive(String id, {required bool active}) =>
      _call('lib-member-setStatus', _status(id, active));

  Future<void> issueLoan(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-loan-issue', data, requestId);

  Future<void> returnLoan(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-loan-return', data, requestId);

  Future<void> renewLoan(String id, {String? requestId}) =>
      _call('lib-loan-renew', {'id': id}, requestId);

  Future<void> createReservation(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('lib-reservation-create', data, requestId);

  Future<void> cancelReservation(String id, {String? requestId}) =>
      _call('lib-reservation-cancel', {'id': id}, requestId);

  Future<void> waiveFine(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-fine-waive', data, requestId);

  Future<void> setFinePayment(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-fine-setPayment', data, requestId);

  Future<void> reportIncident(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-incident-report', data, requestId);

  Future<void> resolveIncident(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('lib-incident-resolve', data, requestId);

  Future<void> requestTransfer(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('lib-transfer-request', data, requestId);

  Future<void> approveTransfer(String id, {String? requestId}) =>
      _call('lib-transfer-approve', {'id': id}, requestId);

  Future<void> dispatchTransfer(String id, {String? requestId}) =>
      _call('lib-transfer-dispatch', {'id': id}, requestId);

  Future<void> receiveTransfer(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('lib-transfer-receive', data, requestId);

  Future<void> createVerification(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('lib-verification-create', data, requestId);

  Future<void> scanVerification(String id, List<String> accessionNos) =>
      _call('lib-verification-scan', {'id': id, 'accessionNos': accessionNos});

  Future<void> submitVerification(String id, {String? requestId}) =>
      _call('lib-verification-submit', {'id': id}, requestId);

  Future<void> approveVerification(
    Map<String, Object?> data, {
    String? requestId,
  }) => _call('lib-verification-approve', data, requestId);

  Future<void> markLoanLost(Map<String, Object?> data, {String? requestId}) =>
      _call('lib-loan-markLost', data, requestId);

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
    Query<Map<String, dynamic>> q,
    LibAccess a, {
    LibLibrary? library,
  }) {
    final scoped = library != null
        ? q.where('campusId', isEqualTo: library.campusId)
        : a.all
        ? q
        : a.campuses.isEmpty
        ? null
        : q.where('campusId', whereIn: a.campuses);
    return library == null
        ? scoped
        : scoped?.where('libraryId', isEqualTo: library.id);
  }

  /// Dashboard figures for the user's campuses (or one [library]). A figure the user cannot read is null.
  Future<Map<String, num?>> dashboard(
    LibAccess a, {
    LibLibrary? library,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    Future<num?> count(
      String coll,
      Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> q) f, {
      bool scoped = true,
    }) async {
      try {
        final base = scoped
            ? _scoped(await _coll(coll), a, library: library)
            : await _coll(coll);
        return base == null ? 0 : (await f(base).count().get()).count;
      } catch (_) {
        return null;
      }
    }

    Future<num?> copies(String status) =>
        count('libCopies', (q) => q.where('status', isEqualTo: status));
    Future<num?> members(String type) async {
      try {
        var q = (await _coll('libMembers'))
            .where('memberType', isEqualTo: type)
            .where('status', isEqualTo: 'active');
        if (library != null) {
          q = q.where('libraryIds', arrayContains: library.id);
        }
        return (await q.count().get()).count;
      } catch (_) {
        return null;
      }
    }

    num? fines;
    try {
      final q = _scoped(await _coll('libFines'), a, library: library);
      fines = q == null
          ? 0
          : (await q
                    .where('status', whereIn: ['outstanding', 'partially_paid'])
                    .aggregate(sum('outstanding'))
                    .get())
                .getSum('outstanding');
    } catch (_) {}
    return {
      // The catalogue is school-wide; a library has no titles of its own.
      'titles': library == null
          ? await count('libCatalogue', (q) => q, scoped: false)
          : null,
      'copies': await count('libCopies', (q) => q),
      'available': await copies('available'),
      'issued': await copies('issued'),
      'lost': await copies('lost'),
      'damaged': await copies('damaged'),
      'overdue': await count(
        'libLoans',
        (q) => q
            .where('status', isEqualTo: 'active')
            .where('dueOn', isLessThan: today),
      ),
      'pending': await count(
        'libLoans',
        (q) => q.where('status', isEqualTo: 'active'),
      ),
      'reserved': await count(
        'libReservations',
        (q) => q.where('status', whereIn: ['waiting', 'ready']),
      ),
      'students': await members('student'),
      'teachers': await members('teacher'),
      'fines': fines,
    };
  }

  /// Titles by ID (for report cells); 30 per Firestore `whereIn`.
  Future<Map<String, LibBook>> titlesByIds(Iterable<String> ids) async {
    final coll = await _coll('libCatalogue');
    final need = ids.toSet().toList();
    final out = <String, LibBook>{};
    for (var i = 0; i < need.length; i += 30) {
      final snap = await coll
          .where(
            FieldPath.documentId,
            whereIn: need.sublist(i, (i + 30).clamp(0, need.length)),
          )
          .get();
      for (final d in snap.docs) {
        out[d.id] = LibBook.fromMap(d.id, d.data());
      }
    }
    return out;
  }

  static const reportLimit = 500;

  /// Rows of [def] for the user's campuses; `popular` / `inactive` are computed over up to [rankLimit] loans.
  Future<List<LibReportRow>> report(
    LibAccess a,
    LibReportDef def, {
    LibLibrary? library,
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final fromS = from?.toIso8601String().substring(0, 10);
    final toS = to?.toIso8601String().substring(0, 10);
    if (def.kind != LibReportKind.query) {
      return _ranking(a, def, library, fromS, toS);
    }
    final coll = await _coll(def.collection);
    final base = def.schoolWide
        ? coll
        : _scoped(coll, a, library: def.hasLibrary ? library : null);
    if (base == null) return [];
    var q = base;
    for (final e in def.where.entries) {
      q = q.where(e.key, isEqualTo: e.value);
    }
    if (status != null) {
      q = q.where(
        def.collection == 'libAcquisitions' ? 'type' : 'status',
        isEqualTo: status,
      );
    }
    if (def.overdue) {
      q = q
          .where(
            'dueOn',
            isLessThan: DateTime.now().toIso8601String().substring(0, 10),
          )
          .orderBy('dueOn');
    } else if (def.dateField != null) {
      final f = def.dateField!;
      final isTimestamp = const {'createdAt'}.contains(f);
      Object bound(String d, {bool end = false}) => isTimestamp
          ? Timestamp.fromDate(
              DateTime.parse(d).add(Duration(days: end ? 1 : 0)),
            )
          : d;
      if (fromS != null) q = q.where(f, isGreaterThanOrEqualTo: bound(fromS));
      if (toS != null) {
        q = isTimestamp
            ? q.where(f, isLessThan: bound(toS, end: true))
            : q.where(f, isLessThanOrEqualTo: toS);
      }
      q = q.orderBy(f, descending: true);
    } else if (def.schoolWide) {
      q = q.orderBy('title');
    }
    final snap = await q.limit(reportLimit).get();
    return [for (final d in snap.docs) d.data()];
  }

  static const rankLimit = 5000;

  Future<List<LibReportRow>> _ranking(
    LibAccess a,
    LibReportDef def,
    LibLibrary? library,
    String? from,
    String? to,
  ) async {
    Future<List<LibReportRow>> fetch(String name, {String? dateField}) async {
      var q = _scoped(await _coll(name), a, library: library);
      if (q == null) return [];
      if (dateField != null) {
        if (from != null) q = q.where(dateField, isGreaterThanOrEqualTo: from);
        if (to != null) q = q.where(dateField, isLessThanOrEqualTo: to);
        q = q.orderBy(dateField, descending: true);
      }
      return [for (final d in (await q.limit(rankLimit).get()).docs) d.data()];
    }

    final loans = await fetch('libLoans', dateField: 'issuedOn');
    final loanCount = <String, int>{};
    for (final l in loans) {
      loanCount.update('${l['catalogueId']}', (n) => n + 1, ifAbsent: () => 1);
    }
    if (def.kind == LibReportKind.popular) {
      return [
        for (final e
            in loanCount.entries.toList()
              ..sort((x, y) => y.value.compareTo(x.value)))
          {'catalogueId': e.key, 'count': e.value},
      ];
    }
    final copyCount = <String, int>{};
    for (final c in await fetch('libCopies')) {
      if (c['status'] == 'withdrawn') continue;
      copyCount.update('${c['catalogueId']}', (n) => n + 1, ifAbsent: () => 1);
    }
    return [
      for (final e in copyCount.entries)
        if (!loanCount.containsKey(e.key))
          {'catalogueId': e.key, 'count': e.value},
    ];
  }
}
