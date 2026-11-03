import 'package:core_ui/core_ui.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_insights.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// Verification sessions, dashboard counts and report rows (Inv-7): reads from Firestore, writes are callables.
@lazySingleton
class InsightsService {
  /// Rules need the campus filter on every list (`all` users need none); null when the user has no campus.
  Query<Map<String, dynamic>>? _scoped(
    Query<Map<String, dynamic>> query,
    ModuleAccess access, {
    int? campusId,
  }) => campusId != null
      ? query.where('campusId', isEqualTo: campusId)
      : access.restrictToCampuses(query);

  Future<List<InventoryVerification>> verifications(ModuleAccess access) async {
    final query = _scoped(
      await schoolCollection('inventoryVerifications'),
      access,
    );
    if (query == null) return [];
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return [
      for (final document in snapshot.docs)
        InventoryVerification.fromMap(document.id, document.data()),
    ];
  }

  Future<InventoryVerification?> verification(String id) async {
    final document = await (await schoolCollection('inventoryVerifications'))
        .doc(id)
        .get();
    final data = document.data();
    return data == null
        ? null
        : InventoryVerification.fromMap(document.id, data);
  }

  Future<List<VerificationLine>> lineItems(
    InventoryVerification verification,
  ) async {
    final snapshot = await (await schoolCollection('inventoryVerifications'))
        .doc(verification.id)
        .collection('lineItems')
        .where('campusId', isEqualTo: verification.campusId)
        .get();
    return [
      for (final document in snapshot.docs)
        VerificationLine.fromMap(document.data()),
    ];
  }

  /// Writes counts straight to the lines (rules check them), so Firestore queues them while offline.
  /// Returns false when the server has not confirmed within a few seconds (the write stays queued).
  Future<bool> saveCounts(
    InventoryVerification verification,
    List<(VerificationLine, num, String?)> counts,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final lineItems = (await schoolCollection('inventoryVerifications'))
        .doc(verification.id)
        .collection('lineItems');
    final batch = FirebaseFirestore.instance.batch();
    for (final (l, counted, reason) in counts) {
      final difference = counted - l.expected;
      batch.update(lineItems.doc(l.balanceId), {
        'counted': counted,
        'difference': difference,
        'reason': difference == 0 ? null : reason,
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
  Future<Map<String, num?>> dashboard(
    ModuleAccess access, {
    InventoryStore? store,
  }) async {
    final today = todayIST();
    final soon = DateTime.parse(today)
        .add(const Duration(days: 30))
        .toApiDate();
    Future<Query<Map<String, dynamic>>?> scope(
      String collection, {
      bool byStore = false,
    }) async {
      final query = _scoped(
        await schoolCollection(collection),
        access,
        campusId: store?.campusId,
      );
      return query == null || !byStore || store == null
          ? query
          : query.where('storeId', isEqualTo: store.id);
    }

    Future<num?> count(
      String collection,
      Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)
      f, {
      bool byStore = false,
    }) async {
      try {
        final query = await scope(collection, byStore: byStore);
        return query == null ? 0 : (await f(query).count().get()).count;
      } catch (_) {
        return null;
      }
    }

    Future<num?> total(String field) async {
      try {
        final query = await scope('inventoryBalances', byStore: true);
        return query == null
            ? 0
            : (await query.aggregate(sum(field)).get()).getSum(field);
      } catch (_) {
        return null;
      }
    }

    Future<num?> bal(
      Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query) f,
    ) => count('inventoryBalances', f, byStore: true);
    const open = ['issued', 'acknowledged', 'partially_received'];
    final purchaseRequests = count(
      'inventoryPurchaseRequests',
      (query) => query.where('status', isEqualTo: 'pending'),
    );
    final issues = count(
      'inventoryIssueRequests',
      (query) => query.where('status', isEqualTo: 'pending'),
    );
    Future<num?> items() async {
      try {
        return (await (await schoolCollection(
          'inventoryItems',
        )).where('status', isEqualTo: 'active').count().get()).count;
      } catch (_) {
        return null;
      }
    }

    final figures = <String, Future<num?>>{
      'items': items(),
      'available': total('quantityAvailable'),
      'value': total('value'),
      'low': bal(
        (query) => query.where('isBelowReorderLevel', isEqualTo: true),
      ),
      'out': bal((query) => query.where('quantityAvailable', isEqualTo: 0)),
      'expiring': bal(
        (query) => query
            .where('earliestExpiryDate', isGreaterThanOrEqualTo: today)
            .where('earliestExpiryDate', isLessThanOrEqualTo: soon),
      ),
      'expired': bal(
        (query) => query.where('earliestExpiryDate', isLessThan: today),
      ),
      'prs': purchaseRequests,
      'approvals': Future.wait([purchaseRequests, issues]).then(
        (pair) => pair[0] == null && pair[1] == null
            ? null
            : (pair[0] ?? 0) + (pair[1] ?? 0),
      ),
      'pos': count(
        'inventoryPurchaseOrders',
        (query) => query.where('status', whereIn: open),
      ),
      'receipts': count(
        'inventoryPurchaseOrders',
        (query) => query.where('status', whereIn: ['issued', 'acknowledged']),
      ),
      'assets': count('inventoryAssets', (query) => query),
      'maint': count(
        'inventoryAssets',
        (query) => query.where(
          'status',
          whereIn: ['under_maintenance', 'under_repair'],
        ),
      ),
    };
    final values = await Future.wait(figures.values);
    return {
      for (final (index, key) in figures.keys.indexed) key: values[index],
    };
  }

  /// Up to [reportLimit] rows of [def] for the user's campuses. Without a store/date index the
  /// ordering of balance reports is by the document (sorted in the provider).
  Future<List<ReportRow>> report(
    ModuleAccess access,
    ReportDef def, {
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final base = def.schoolWide
        ? await schoolCollection(def.collection) as Query<Map<String, dynamic>>
        : _scoped(await schoolCollection(def.collection), access);
    if (base == null) return [];
    var query = base;
    for (final mapEntry in def.where.entries) {
      query = query.where(mapEntry.key, isEqualTo: mapEntry.value);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    } else if (def.fixedStatuses.isNotEmpty) {
      query = query.where('status', whereIn: def.fixedStatuses);
    }
    if (def.hasDates) {
      Object bound(DateTime date) =>
          def.isString ? date.toApiDate() : Timestamp.fromDate(date);
      if (from != null) {
        query = query.where(def.dateField, isGreaterThanOrEqualTo: bound(from));
      }
      if (to != null) {
        query = query.where(
          def.dateField,
          isLessThan: bound(to.add(const Duration(days: 1))),
        );
      }
      query = query.orderBy(def.dateField, descending: !def.isString);
    }
    final snapshot = await query.limit(reportLimit).get();
    return [for (final document in snapshot.docs) document.data()];
  }

  static const reportLimit = 500;
}
