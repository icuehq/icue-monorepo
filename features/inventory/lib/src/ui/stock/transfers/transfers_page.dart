import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/transfers/transfer_rules.dart';
import 'package:inventory/src/ui/stock/transfers/widgets/transfer_card.dart';
import 'package:provider/provider.dart';

/// Stock transfers (FRS 10.10): request → dispatch → receipt.
class TransfersPage extends StatefulWidget {
  const TransfersPage({super.key});

  @override
  State<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends State<TransfersPage> {
  String _selectedFilter = 'all';

  /// False until the first fetch ends, so rows from an earlier visit never flash.
  var _loaded = false;

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    final stockProvider = context.read<StockProvider>();
    await stockProvider.loadAllStores();
    if (mounted) await stockProvider.loadTransfers(inventoryProvider.access);
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockProvider = context.watch<StockProvider>();
    final access = context.watch<InventoryProvider>().access;
    final canOperate = access.can('inventory.stock.operate');

    String storeName(String id) =>
        stockProvider.allStores
            .where((currentStore) => currentStore.id == id)
            .firstOrNull
            ?.name ??
        id;

    final allTransfers = stockProvider.transfers;
    final filteredTransfers = allTransfers.where((transfer) {
      if (_selectedFilter == 'requested') {
        return transfer.preDispatch;
      }
      if (_selectedFilter == 'in_transit') {
        return transfer.inTransit;
      }
      if (_selectedFilter == 'received') {
        return transfer.status == 'received';
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Transfers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              onPressed: () => _open(InventoryRoutes.inventoryTransferForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Transfer'),
            )
          : null,
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${allTransfers.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'requested',
                  'Requested (${allTransfers.where((t) => t.preDispatch).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'in_transit',
                  'In Transit (${allTransfers.where((t) => t.inTransit).length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'received',
                  'Received (${allTransfers.where((t) => t.status == "received").length})',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Transfer list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child:
                  !_loaded || (stockProvider.isLoading && allTransfers.isEmpty)
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTransfers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              stockProvider.errorMessage != null
                                  ? 'Could not load transfers'
                                  : _selectedFilter == 'all'
                                  ? 'No stock transfers found'
                                  : 'No transfers in this status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stockProvider.errorMessage ??
                                  (canOperate
                                      ? 'Initiate a new transfer between stores to move stock.'
                                      : 'Stock transfers will appear here once requested.'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTransfers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final transfer = filteredTransfers[index];
                        return TransferCard(
                          transfer: transfer,
                          fromStoreName: storeName(transfer.fromStoreId),
                          toStoreName: storeName(transfer.toStoreId),
                          getItemName: stockProvider.itemName,
                          nextAction: transferNextAction(transfer, access),
                          onTap: () => _open(
                            '${InventoryRoutes.inventoryTransferDetail}?id=${transfer.id}',
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

  Widget _buildFilterChip(String key, String label) {
    final selected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }
}
