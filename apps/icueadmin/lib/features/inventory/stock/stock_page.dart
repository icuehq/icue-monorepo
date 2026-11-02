import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/stock/balance_sheets.dart';
import 'package:icueadmin/features/inventory/stock/stock_balance_card.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Stock overview (FRS 10.6): balances per store × item × variant × batch.
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  var _query = '';
  var _lowOnly = false;

  @override
  void initState() {
    super.initState();
    final inventoryProvider = context.read<InventoryProvider>();
    final stock = context.read<StockProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (inventoryProvider.stores.isEmpty) {
        await inventoryProvider.loadMasters();
      }
      final first =
          stock.store ??
          inventoryProvider.stores.where((store) => store.active).firstOrNull;
      if (first != null) await stock.loadBalances(first);
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300 && stock.store != null) {
        stock.loadBalances(stock.store!, more: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _quickActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
        label: Text(label),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        backgroundColor: theme.colorScheme.surface,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final stockProvider = context.watch<StockProvider>();
    final access = inventoryProvider.access;
    final theme = Theme.of(context);
    final canOperate = access.can('inventory.stock.operate');

    final activeStores = inventoryProvider.stores
        .where((store) => store.active)
        .toList();

    final allRows = stockProvider.balances;
    final lowStockCount = allRows
        .where((balance) => balance.isBelowReorderLevel)
        .length;
    final totalStoreValue = allRows.fold<double>(
      0,
      (sum, balance) => sum + balance.value,
    );

    final filteredRows = allRows.where((balance) {
      final item = stockProvider.items[balance.itemId];
      final name = (item?.name ?? balance.itemId).toLowerCase();
      final code = (item?.code ?? '').toLowerCase();
      final batch = (balance.batchNumber ?? '').toLowerCase();

      final matchesQuery =
          _query.isEmpty ||
          name.contains(_query) ||
          code.contains(_query) ||
          batch.contains(_query);

      final matchesLow = !_lowOnly || balance.isBelowReorderLevel;
      return matchesQuery && matchesLow;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Store Stock')),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.inventoryReceive),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Receive stock'),
            )
          : null,
      body: Column(
        children: [
          // Store Selector & Summary Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: stockProvider.store?.id,
                            hint: const Text('Select a store'),
                            items: [
                              for (final store in activeStores)
                                DropdownMenuItem(
                                  value: store.id,
                                  child: Text(
                                    '${store.name} (${store.code}) · Campus ${store.campusId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (id) {
                              if (id == null) return;
                              final store = activeStores.firstWhere(
                                (store) => store.id == id,
                              );
                              stockProvider.loadBalances(store);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (stockProvider.store != null && allRows.isNotEmpty) ...[
                    const Divider(height: 12),
                    Row(
                      children: [
                        Text(
                          '${allRows.length} item${allRows.length == 1 ? '' : 's'} in store',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Value: ₹${totalStoreValue.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (lowStockCount > 0) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 13,
                                  color: Colors.orange.shade900,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$lowStockCount low stock',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Horizontal Quick Actions Bar
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                if (canOperate)
                  _quickActionChip(
                    context,
                    icon: Icons.move_to_inbox_outlined,
                    label: 'Receive',
                    onTap: () => context.push(AppRoutes.inventoryReceive),
                  ),
                _quickActionChip(
                  context,
                  icon: Icons.outbox_outlined,
                  label: 'Issue requests',
                  onTap: () => context.push(AppRoutes.inventoryRequests),
                ),
                _quickActionChip(
                  context,
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transfers',
                  onTap: () => context.push(AppRoutes.inventoryTransfers),
                ),
                _quickActionChip(
                  context,
                  icon: Icons.report_problem_outlined,
                  label: 'Damaged / Expired',
                  onTap: () => context.push(AppRoutes.inventoryUnavailable),
                ),
              ],
            ),
          ),

          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search stock by item or batch…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: _lowOnly
                      ? const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.orange,
                        )
                      : null,
                  label: Text(
                    lowStockCount > 0 ? 'Low ($lowStockCount)' : 'Low',
                  ),
                  selected: _lowOnly,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (value) => setState(() => _lowOnly = value),
                ),
              ],
            ),
          ),

          // Stock Balances List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (stockProvider.store != null) {
                  await stockProvider.loadBalances(stockProvider.store!);
                }
              },
              child: filteredRows.isEmpty
                  ? Center(
                      child: stockProvider.isLoading
                          ? const CircularProgressIndicator()
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        size: 36,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      stockProvider.store == null
                                          ? 'No store selected'
                                          : (_lowOnly || _query.isNotEmpty
                                                ? 'No matching stock'
                                                : 'No stock in this store'),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      stockProvider.store == null
                                          ? 'Select an active store above to view inventory balances.'
                                          : (_lowOnly || _query.isNotEmpty
                                                ? 'Try clearing the search query or low stock filter.'
                                                : 'Receive items or transfer stock into this store to see balances.'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (_lowOnly || _query.isNotEmpty)
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _query = '';
                                            _lowOnly = false;
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.filter_alt_off_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Reset filters'),
                                      )
                                    else if (canOperate)
                                      FilledButton.icon(
                                        onPressed: () => context.push(
                                          AppRoutes.inventoryReceive,
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Receive stock'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount:
                          filteredRows.length +
                          (stockProvider.hasMoreBalances ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == filteredRows.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final balance = filteredRows[i];
                        final item = stockProvider.items[balance.itemId];
                        return StockBalanceCard(
                          balance: balance,
                          itemName: stockProvider.itemName(balance.itemId),
                          itemCode: item?.code,
                          stockUnit: item?.stockUnit,
                          reorderLevel: item?.reorderLevel,
                          onTap: () => showFormSheet(
                            context,
                            () => BalanceActions(balance: balance),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
