import 'package:icue_firebase/icue_firebase.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory/src/models/inventory_insights.dart';
import 'package:inventory/src/models/inventory_masters.dart';
import 'package:inventory/src/models/inventory_reports.dart';
import 'package:inventory/src/services/insights_service.dart';

/// Dashboard and reports. Needs `InventoryProvider.loadMasters()` first (access, stores).
@lazySingleton
class InsightsProvider extends LoadingProvider {
  InsightsProvider(this._service);

  final InsightsService _service;

  /// The loaded report's documents and the branch's items; the stock summary also loads today's balances.
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> balances = [];
  Map<String, InventoryItem> items = {};

  /// Live overview figures; the caller listens for as long as it is on screen.
  Stream<Map<String, num?>> watchDashboard({InventoryStore? store}) =>
      _service.dashboard(store: store);

  /// Live overview figures together with the raw stats map for store breakdowns.
  Stream<InventoryDashboardSnapshot> watchDashboardSnapshot({
    InventoryStore? store,
  }) => _service.dashboardSnapshot(store: store);

  /// Loads the documents behind [report] within [from]..[to] (when it has dates), and the items.
  /// The stock summary loads movements from [from] up to today and today's balances, to work out
  /// the stock at both ends of the period.
  Future<void> loadReport(
    InventoryReport report, {
    DateTime? from,
    DateTime? to,
  }) => load(() async {
    documents = [];
    balances = [];
    final summary = report == InventoryReport.stockSummary;
    final (loaded, loadedBalances, loadedItems) = await (
      _service.reportDocuments(
        report.source,
        from: from,
        to: summary ? null : to,
      ),
      summary
          ? _service.reportDocuments(ReportSource.balances)
          : Future.value(<Map<String, dynamic>>[]),
      _service.items(),
    ).wait;
    documents = loaded;
    balances = loadedBalances;
    items = loadedItems;
  });
}
