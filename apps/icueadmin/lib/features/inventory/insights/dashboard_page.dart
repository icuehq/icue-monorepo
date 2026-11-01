import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
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
    'items': AppRoutes.inventoryItems,
    'available': AppRoutes.inventoryStock,
    'prs': AppRoutes.inventoryPurchaseRequests,
    'approvals': AppRoutes.inventoryPurchaseRequests,
    'pos': AppRoutes.inventoryPurchaseOrders,
    'receipts': AppRoutes.inventoryPurchaseOrders,
    'assets': AppRoutes.inventoryAssets,
    'maint': AppRoutes.inventoryMaintenance,
  };

  Future<void> _load() async {
    final inv = context.read<InventoryProvider>();
    if (inv.stores.isEmpty) await inv.loadMasters();
    if (!mounted) return;
    final store = inv.stores.where((s) => s.id == _storeId).firstOrNull;
    await context.read<InsightsProvider>().loadDashboard(
      inv.access,
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
    final p = context.watch<InsightsProvider>();
    final inv = context.watch<InventoryProvider>();
    final tiles = [
      for (final (key, label, perms) in dashboardStats)
        if (perms.any(inv.access.can) && p.dashboard[key] != null)
          (key, label, p.dashboard[key]!),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (inv.access.can('inv.reports.view'))
            IconButton(
              tooltip: 'Reports',
              icon: const Icon(Icons.assessment_outlined),
              onPressed: () => context.push(AppRoutes.inventoryReports),
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
                for (final s in inv.stores.where((s) => s.active))
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) {
                _storeId = v;
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (p.isLoading && tiles.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (tiles.isEmpty)
              Center(child: Text(p.errorMessage ?? 'Nothing to show'))
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (key, label, value) in tiles)
                    SizedBox(
                      width: 160,
                      child: Card(
                        child: InkWell(
                          onTap: _targets[key] == null
                              ? null
                              : () => context.push(_targets[key]!),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  key == 'value'
                                      ? value.toStringAsFixed(2)
                                      : '${value.round()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
