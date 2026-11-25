import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_insights.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_reports.dart';

/// Dashboard figures and report data (Inv-7): read from Firestore.
@lazySingleton
class InsightsService {
  /// Live dashboard figures for the branch (or one [store]), from the analytics summary the triggers keep
  /// (`inventoryStats/overall`). A summary nothing has written yet reads as zeros.
  Stream<Map<String, num?>> dashboard({InventoryStore? store}) =>
      dashboardSnapshot(store: store).map((snapshot) => snapshot.figures);

  /// Live dashboard figures plus the raw `inventoryStats/overall` document for per-store summaries.
  Stream<InventoryDashboardSnapshot> dashboardSnapshot({
    InventoryStore? store,
  }) async* {
    final summary = (await branchCollection(Collections.inventoryStats))
        .doc('overall');
    yield* summary.snapshots().map((snapshot) {
      final data = snapshot.data();
      return InventoryDashboardSnapshot(
        figures: overviewFigures(data, store?.id, today: todayIST()),
        rawSummary: data,
      );
    });
  }

  /// Up to [reportLimit] documents of [source] (with their `id`), newest first, within [from]..[to]
  /// when it has dates (no [to]: up to today). Issues also get their request's `requesterName` and `purpose`.
  Future<List<Map<String, dynamic>>> reportDocuments(
    ReportSource source, {
    DateTime? from,
    DateTime? to,
  }) async {
    Query<Map<String, dynamic>> query = await branchCollection(
      source.collection,
    );
    final dateField = source.dateField;
    if (dateField != null) {
      if (from != null) {
        query = query.where(
          dateField,
          isGreaterThanOrEqualTo: dayTimestamp(from.toApiDate()),
        );
      }
      if (to != null) {
        query = query.where(
          dateField,
          isLessThan: dayTimestamp(to.add(const Duration(days: 1)).toApiDate()),
        );
      }
      query = query.orderBy(dateField, descending: true);
    }
    final snapshot = await query.limit(reportLimit).get();
    final documents = [
      for (final document in snapshot.docs)
        {'id': document.id, ...document.data()},
    ];
    if (source == ReportSource.issues) await _addRequesters(documents);
    return documents;
  }

  /// Copies each issue's request `requesterName` and `purpose` onto it.
  Future<void> _addRequesters(List<Map<String, dynamic>> issues) async {
    final requests = await branchCollection('inventoryIssueRequests');
    final ids = {
      for (final issue in issues) readString(issue['issueRequestId']),
    }..remove('');
    final byId = <String, Map<String, dynamic>>{};
    final idList = ids.toList();
    for (var start = 0; start < idList.length; start += 30) {
      final snapshot = await requests
          .where(
            FieldPath.documentId,
            whereIn: idList.sublist(
              start,
              (start + 30).clamp(0, idList.length),
            ),
          )
          .get();
      for (final document in snapshot.docs) {
        byId[document.id] = document.data();
      }
    }
    for (final issue in issues) {
      final request = byId[issue['issueRequestId']];
      issue['requesterName'] = request?['requesterName'];
      issue['purpose'] = request?['purpose'];
    }
  }

  /// Every item of the branch (names, units, reorder levels and items with no stock yet).
  Future<Map<String, InventoryItem>> items() async {
    final snapshot = await (await branchCollection('inventoryItems')).get();
    return {
      for (final document in snapshot.docs)
        document.id: InventoryItem.fromMap(document.id, document.data()),
    };
  }

  static const reportLimit = 5000;
}
