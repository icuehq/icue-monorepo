import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/stock/balance_sheets.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Stock overview (FRS 10.6): one row per store × item × variant × batch.
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final _scroll = ScrollController();
  var _query = '';
  var _lowOnly = false;

  @override
  void initState() {
    super.initState();
    final inv = context.read<InventoryProvider>();
    final stock = context.read<StockProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (inv.stores.isEmpty) await inv.loadMasters();
      final first =
          stock.store ?? inv.stores.where((s) => s.active).firstOrNull;
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final p = context.watch<StockProvider>();
    final a = inv.access;
    final rows = p.balances.where((b) {
      final name = p.itemName(b.itemId).toLowerCase();
      return (!_lowOnly || b.belowReorder) &&
          (name.contains(_query) ||
              (b.batchNo ?? '').toLowerCase().contains(_query));
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (r) => context.push(r),
            itemBuilder: (_) => [
              if (a.can('inv.stock.operate'))
                const PopupMenuItem(
                  value: AppRoutes.inventoryReceive,
                  child: Text('Receive stock'),
                ),
              const PopupMenuItem(
                value: AppRoutes.inventoryRequests,
                child: Text('Issue requests'),
              ),
              const PopupMenuItem(
                value: AppRoutes.inventoryTransfers,
                child: Text('Transfers'),
              ),
              const PopupMenuItem(
                value: AppRoutes.inventoryUnavailable,
                child: Text('Damaged / expired / lost'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButton<String>(
              isExpanded: true,
              value: p.store?.id,
              hint: const Text('Select a store'),
              items: [
                for (final s in inv.stores.where((s) => s.active))
                  DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (${s.code})'),
                  ),
              ],
              onChanged: (id) =>
                  p.loadBalances(inv.stores.firstWhere((s) => s.id == id)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Filter loaded rows by item or batch',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Low'),
                  selected: _lowOnly,
                  onSelected: (v) => setState(() => _lowOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: p.isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            p.errorMessage ??
                                (p.store == null ? 'No store' : 'No stock'),
                          ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _BalanceTile(rows[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile(this.b);

  final InvBalance b;

  @override
  Widget build(BuildContext context) {
    final p = context.read<StockProvider>();
    final unit = p.items[b.itemId]?.stockUnit ?? '';
    final extra = [
      if (b.batchNo != null) 'Batch ${b.batchNo}',
      if (b.expiryDate != null) 'exp ${b.expiryDate}',
    ].join(' · ');
    return ListTile(
      title: Text(p.itemName(b.itemId)),
      subtitle: Text(
        [
          if (extra.isNotEmpty) extra,
          'Out ${fmtQty(b.issuedTotal)} · In ${fmtQty(b.receivedTotal)}'
              '${b.damaged > 0 ? ' · Damaged ${fmtQty(b.damaged)}' : ''}'
              '${b.expired > 0 ? ' · Expired ${fmtQty(b.expired)}' : ''}'
              ' · ₹${b.value.toStringAsFixed(2)}',
        ].join('\n'),
      ),
      isThreeLine: extra.isNotEmpty,
      leading: b.belowReorder
          ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
          : null,
      trailing: Text(
        '${fmtQty(b.available)} $unit',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => showInvSheet(context, () => BalanceActions(balance: b)),
    );
  }
}
