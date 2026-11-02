import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/stock/transfer_card.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Stock transfers (FRS 10.10): request → dispatch → receipt.
class TransfersPage extends StatefulWidget {
  const TransfersPage({super.key});

  @override
  State<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends State<TransfersPage> {
  String _selectedFilter = 'all';

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.stores.isEmpty) await inventoryProvider.loadMasters();
    if (!mounted) return;
    final stockProvider = context.read<StockProvider>();
    await stockProvider.loadAllStores();
    if (mounted) await stockProvider.loadTransfers(inventoryProvider.access);
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
        return transfer.status == 'requested';
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
              onPressed: () async {
                await context.push(AppRoutes.inventoryTransferForm);
                if (mounted) await _load();
              },
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
                  'Requested (${allTransfers.where((t) => t.status == "requested").length})',
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
              child: stockProvider.isLoading && allTransfers.isEmpty
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
                              _selectedFilter == 'all'
                                  ? 'No stock transfers found'
                                  : 'No transfers in this status',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              canOperate
                                  ? 'Initiate a new transfer between stores to move stock.'
                                  : 'Stock transfers will appear here once requested.',
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
                          onTap: canOperate
                              ? () async {
                                  await showFormSheet(
                                    context,
                                    () => _TransferSheet(
                                      transfer: transfer,
                                      fromStoreName: storeName(
                                        transfer.fromStoreId,
                                      ),
                                      toStoreName: storeName(
                                        transfer.toStoreId,
                                      ),
                                    ),
                                  );
                                  if (mounted) await _load();
                                }
                              : null,
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

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({
    required this.transfer,
    required this.fromStoreName,
    required this.toStoreName,
  });

  final InventoryTransfer transfer;
  final String fromStoreName;
  final String toStoreName;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  late final _quantityControllers = [
    for (final transferLine in widget.transfer.lineItems)
      TextEditingController(
        text: formatQuantity(transferLine.dispatched - transferLine.received),
      ),
  ];
  final _requestId = newRequestId();
  var _final = false;
  var _busy = false;

  @override
  void dispose() {
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transfer = widget.transfer;
    final currentStockProvider = context.read<StockProvider>();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transfer.number,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.fromStoreName} ➔ ${widget.toStoreName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(humanizeStatus(transfer.status)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Requested State -> Dispatch action
          if (transfer.status == 'requested') ...[
            Text(
              'Items to Dispatch',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final line in transfer.requested)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(currentStockProvider.itemName(line.itemId)),
                  trailing: Text(
                    '${formatQuantity(line.quantity)} requested',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dispatching will allocate and deduct quantities from ${widget.fromStoreName}.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await stockSubmit(
                        context,
                        (stockProvider) => stockProvider.act(
                          'inventory-transfer-dispatch',
                          {'id': transfer.id},
                          requestId: _requestId,
                        ),
                        done: 'Transfer dispatched successfully',
                      );
                      if (mounted) setState(() => _busy = false);
                    },
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(_busy ? 'Dispatching…' : 'Dispatch Transfer'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ] else ...[
            // In transit or received lines
            Text(
              transfer.inTransit ? 'Receive Stock' : 'Transfer Lines',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, l) in transfer.lineItems.indexed) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${currentStockProvider.itemName(l.itemId)}${l.batchNumber == null ? '' : ' · Batch ${l.batchNumber}'}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'Sent ${formatQuantity(l.dispatched)} | Got ${formatQuantity(l.received)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (l.discrepancy > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Shortfall: ${formatQuantity(l.discrepancy)} units',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (transfer.inTransit) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _quantityControllers[i],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Receive quantity now',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.all_inclusive, size: 16),
                              tooltip: 'Fill remaining',
                              onPressed: () {
                                _quantityControllers[i].text = formatQuantity(
                                  l.dispatched - l.received,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (transfer.inTransit) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Close transfer upon receipt'),
                subtitle: const Text(
                  'Record any unreceived items as permanent shortfall/discrepancy',
                ),
                value: _final,
                onChanged: (value) => setState(() => _final = value),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await stockSubmit(
                          context,
                          (
                            stockProvider,
                          ) => stockProvider.act('inventory-transfer-receive', {
                            'id': transfer.id,
                            'final': _final,
                            'lineItems': [
                              for (final (i, c) in _quantityControllers.indexed)
                                if ((double.tryParse(c.text.trim()) ?? 0) > 0)
                                  {
                                    'index': i,
                                    'quantityReceived': double.parse(
                                      c.text.trim(),
                                    ),
                                  },
                            ],
                          }, requestId: _requestId),
                          done: 'Receipt recorded successfully',
                        );
                        if (mounted) setState(() => _busy = false);
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_busy ? 'Recording…' : 'Confirm Receipt'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
