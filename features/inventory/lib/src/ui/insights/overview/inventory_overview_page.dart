import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/home/inventory_home_page.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_attention_card.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_kpi_grid.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_quick_actions.dart';
import 'package:provider/provider.dart';

/// The Inventory landing page: the tile grid on phones, the [InventoryOverviewPage] on wide screens.
class InventoryLanding extends StatelessWidget {
  const InventoryLanding({super.key});

  @override
  Widget build(BuildContext context) => context.isWide
      ? const InventoryOverviewPage()
      : const InventoryHomePage();
}

/// Everything about Inventory at a glance (FRS 10.1): figures for the user's campuses, optionally one store.
class InventoryOverviewPage extends StatefulWidget {
  const InventoryOverviewPage({super.key});

  @override
  State<InventoryOverviewPage> createState() => _InventoryOverviewPageState();
}

class _InventoryOverviewPageState extends State<InventoryOverviewPage> {
  String? _storeId;

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
    final access = inventoryProvider.access;
    final wide = context.isWide;

    // Figures a role may not read are left out.
    final stats = <String, num?>{
      for (final (key, _, permissions) in dashboardStats)
        if (permissions.any(access.can)) key: insightsProvider.dashboard[key],
    };

    final filter = SizedBox(
      width: wide ? 240 : double.infinity,
      child: DropdownButtonFormField<String?>(
        initialValue: _storeId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Store',
          prefixIcon: Icon(Icons.warehouse_outlined, size: 18),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(child: Text('All stores')),
          for (final store in inventoryProvider.stores.where(
            (store) => store.active,
          ))
            DropdownMenuItem(
              value: store.id,
              child: Text(store.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          _storeId = value;
          _load();
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: insightsProvider.isLoading ? null : _load,
          ),
        ],
      ),
      body: IcueCenteredBody(
        child: ListView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(child: OverviewQuickActions(access: access)),
                  const SizedBox(width: 16),
                  filter,
                ],
              )
            else ...[
              filter,
              const SizedBox(height: 12),
              OverviewQuickActions(access: access),
            ],
            const SizedBox(height: 20),
            if (insightsProvider.isLoading &&
                insightsProvider.dashboard.isEmpty)
              const Padding(
                padding: EdgeInsets.all(56),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (stats.values.every((value) => value == null))
              Center(
                child: Text(insightsProvider.errorMessage ?? 'Nothing to show'),
              )
            else ...[
              OverviewKpiGrid(stats: stats),
              const SizedBox(height: 16),
              OverviewAttentionCard(stats: stats),
            ],
          ],
        ),
      ),
    );
  }
}
