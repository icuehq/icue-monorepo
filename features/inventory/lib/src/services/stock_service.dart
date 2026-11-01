import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_masters.dart';
import 'package:inventory/src/models/inv_stock.dart';

/// Stock (Inv-2): reads from Firestore, every write is a callable.
@lazySingleton
class StockService {
  Future<Query<Map<String, dynamic>>> _q(String path) async {
    final claims =
        (await FirebaseAuth.instance.currentUser!.getIdTokenResult()).claims;
    return FirebaseFirestore.instance.collection(
      'schools/${claims?['sid']}/$path',
    );
  }

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// Rules require the campus filter on every list (`all` users need none).
  Query<Map<String, dynamic>>? _scoped(
    Query<Map<String, dynamic>> q,
    InvAccess a, [
    String field = 'campusId',
  ]) {
    if (a.all) return q;
    return a.campuses.isEmpty ? null : q.where(field, whereIn: a.campuses);
  }

  Future<PagedResult<InvBalance>> balances(
    InvStore store, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async => fetchPage(
    (await _q('invBalances'))
        .where('campusId', isEqualTo: store.campusId)
        .where('storeId', isEqualTo: store.id)
        .orderBy('itemId'),
    (d) => InvBalance.fromMap(d.id, d.data()!),
    after: after,
    limit: 50,
  );

  Future<List<InvMovement>> movements(InvBalance b, int campusId) async {
    final snap = await (await _q('invMovements'))
        .where('campusId', isEqualTo: campusId)
        .where('balanceId', isEqualTo: b.id)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [for (final d in snap.docs) InvMovement.fromMap(d.data())];
  }

  /// Approvers and stock users see the campus's requests; everyone else their own.
  Future<List<InvIssueRequest>> requests(InvAccess a, {String? status}) async {
    final base = await _q('invIssueRequests');
    final wide = a.can('inv.stock.view') || a.can('inv.issue.approve');
    var q = wide ? _scoped(base, a) : base.where('createdBy', isEqualTo: uid);
    if (q == null) return [];
    if (status != null) q = q.where('status', isEqualTo: status);
    final snap = await q.orderBy('createdAt', descending: true).limit(50).get();
    return [for (final d in snap.docs) InvIssueRequest.fromMap(d.id, d.data())];
  }

  Future<List<InvIssue>> issuesOf(InvIssueRequest r) async {
    final snap = await (await _q('invIssues'))
        .where('campusId', isEqualTo: r.campusId)
        .where('issueRequestId', isEqualTo: r.id)
        .get();
    return [for (final d in snap.docs) InvIssue.fromMap(d.id, d.data())];
  }

  /// Transfers leaving or arriving on the user's campuses.
  Future<List<InvTransfer>> transfers(InvAccess a) async {
    final base = await _q('invTransfers');
    final queries = [
      _scoped(base, a),
      if (!a.all) _scoped(base, a, 'toCampusId'),
    ];
    final byId = <String, InvTransfer>{};
    for (final q in queries.whereType<Query<Map<String, dynamic>>>()) {
      final snap = await q
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      for (final d in snap.docs) {
        byId[d.id] = InvTransfer.fromMap(d.id, d.data());
      }
    }
    return byId.values.toList()..sort(
      (x, y) =>
          (y.createdAt ?? DateTime(0)).compareTo(x.createdAt ?? DateTime(0)),
    );
  }

  Future<List<InvUnavailable>> unavailable(InvAccess a) async {
    final q = _scoped(
      await _q('invUnavailable'),
      a,
    )?.where('status', whereIn: ['open', 'in_repair']);
    if (q == null) return [];
    final snap = await q
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return [for (final d in snap.docs) InvUnavailable.fromMap(d.id, d.data())];
  }

  /// Every store in the school (transfer destinations may be on another campus).
  Future<List<InvStore>> allStores() async {
    final snap = await (await _q('invStores')).get();
    return [for (final d in snap.docs) InvStore.fromMap(d.id, d.data())]
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  /// Item docs by id (30 per Firestore `in` query).
  Future<Map<String, InvItem>> itemsByIds(Iterable<String> ids) async {
    final out = <String, InvItem>{};
    final list = ids.toSet().toList();
    for (var i = 0; i < list.length; i += 30) {
      final snap = await (await _q('invItems'))
          .where(FieldPath.documentId, whereIn: list.skip(i).take(30).toList())
          .get();
      for (final d in snap.docs) {
        out[d.id] = InvItem.fromMap(d.id, d.data());
      }
    }
    return out;
  }

  /// Calls [fn] (e.g. `inv-receipt-confirm`); [requestId] makes a retry idempotent.
  Future<Map<String, dynamic>> call(
    String fn,
    Map<String, Object?> data, {
    String? requestId,
  }) async {
    final res = await callFunction(fn, data: data, requestId: requestId);
    return res is Map ? Map<String, dynamic>.from(res) : {};
  }
}
