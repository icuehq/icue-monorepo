import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_insights.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// Dashboard figures and report rows (Inv-7): read from Firestore.
@lazySingleton
class InsightsService {
  /// Live dashboard figures for the branch (or one [store]), from the analytics summary the triggers keep
  /// (`inventoryStats/overall`). A summary nothing has written yet reads as zeros.
  Stream<Map<String, num?>> dashboard({InventoryStore? store}) async* {
    final summary = (await branchCollection(Collections.inventoryStats))
        .doc('overall');
    yield* summary.snapshots().map(
      (snapshot) =>
          overviewFigures(snapshot.data(), store?.id, today: todayIST()),
    );
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
