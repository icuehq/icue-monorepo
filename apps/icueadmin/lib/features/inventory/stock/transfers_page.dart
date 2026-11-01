import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
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
    final stockProvider = context.watch<StockProvider>();
    final access = context.watch<InventoryProvider>().access;
    final canOperate = access.can('inventory.stock.operate');
    String store(String id) =>
        stockProvider.allStores
            .where((currentStore) => currentStore.id == id)
            .firstOrNull
            ?.name ??
        id;
    return Scaffold(
      appBar: AppBar(title: const Text('Transfers')),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.inventoryTransferForm);
                if (mounted) await _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Transfer'),
            )
          : null,
      body: stockProvider.transfers.isEmpty
          ? Center(
              child: stockProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Text(stockProvider.errorMessage ?? 'No transfers'),
            )
          : ListView(
              children: [
                for (final transfer in stockProvider.transfers)
                  ListTile(
                    title: Text(
                      '${transfer.number} · ${store(transfer.fromStoreId)} → ${store(transfer.toStoreId)}',
                    ),
                    subtitle: Text(
                      [
                        for (final line in transfer.requested)
                          '${stockProvider.itemName(line.itemId)} × ${formatQuantity(line.quantity)}',
                      ].join(', '),
                    ),
                    trailing: Chip(
                      label: Text(humanizeStatus(transfer.status)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: canOperate
                        ? () async {
                            await showFormSheet(
                              context,
                              () => _TransferSheet(transfer),
                            );
                            if (mounted) await _load();
                          }
                        : null,
                  ),
              ],
            ),
    );
  }
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet(this.transfer);

  final InventoryTransfer transfer;

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

  @override
  void dispose() {
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transfer = widget.transfer;
    final currentStockProvider = context.read<StockProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(transfer.number, style: Theme.of(context).textTheme.titleLarge),
        Text(humanizeStatus(transfer.status)),
        const SizedBox(height: 8),
        if (transfer.status == 'requested') ...[
          for (final line in transfer.requested)
            ListTile(
              dense: true,
              title: Text(currentStockProvider.itemName(line.itemId)),
              trailing: Text(formatQuantity(line.quantity)),
            ),
          FilledButton(
            onPressed: () => stockSubmit(
              context,
              (stockProvider) => stockProvider.act(
                'inventory-transfer-dispatch',
                {'id': transfer.id},
                requestId: _requestId,
              ),
              done: 'Dispatched',
            ),
            child: const Text('Dispatch (reduces source stock)'),
          ),
        ] else ...[
          for (final (i, l) in transfer.lineItems.indexed)
            transfer.inTransit
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _quantityControllers[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            '${currentStockProvider.itemName(l.itemId)}${l.batchNumber == null ? '' : ' · ${l.batchNumber}'}'
                            ' – receive (sent ${formatQuantity(l.dispatched)}, got ${formatQuantity(l.received)})',
                      ),
                    ),
                  )
                : ListTile(
                    dense: true,
                    title: Text(currentStockProvider.itemName(l.itemId)),
                    subtitle: l.discrepancy > 0
                        ? Text('Short by ${formatQuantity(l.discrepancy)}')
                        : null,
                    trailing: Text(
                      '${formatQuantity(l.received)} / ${formatQuantity(l.dispatched)}',
                    ),
                  ),
          if (transfer.inTransit) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Close transfer; record any shortfall'),
              value: _final,
              onChanged: (value) => setState(() => _final = value),
            ),
            FilledButton(
              onPressed: () => stockSubmit(
                context,
                (stockProvider) =>
                    stockProvider.act('inventory-transfer-receive', {
                      'id': transfer.id,
                      'final': _final,
                      'lineItems': [
                        for (final (i, c) in _quantityControllers.indexed)
                          if ((double.tryParse(c.text.trim()) ?? 0) > 0)
                            {
                              'index': i,
                              'quantityReceived': double.parse(c.text.trim()),
                            },
                      ],
                    }, requestId: _requestId),
                done: 'Receipt recorded',
              ),
              child: const Text('Confirm receipt'),
            ),
          ],
        ],
      ],
    );
  }
}
