import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/stock/balance_sheets.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final stockProvider = context.watch<StockProvider>();
    final access = inventoryProvider.access;
    final rows = stockProvider.balances.where((balance) {
      final name = stockProvider.itemName(balance.itemId).toLowerCase();
      return (!_lowOnly || balance.isBelowReorderLevel) &&
          (name.contains(_query) ||
              (balance.batchNumber ?? '').toLowerCase().contains(_query));
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => context.push(value),
            itemBuilder: (_) => [
              if (access.can('inventory.stock.operate'))
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
              value: stockProvider.store?.id,
              hint: const Text('Select a store'),
              items: [
                for (final store in inventoryProvider.stores.where(
                  (store) => store.active,
                ))
                  DropdownMenuItem(
                    value: store.id,
                    child: Text('${store.name} (${store.code})'),
                  ),
              ],
              onChanged: (id) => stockProvider.loadBalances(
                inventoryProvider.stores.firstWhere((store) => store.id == id),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
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
                  onSelected: (value) => setState(() => _lowOnly = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: stockProvider.isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            stockProvider.errorMessage ??
                                (stockProvider.store == null
                                    ? 'No store'
                                    : 'No stock'),
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
  const _BalanceTile(this.balance);

  final InventoryBalance balance;

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.read<StockProvider>();
    final unit = stockProvider.items[balance.itemId]?.stockUnit ?? '';
    final extra = [
      if (balance.batchNumber != null) 'Batch ${balance.batchNumber}',
      if (balance.expiryDate != null) 'exp ${balance.expiryDate}',
    ].join(' · ');
    return ListTile(
      title: Text(stockProvider.itemName(balance.itemId)),
      subtitle: Text(
        [
          if (extra.isNotEmpty) extra,
          'Out ${formatQuantity(balance.issuedTotal)} · In ${formatQuantity(balance.receivedTotal)}'
              '${balance.damaged > 0 ? ' · Damaged ${formatQuantity(balance.damaged)}' : ''}'
              '${balance.expired > 0 ? ' · Expired ${formatQuantity(balance.expired)}' : ''}'
              ' · ₹${balance.value.toStringAsFixed(2)}',
        ].join('\n'),
      ),
      isThreeLine: extra.isNotEmpty,
      leading: balance.isBelowReorderLevel
          ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
          : null,
      trailing: Text(
        '${formatQuantity(balance.available)} $unit',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () =>
          showFormSheet(context, () => BalanceActions(balance: balance)),
    );
  }
}
