import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/balance/widgets/stock_balance_card.dart';

/// Phone stock balances as cards; wide screens use `StockBalanceTable`.
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
  Widget build(BuildContext context) => ListView.builder(
    controller: scroll,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.only(top: 4, bottom: 88),
    itemCount: rows.length + (stockProvider.hasMoreBalances ? 1 : 0),
    itemBuilder: (context, index) {
      if (index == rows.length) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final balance = rows[index];
      final item = stockProvider.items[balance.itemId];
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
  );
}
