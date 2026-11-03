import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Inventory dashboard (FRS 10.1): figures for the user's campuses, optionally one store.
class InventoryDashboardPage extends StatefulWidget {
  const InventoryDashboardPage({super.key});

  @override
  State<InventoryDashboardPage> createState() => _InventoryDashboardPageState();
}

class _InventoryDashboardPageState extends State<InventoryDashboardPage> {
  String? _storeId;

  // Where a tile leads (FRS 10.1 user actions); null = not tappable.
  static const _targets = {
    'items': InventoryRoutes.inventoryItems,
    'available': InventoryRoutes.inventoryStock,
    'prs': InventoryRoutes.inventoryPurchaseRequests,
    'approvals': InventoryRoutes.inventoryPurchaseRequests,
    'pos': InventoryRoutes.inventoryPurchaseOrders,
    'receipts': InventoryRoutes.inventoryPurchaseOrders,
    'assets': InventoryRoutes.inventoryAssets,
    'maint': InventoryRoutes.inventoryMaintenance,
  };

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    final store = inventoryProvider.stores
        .where((currentStore) => currentStore.id == _storeId)
        .firstOrNull;
    await context.read<InsightsProvider>().loadDashboard(
      inventoryProvider.access,
      store: store,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final insightsProvider = context.watch<InsightsProvider>();
    final inventoryProvider = context.watch<InventoryProvider>();
    final tiles = [
      for (final (key, label, permissions) in dashboardStats)
        if (permissions.any(inventoryProvider.access.can) &&
            insightsProvider.dashboard[key] != null)
          StatTile(
            label: label,
            value: insightsProvider.dashboard[key]!,
            route: _targets[key],
            isAmount: key == 'value',
          ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (inventoryProvider.access.can('inventory.reports.view'))
            IconButton(
              tooltip: 'Reports',
              icon: const Icon(Icons.assessment_outlined),
              onPressed: () => context.push(InventoryRoutes.inventoryReports),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _storeId,
              decoration: const InputDecoration(labelText: 'Store'),
              items: [
                const DropdownMenuItem(child: Text('All stores')),
                for (final store in inventoryProvider.stores.where(
                  (store) => store.active,
                ))
                  DropdownMenuItem(value: store.id, child: Text(store.name)),
              ],
              onChanged: (value) {
                _storeId = value;
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (insightsProvider.isLoading && tiles.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (tiles.isEmpty)
              Center(
                child: Text(insightsProvider.errorMessage ?? 'Nothing to show'),
              )
            else
              StatTileGrid(tiles: tiles),
          ],
        ),
      ),
    );
  }
}
