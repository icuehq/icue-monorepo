import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
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
    final inv = context.read<InventoryProvider>();
    if (inv.stores.isEmpty) await inv.loadMasters();
    if (!mounted) return;
    final p = context.read<StockProvider>();
    await p.loadAllStores();
    if (mounted) await p.loadTransfers(inv.access);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StockProvider>();
    final a = context.watch<InventoryProvider>().access;
    final canOperate = a.can('inv.stock.operate');
    String store(String id) =>
        p.allStores.where((s) => s.id == id).firstOrNull?.name ?? id;
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
      body: p.transfers.isEmpty
          ? Center(
              child: p.isLoading
                  ? const CircularProgressIndicator()
                  : Text(p.errorMessage ?? 'No transfers'),
            )
          : ListView(
              children: [
                for (final t in p.transfers)
                  ListTile(
                    title: Text(
                      '${t.number} · ${store(t.fromStoreId)} → ${store(t.toStoreId)}',
                    ),
                    subtitle: Text(
                      [
                        for (final l in t.requested)
                          '${p.itemName(l.itemId)} × ${fmtQty(l.qty)}',
                      ].join(', '),
                    ),
                    trailing: Chip(
                      label: Text(statusLabel(t.status)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: canOperate
                        ? () async {
                            await showInvSheet(
                              context,
                              () => _TransferSheet(t),
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
  const _TransferSheet(this.t);

  final InvTransfer t;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  late final _qty = [
    for (final l in widget.t.lines)
      TextEditingController(text: fmtQty(l.dispatched - l.received)),
  ];
  final _requestId = newRequestId();
  var _final = false;

  @override
  void dispose() {
    for (final c in _qty) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final p = context.read<StockProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.number, style: Theme.of(context).textTheme.titleLarge),
        Text(statusLabel(t.status)),
        const SizedBox(height: 8),
        if (t.status == 'requested') ...[
          for (final l in t.requested)
            ListTile(
              dense: true,
              title: Text(p.itemName(l.itemId)),
              trailing: Text(fmtQty(l.qty)),
            ),
          FilledButton(
            onPressed: () => stockSubmit(
              context,
              (p) => p.act('inv-transfer-dispatch', {
                'id': t.id,
              }, requestId: _requestId),
              done: 'Dispatched',
            ),
            child: const Text('Dispatch (reduces source stock)'),
          ),
        ] else ...[
          for (final (i, l) in t.lines.indexed)
            t.inTransit
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _qty[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            '${p.itemName(l.itemId)}${l.batchNo == null ? '' : ' · ${l.batchNo}'}'
                            ' – receive (sent ${fmtQty(l.dispatched)}, got ${fmtQty(l.received)})',
                      ),
                    ),
                  )
                : ListTile(
                    dense: true,
                    title: Text(p.itemName(l.itemId)),
                    subtitle: l.discrepancy > 0
                        ? Text('Short by ${fmtQty(l.discrepancy)}')
                        : null,
                    trailing: Text(
                      '${fmtQty(l.received)} / ${fmtQty(l.dispatched)}',
                    ),
                  ),
          if (t.inTransit) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Close transfer; record any shortfall'),
              value: _final,
              onChanged: (v) => setState(() => _final = v),
            ),
            FilledButton(
              onPressed: () => stockSubmit(
                context,
                (p) => p.act('inv-transfer-receive', {
                  'id': t.id,
                  'final': _final,
                  'lines': [
                    for (final (i, c) in _qty.indexed)
                      if ((double.tryParse(c.text.trim()) ?? 0) > 0)
                        {
                          'index': i,
                          'qtyReceived': double.parse(c.text.trim()),
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
