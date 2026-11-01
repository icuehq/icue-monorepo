import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inv_insights.dart';
import 'package:inventory/src/models/inv_masters.dart';

/// Verification sessions, dashboard counts and report rows (Inv-7): reads from Firestore, writes are callables.
@lazySingleton
class InsightsService {
  Future<CollectionReference<Map<String, dynamic>>> _coll(String path) async {
    final claims =
        (await FirebaseAuth.instance.currentUser!.getIdTokenResult()).claims;
    return FirebaseFirestore.instance.collection(
      'schools/${claims?['sid']}/$path',
    );
  }

  /// Rules need the campus filter on every list (`all` users need none); null when the user has no campus.
  Query<Map<String, dynamic>>? _scoped(
    Query<Map<String, dynamic>> q,
    InvAccess a, {
    int? campusId,
  }) => campusId != null
      ? q.where('campusId', isEqualTo: campusId)
      : a.all
      ? q
      : a.campuses.isEmpty
      ? null
      : q.where('campusId', whereIn: a.campuses);

  Future<List<InvVerification>> verifications(InvAccess a) async {
    final q = _scoped(await _coll('invVerifications'), a);
    if (q == null) return [];
    final snap = await q.orderBy('createdAt', descending: true).limit(50).get();
    return [for (final d in snap.docs) InvVerification.fromMap(d.id, d.data())];
  }

  Future<InvVerification?> verification(String id) async {
    final d = await (await _coll('invVerifications')).doc(id).get();
    final m = d.data();
    return m == null ? null : InvVerification.fromMap(d.id, m);
  }

  Future<List<VerificationLine>> lines(InvVerification v) async {
    final snap = await (await _coll('invVerifications'))
        .doc(v.id)
        .collection('lines')
        .where('campusId', isEqualTo: v.campusId)
        .get();
    return [for (final d in snap.docs) VerificationLine.fromMap(d.data())];
  }

  /// Writes counts straight to the lines (rules check them), so Firestore queues them while offline.
  /// Returns false when the server has not confirmed within a few seconds (the write stays queued).
  Future<bool> saveCounts(
    InvVerification v,
    List<(VerificationLine, num, String?)> counts,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final lines = (await _coll('invVerifications'))
        .doc(v.id)
        .collection('lines');
    final batch = FirebaseFirestore.instance.batch();
    for (final (l, counted, reason) in counts) {
      final diff = counted - l.expected;
      batch.update(lines.doc(l.balanceId), {
        'counted': counted,
        'diff': diff,
        'reason': diff == 0 ? null : reason,
        'countedBy': uid,
        'countedAt': FieldValue.serverTimestamp(),
      });
    }
    var synced = true;
    await batch.commit().timeout(
      const Duration(seconds: 4),
      onTimeout: () => synced = false,
    );
    return synced;
  }

  /// Dashboard figures for the campuses (or the one [storeId]'s campus) the user may see.
  /// A figure the user's permissions cannot read is null.
  Future<Map<String, num?>> dashboard(InvAccess a, {InvStore? store}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final soon = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10);
    Future<Query<Map<String, dynamic>>?> scope(
      String coll, {
      bool byStore = false,
    }) async {
      final q = _scoped(await _coll(coll), a, campusId: store?.campusId);
      return q == null || !byStore || store == null
          ? q
          : q.where('storeId', isEqualTo: store.id);
    }

    Future<num?> count(
      String coll,
      Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> q) f, {
      bool byStore = false,
    }) async {
      try {
        final q = await scope(coll, byStore: byStore);
        return q == null ? 0 : (await f(q).count().get()).count;
      } catch (_) {
        return null;
      }
    }

    Future<num?> total(String field) async {
      try {
        final q = await scope('invBalances', byStore: true);
        return q == null
            ? 0
            : (await q.aggregate(sum(field)).get()).getSum(field);
      } catch (_) {
        return null;
      }
    }

    Future<num?> bal(
      Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> q) f,
    ) => count('invBalances', f, byStore: true);
    const open = ['issued', 'acknowledged', 'partially_received'];
    final prs = await count(
      'invPurchaseRequests',
      (q) => q.where('status', isEqualTo: 'pending'),
    );
    final issues = await count(
      'invIssueRequests',
      (q) => q.where('status', isEqualTo: 'pending'),
    );
    num? items;
    try {
      items = (await (await _coll(
        'invItems',
      )).where('status', isEqualTo: 'active').count().get()).count;
    } catch (_) {}
    return {
      'items': items,
      'available': await total('qtyAvailable'),
      'value': await total('value'),
      'low': await bal((q) => q.where('belowReorder', isEqualTo: true)),
      'out': await bal((q) => q.where('qtyAvailable', isEqualTo: 0)),
      'expiring': await bal(
        (q) => q
            .where('expKey', isGreaterThanOrEqualTo: today)
            .where('expKey', isLessThanOrEqualTo: soon),
      ),
      'expired': await bal((q) => q.where('expKey', isLessThan: today)),
      'prs': prs,
      'approvals': prs == null && issues == null
          ? null
          : (prs ?? 0) + (issues ?? 0),
      'pos': await count(
        'invPurchaseOrders',
        (q) => q.where('status', whereIn: open),
      ),
      'receipts': await count(
        'invPurchaseOrders',
        (q) => q.where('status', whereIn: ['issued', 'acknowledged']),
      ),
      'assets': await count('invAssets', (q) => q),
      'maint': await count(
        'invAssets',
        (q) =>
            q.where('status', whereIn: ['under_maintenance', 'under_repair']),
      ),
    };
  }

  /// Up to [reportLimit] rows of [def] for the user's campuses. Without a store/date index the
  /// ordering of balance reports is by the document (sorted in the provider).
  Future<List<ReportRow>> report(
    InvAccess a,
    ReportDef def, {
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final base = def.schoolWide
        ? await _coll(def.collection) as Query<Map<String, dynamic>>
        : _scoped(await _coll(def.collection), a);
    if (base == null) return [];
    var q = base;
    for (final e in def.where.entries) {
      q = q.where(e.key, isEqualTo: e.value);
    }
    if (status != null) {
      q = q.where('status', isEqualTo: status);
    } else if (def.fixedStatuses.isNotEmpty) {
      q = q.where('status', whereIn: def.fixedStatuses);
    }
    if (def.hasDates) {
      Object bound(DateTime d) => def.isString
          ? d.toIso8601String().substring(0, 10)
          : Timestamp.fromDate(d);
      if (from != null) {
        q = q.where(def.dateField, isGreaterThanOrEqualTo: bound(from));
      }
      if (to != null) {
        q = q.where(
          def.dateField,
          isLessThan: bound(to.add(const Duration(days: 1))),
        );
      }
      q = q.orderBy(def.dateField, descending: !def.isString);
    }
    final snap = await q.limit(reportLimit).get();
    return [for (final d in snap.docs) d.data()];
  }

  static const reportLimit = 500;
}
