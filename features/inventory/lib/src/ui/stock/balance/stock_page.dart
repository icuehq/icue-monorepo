import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart' show textSearchSupported;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/balance/widgets/stock_balance_list.dart';
import 'package:inventory/src/ui/stock/balance/widgets/stock_balance_table.dart';
import 'package:provider/provider.dart';

/// Stock overview (FRS 10.6): balances per store × item × variant × batch.
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  /// The phone dropdown's value for "All stores" (store IDs are Firestore IDs, never this).
  static const _allStores = '*';

  final _searchController = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final inventoryProvider = context.read<InventoryProvider>();
    final stock = context.read<StockProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (inventoryProvider.stores.isEmpty) {
        await inventoryProvider.loadMasters();
      }
      if (stock.balancesLoaded) return;
      final first = inventoryProvider.stores
          .where((store) => store.active)
          .firstOrNull;
      if (first != null) await stock.loadBalances(first);
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) stock.loadMoreBalances();
    });
  }

  /// These screens change balances, so reload the visible store when they close.
  Future<void> _open(String route) async {
    final stock = context.read<StockProvider>();
    await context.push(route);
    if (mounted) await stock.reloadBalances();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _actions(InventoryBalance balance) => context.push(
    '${InventoryRoutes.inventoryStockDetails}'
    '?id=${Uri.encodeQueryComponent(balance.id)}',
  );

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final stockProvider = context.watch<StockProvider>();
    final theme = Theme.of(context);
    final wide = context.isWide;

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

    return Scaffold(
      appBar: AppBar(title: const Text('Store Stock')),
      floatingActionButton: !wide
          ? FloatingActionButton.extended(
              onPressed: () => _open(InventoryRoutes.inventoryReceive),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Receive stock'),
            )
          : null,
      body: IcueCenteredBody(
        child: Column(
          children: [
            // Store selector (phones) and summary bar
            if (!wide || (stockProvider.balancesLoaded && allRows.isNotEmpty))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
                      if (!wide &&
                          !(inventoryProvider.restricted &&
                              activeStores.length == 1))
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
                                  value: stockProvider.balancesLoaded
                                      ? (stockProvider.store?.id ?? _allStores)
                                      : null,
                                  hint: const Text('Select a store'),
                                  items: [
                                    if (activeStores.length > 1)
                                      const DropdownMenuItem(
                                        value: _allStores,
                                        child: Text(
                                          'All stores',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    for (final store in activeStores)
                                      DropdownMenuItem(
                                        value: store.id,
                                        child: Text(
                                          store.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                  onChanged: (id) {
                                    if (id == null) return;
                                    stockProvider.loadBalances(
                                      activeStores
                                          .where((store) => store.id == id)
                                          .firstOrNull,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (stockProvider.balancesLoaded &&
                          allRows.isNotEmpty) ...[
                        if (!wide) const Divider(height: 12),
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
                              'Value: ${totalStoreValue.toRupees()}',
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

            if (wide)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StockBalanceTable(
                    stockProvider: stockProvider,
                    stores: activeStores,
                    onOpen: _actions,
                    onReceive: () => _open(InventoryRoutes.inventoryReceive),
                  ),
                ),
              )
            else ...[
              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    if (textSearchSupported) ...[
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) => stockProvider.loadBalances(
                            stockProvider.store,
                            search: value,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search stock by item name…',
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
                            suffixIcon: stockProvider.balanceSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      stockProvider.loadBalances(
                                        stockProvider.store,
                                        search: '',
                                      );
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilterChip(
                      avatar: stockProvider.lowOnly
                          ? const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange,
                            )
                          : null,
                      label: Text(
                        lowStockCount > 0 ? 'Low ($lowStockCount)' : 'Low',
                      ),
                      selected: stockProvider.lowOnly,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (value) => stockProvider.loadBalances(
                        stockProvider.store,
                        lowOnly: value,
                      ),
                    ),
                  ],
                ),
              ),

              // Stock Balances List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await stockProvider.reloadBalances();
                  },
                  child: allRows.isEmpty
                      ? Center(
                          child: stockProvider.isLoading
                              ? const CircularProgressIndicator()
                              : SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          !stockProvider.balancesLoaded
                                              ? 'No store selected'
                                              : (stockProvider.lowOnly ||
                                                        stockProvider
                                                            .balanceSearch
                                                            .isNotEmpty
                                                    ? 'No matching stock'
                                                    : 'No stock in this store'),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          !stockProvider.balancesLoaded
                                              ? 'Select an active store above to view inventory balances.'
                                              : (stockProvider.lowOnly ||
                                                        stockProvider
                                                            .balanceSearch
                                                            .isNotEmpty
                                                    ? 'Try clearing the search query or low stock filter.'
                                                    : 'Receive items into this store to see balances.'),
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 18),
                                        if (stockProvider.lowOnly ||
                                            stockProvider
                                                .balanceSearch
                                                .isNotEmpty)
                                          IcueButton(
                                            label: 'Reset filters',
                                            onPressed: () {
                                              _searchController.clear();
                                              stockProvider.loadBalances(
                                                stockProvider.store,
                                                search: '',
                                                lowOnly: false,
                                              );
                                            },
                                            variant: IcueButtonVariant.outline,
                                            leadingIcon:
                                                Icons.filter_alt_off_outlined,
                                          )
                                        else
                                          IcueButton(
                                            label: 'Receive stock',
                                            onPressed: () => _open(
                                              InventoryRoutes.inventoryReceive,
                                            ),
                                            leadingIcon: Icons.add,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                        )
                      : StockBalanceList(
                          scroll: _scroll,
                          rows: allRows,
                          stockProvider: stockProvider,
                          onOpen: _actions,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
