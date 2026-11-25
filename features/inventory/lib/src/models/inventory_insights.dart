// Dashboard figures (Inv-7). Reports live in `inventory_reports.dart`.

import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/src/models/inventory_masters.dart';

/// Dashboard figures from the `inventoryStats/overall` [summary] (InventoryStatsTotals): the branch's, with the
/// stock figures of [storeId] when given. Expired and expiring stock lines are the `expiryOn` days before [today]
/// and in the next 30 (`yyyy-MM-dd`).
Map<String, num> overviewFigures(
  Map<String, dynamic>? summary,
  String? storeId, {
  required String today,
}) {
  final branch = summary ?? const <String, dynamic>{};
  final stock = storeId == null
      ? branch
      : (branch['stores'] as Map<String, dynamic>?)?[storeId]
                as Map<String, dynamic>? ??
            const <String, dynamic>{};
  num figure(Map<String, dynamic> source, String key) =>
      source[key] as num? ?? 0;
  final soon = addDays(today, 30);
  num lines(bool Function(String day) test) =>
      (stock['expiryOn'] as Map<String, dynamic>? ?? const {}).entries
          .where((entry) => test(entry.key))
          .fold<num>(0, (total, entry) => total + (entry.value as num));
  return {
    'items': figure(branch, 'items'),
    'available': figure(stock, 'available'),
    'value': figure(stock, 'value'),
    'low': figure(stock, 'lowStock'),
    'out': figure(stock, 'outOfStock'),
    'expiring': lines(
      (day) => day.compareTo(today) >= 0 && day.compareTo(soon) <= 0,
    ),
    'expired': lines((day) => day.compareTo(today) < 0),
    'prs': figure(branch, 'openPurchaseRequests'),
    'approvals': figure(branch, 'pendingIssueRequests'),
    'assets': figure(branch, 'assets'),
    'maint': figure(branch, 'underMaintenance'),
  };
}

/// Stock figures for one active store read from `inventoryStats/overall.stores`.
class StoreOverviewSummary {
  const StoreOverviewSummary({
    required this.store,
    required this.available,
    required this.value,
    required this.lowStock,
    required this.outOfStock,
  });

  final InventoryStore store;
  final num available;
  final num value;
  final int lowStock;
  final int outOfStock;
}

/// Live overview payload combining scoped [figures] and branch-wide [rawSummary].
class InventoryDashboardSnapshot {
  const InventoryDashboardSnapshot({
    required this.figures,
    required this.rawSummary,
  });

  final Map<String, num> figures;
  final Map<String, dynamic>? rawSummary;
}

/// Extracts per-store stock summaries for all active [stores] from `inventoryStats/overall`.
List<StoreOverviewSummary> storeOverviewSummaries(
  Map<String, dynamic>? summary,
  List<InventoryStore> stores,
) {
  final storesMap =
      summary?['stores'] as Map<String, dynamic>? ?? const <String, dynamic>{};
  return [
    for (final store in stores.where((currentStore) => currentStore.active))
      () {
        final storeStats =
            storesMap[store.id] as Map<String, dynamic>? ??
            const <String, dynamic>{};
        return StoreOverviewSummary(
          store: store,
          available: storeStats['available'] as num? ?? 0,
          value: storeStats['value'] as num? ?? 0,
          lowStock: (storeStats['lowStock'] as num? ?? 0).round(),
          outOfStock: (storeStats['outOfStock'] as num? ?? 0).round(),
        );
      }(),
  ];
}

/// Dashboard tiles (FRS 10.1): key, label.
const dashboardStats = <(String, String)>[
  ('items', 'Active items'),
  ('available', 'Available stock'),
  ('value', 'Stock value'),
  ('low', 'Low-stock lines'),
  ('out', 'Out-of-stock lines'),
  ('expiring', 'Expiring in 30 days'),
  ('expired', 'Expired lines'),
  ('prs', 'Open purchase requests'),
  ('approvals', 'Pending approvals'),
  ('assets', 'Registered assets'),
  ('maint', 'Assets under maintenance'),
];
