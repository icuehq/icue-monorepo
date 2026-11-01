import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:school_library/src/models/lib_copies.dart';
import 'package:school_library/src/models/lib_fines.dart';
import 'package:school_library/src/models/lib_incidents.dart';
import 'package:school_library/src/models/lib_loans.dart';
import 'package:school_library/src/models/lib_masters.dart';
import 'package:school_library/src/models/lib_members.dart';
import 'package:school_library/src/models/lib_reservations.dart';

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
}
