import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/home/inventory_home_page.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_attention_card.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_issue_requests_card.dart';
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

/// Everything about Inventory at a glance (FRS 10.1): figures for the branch, optionally one store.
class InventoryOverviewPage extends StatefulWidget {
  const InventoryOverviewPage({super.key});

  @override
  State<InventoryOverviewPage> createState() => _InventoryOverviewPageState();
}

class _InventoryOverviewPageState extends State<InventoryOverviewPage> {
  String? _storeId;
  Stream<Map<String, num?>>? _stats;

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    // A store manager has no "All stores" figure: it is always one of their stores.
    if (inventoryProvider.restricted &&
        !inventoryProvider.stores.any((store) => store.id == _storeId)) {
      _storeId = inventoryProvider.stores.firstOrNull?.id;
    }
    final store = inventoryProvider.stores
        .where((currentStore) => currentStore.id == _storeId)
        .firstOrNull;
    setState(
      () => _stats = context.read<InsightsProvider>().watchDashboard(
        store: store,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final wide = context.isWide;

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
          if (!inventoryProvider.restricted)
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

    final showFilter =
        !inventoryProvider.restricted || inventoryProvider.showStoreFilter;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: StreamBuilder<Map<String, num?>>(
        stream: _stats,
        builder: (context, snapshot) {
          final stats = <String, num?>{
            for (final (key, _) in dashboardStats) key: snapshot.data?[key],
          };
          return IcueCenteredBody(
            child: ListView(
              padding: EdgeInsets.all(wide ? 24 : 16),
              children: [
                if (wide)
                  Row(
                    children: [
                      const Expanded(child: OverviewQuickActions()),
                      const SizedBox(width: 16),
                      if (showFilter) filter,
                    ],
                  )
                else ...[
                  if (showFilter) ...[filter, const SizedBox(height: 12)],
                  const OverviewQuickActions(),
                ],
                const SizedBox(height: 20),
                if (snapshot.hasError)
                  Center(child: Text(callableErrorMessage(snapshot.error!)))
                else if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.all(56),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const OverviewIssueRequestsCard(),
                  const SizedBox(height: 16),
                  OverviewKpiGrid(stats: stats),
                  const SizedBox(height: 16),
                  OverviewAttentionCard(stats: stats),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
