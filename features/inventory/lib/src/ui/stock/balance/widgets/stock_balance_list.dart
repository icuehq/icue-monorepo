import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/balance/widgets/stock_balance_card.dart';

/// Stock balances as a table on wide screens, cards on phones.
class StockBalanceList extends StatelessWidget {
  const StockBalanceList({
    required this.scroll,
    required this.rows,
    required this.stockProvider,
    required this.onOpen,
    super.key,
  });

  final ScrollController scroll;
  final List<InventoryBalance> rows;
  final StockProvider stockProvider;
  final void Function(InventoryBalance balance) onOpen;

  @override
  Widget build(BuildContext context) => AdaptiveList<InventoryBalance>(
    controller: scroll,
    items: rows,
    onTap: onOpen,
    columns: [
      AdaptiveColumn.text(
        'Item',
        (balance) => stockProvider.itemName(balance.itemId),
        flex: 3,
      ),
      AdaptiveColumn.text(
        'Code',
        (balance) => stockProvider.items[balance.itemId]?.code ?? '—',
      ),
      AdaptiveColumn.text(
        'Available',
        (balance) =>
            '${balance.available.toQuantityText()} ${stockProvider.items[balance.itemId]?.stockUnit ?? ''}',
      ),
      AdaptiveColumn.text(
        'Damaged',
        (balance) => balance.damaged.toQuantityText(),
      ),
      AdaptiveColumn.text(
        'Expired',
        (balance) => balance.expired.toQuantityText(),
      ),
      AdaptiveColumn.text('Value', (balance) => balance.value.toRupees()),
      AdaptiveColumn(
        label: '',
        cell: (context, balance) => balance.isBelowReorderLevel
            ? Text(
                'Low stock',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : const SizedBox.shrink(),
      ),
    ],
    cardBuilder: (context, balance) {
      final item = stockProvider.items[balance.itemId];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: StockBalanceCard(
          balance: balance,
          itemName: stockProvider.itemName(balance.itemId),
          itemCode: item?.code,
          stockUnit: item?.stockUnit,
          reorderLevel: item?.reorderLevel,
          onTap: () => onOpen(balance),
        ),
      );
    },
    footer: stockProvider.hasMoreBalances
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        : null,
  );
}
