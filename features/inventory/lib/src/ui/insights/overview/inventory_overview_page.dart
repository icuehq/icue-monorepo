import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/home/inventory_home_page.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_attention_card.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_issue_requests_card.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_kpi_grid.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_quick_actions.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_skeleton.dart';
import 'package:inventory/src/ui/insights/overview/widgets/overview_stores_card.dart';
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
  Stream<InventoryDashboardSnapshot>? _dashboard;
  int _refreshVersion = 0;

  Future<void> _load({bool reloadMasters = false}) async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (reloadMasters || inventoryProvider.stores.isEmpty) {
      await inventoryProvider.loadMasters();
    }
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
      () => _dashboard = context
          .read<InsightsProvider>()
          .watchDashboardSnapshot(store: store),
    );
  }

  Future<void> _refresh() async {
    setState(() => _refreshVersion++);
    await _load(reloadMasters: true);
  }

  void _selectStore(String? storeId) {
    if (_storeId == storeId) return;
    _storeId = storeId;
    _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryProvider = context.watch<InventoryProvider>();
    final wide = context.isWide;
    final activeStores = inventoryProvider.stores
        .where((store) => store.active)
        .toList();
    final selectedStore = activeStores
        .where((store) => store.id == _storeId)
        .firstOrNull;
    final showFilter =
        !inventoryProvider.restricted || inventoryProvider.showStoreFilter;
    final canvasColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerLowest
        : Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.025),
            const Color(0xFFF6F7FB),
          );

    return Scaffold(
      backgroundColor: canvasColor,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: StreamBuilder<InventoryDashboardSnapshot>(
        stream: _dashboard,
        builder: (context, snapshot) {
          final rawFigures = snapshot.data?.figures;
          final stats = <String, num?>{
            for (final (key, _) in dashboardStats) key: rawFigures?[key],
          };
          final alertCount = [
            'out',
            'expired',
            'low',
            'expiring',
            'approvals',
            'maint',
          ].where((key) => (stats[key] ?? 0) > 0).length;
          final storeSummaries = storeOverviewSummaries(
            snapshot.data?.rawSummary,
            inventoryProvider.stores,
          );
          final loadError =
              snapshot.error ??
              (_dashboard == null ? inventoryProvider.errorMessage : null);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal =
                    constraints.maxWidth >= IcueBreakpoints.table;
                final storeSelector = _StoreFilterPill(
                  selectedStoreId: _storeId,
                  stores: activeStores,
                  allowAll: !inventoryProvider.restricted,
                  onChanged: _selectStore,
                );

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(wide ? 24 : 16),
                  children: [
                    _OverviewHeaderCard(
                      scopeTitle: selectedStore?.name ?? 'All stores',
                      storeCount: activeStores.length,
                      alertCount: snapshot.hasData ? alertCount : null,
                      horizontal: horizontal,
                      storeFilter: showFilter ? storeSelector : null,
                    ),
                    const SizedBox(height: 16),
                    const OverviewQuickActions(),
                    const SizedBox(height: 18),
                    if (loadError != null)
                      IcueEmptyState.error(
                        message: loadError is String
                            ? loadError
                            : callableErrorMessage(loadError),
                        onAction: _refresh,
                      )
                    else if (!snapshot.hasData)
                      OverviewSkeleton(horizontal: horizontal)
                    else ...[
                      OverviewKpiGrid(
                        stats: stats,
                        storeName: selectedStore?.name,
                      ),
                      const SizedBox(height: 18),
                      if (horizontal)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: OverviewIssueRequestsCard(
                                refreshVersion: _refreshVersion,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  OverviewAttentionCard(stats: stats),
                                  if (!inventoryProvider.restricted &&
                                      storeSummaries.length > 1) ...[
                                    const SizedBox(height: 16),
                                    OverviewStoresCard(
                                      stores: storeSummaries,
                                      selectedStoreId: _storeId,
                                      onSelectStore: _selectStore,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        OverviewAttentionCard(stats: stats),
                        const SizedBox(height: 16),
                        OverviewIssueRequestsCard(
                          refreshVersion: _refreshVersion,
                        ),
                        if (!inventoryProvider.restricted &&
                            storeSummaries.length > 1) ...[
                          const SizedBox(height: 16),
                          OverviewStoresCard(
                            stores: storeSummaries,
                            selectedStoreId: _storeId,
                            onSelectStore: _selectStore,
                          ),
                        ],
                      ],
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OverviewHeaderCard extends StatelessWidget {
  const _OverviewHeaderCard({
    required this.scopeTitle,
    required this.storeCount,
    required this.alertCount,
    required this.horizontal,
    this.storeFilter,
  });

  final String scopeTitle;
  final int storeCount;
  final int? alertCount;
  final bool horizontal;
  final Widget? storeFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAlerts = (alertCount ?? 0) > 0;
    final statusColor = hasAlerts
        ? const Color(0xFFD97706)
        : Colors.green.shade700;

    final titleBlock = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.warehouse_rounded,
            size: 22,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      scopeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (alertCount != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasAlerts
                                ? '$alertCount alert${alertCount == 1 ? '' : 's'}'
                                : 'All clear',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                storeCount == 0
                    ? 'Live stock, approvals & asset overview'
                    : '$storeCount active store${storeCount == 1 ? '' : 's'} · Live stock, approvals & assets',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(horizontal ? 18 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: horizontal
          ? Row(
              children: [
                Expanded(child: titleBlock),
                if (storeFilter != null) ...[
                  const SizedBox(width: 16),
                  SizedBox(width: 240, child: storeFilter),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                if (storeFilter != null) ...[
                  const SizedBox(height: 14),
                  storeFilter!,
                ],
              ],
            ),
    );
  }
}

class _StoreFilterPill extends StatelessWidget {
  const _StoreFilterPill({
    required this.selectedStoreId,
    required this.stores,
    required this.allowAll,
    required this.onChanged,
  });

  final String? selectedStoreId;
  final List<InventoryStore> stores;
  final bool allowAll;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                key: ValueKey(selectedStoreId),
                value: selectedStoreId,
                isExpanded: true,
                isDense: true,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  if (allowAll)
                    const DropdownMenuItem(child: Text('All stores')),
                  for (final store in stores)
                    DropdownMenuItem(
                      value: store.id,
                      child: Text(store.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
