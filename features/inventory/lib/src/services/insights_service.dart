import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_insights.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// Dashboard counts and report rows (Inv-7): reads from Firestore.
@lazySingleton
class InsightsService {
  /// Dashboard figures for the branch (or one [store]). A figure the user's permissions cannot read is null.
  Future<Map<String, num?>> dashboard({InventoryStore? store}) async {
    final today = todayIST();
    final soon = dayTimestamp(
      DateTime.parse(today).add(const Duration(days: 30)).toApiDate(),
    );
    Future<Query<Map<String, dynamic>>> scope(
      String collection, {
      bool byStore = false,
    }) async {
      final query = await branchCollection(collection);
      return !byStore || store == null
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
        return (await f(query).count().get()).count;
      } catch (_) {
        return null;
      }
    }

    Future<num?> total(String field) async {
      try {
        final query = await scope('inventoryBalances', byStore: true);
        return (await query.aggregate(sum(field)).get()).getSum(field);
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
        return (await (await branchCollection(
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
            .where(
              'earliestExpiryDate',
              isGreaterThanOrEqualTo: dayTimestamp(today),
            )
            .where('earliestExpiryDate', isLessThanOrEqualTo: soon),
      ),
      'expired': bal(
        (query) =>
            query.where('earliestExpiryDate', isLessThan: dayTimestamp(today)),
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

  /// Up to [reportLimit] rows of [def] for the branch. Without a store/date index the
  /// ordering of balance reports is by the document (sorted in the provider).
  Future<List<ReportRow>> report(
    ReportDef def, {
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(def.collection);
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
          def.isDay ? dayTimestamp(date.toApiDate()) : Timestamp.fromDate(date);
      if (from != null) {
        query = query.where(def.dateField, isGreaterThanOrEqualTo: bound(from));
      }
      if (to != null) {
        query = query.where(
          def.dateField,
          isLessThan: bound(to.add(const Duration(days: 1))),
        );
      }
      query = query.orderBy(def.dateField, descending: !def.isDay);
    }
    final snapshot = await query.limit(reportLimit).get();
    return [for (final document in snapshot.docs) document.data()];
  }

  static const reportLimit = 500;
}
