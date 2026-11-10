import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Wide-screen stock balances of the selected store: an [IcueClientTable] over
/// the balances loaded so far, with "Load more" while the store has more.
class StockBalanceTable extends StatelessWidget {
  const StockBalanceTable({
    required this.stockProvider,
    required this.stores,
    required this.onOpen,
    this.onReceive,
    super.key,
  });

  final StockProvider stockProvider;

  /// Active stores offered by the toolbar's store filter.
  final List<InventoryStore> stores;
  final void Function(InventoryBalance balance) onOpen;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final store = stockProvider.store;
    String unit(InventoryBalance balance) =>
        stockProvider.items[balance.itemId]?.stockUnit ?? '';
    final receiveAction = onReceive == null
        ? null
        : IcueTableAction(
            label: 'Receive stock',
            icon: Icons.add_rounded,
            onPressed: onReceive,
          );

    return IcueClientTable<InventoryBalance>(
      title: 'Store stock',
      items: stockProvider.balances,
      rowKey: (balance) => balance.id,
      rowLabel: (balance) => stockProvider.itemName(balance.itemId),
      status: IcueTableStatus.of(
        failed:
            stockProvider.errorMessage != null &&
            stockProvider.balances.isEmpty,
        loading: stockProvider.isLoading && stockProvider.balances.isEmpty,
      ),
      errorMessage: stockProvider.errorMessage,
      onRetry: store == null ? null : () => stockProvider.loadBalances(store),
      initialPageSize: 25,
      searchHint: 'Search item, code or batch...',
      searchText: (balance) =>
          '${stockProvider.itemName(balance.itemId)} '
          '${stockProvider.items[balance.itemId]?.code ?? ''} '
          '${balance.batchNumber ?? ''}',
      externalFilters: [
        IcueTableFilter(
          id: 'store',
          label: 'Store',
          allowAll: false,
          options: [
            for (final store in stores)
              IcueTableFilterOption(store.id, store.name),
          ],
          value: store?.id,
          onChanged: (id) {
            final picked = stores.where((store) => store.id == id).firstOrNull;
            if (picked != null) stockProvider.loadBalances(picked);
          },
        ),
      ],
      filters: [
        IcueClientFilter(
          id: 'level',
          label: 'Level',
          options: const [IcueTableFilterOption('low', 'Low stock')],
          matches: (balance, _) => balance.isBelowReorderLevel,
        ),
      ],
      onRowTap: onOpen,
      primaryAction: receiveAction,
      secondaryAction: stockProvider.hasMoreBalances && store != null
          ? IcueTableAction(
              label: 'Load more',
              icon: Icons.expand_more_rounded,
              onPressed: () => stockProvider.loadBalances(store, more: true),
            )
          : null,
      emptyTitle: store == null
          ? 'No store selected'
          : 'No stock in this store',
      emptyMessage: store == null
          ? 'Pick a store from the Store filter to view its balances.'
          : 'Receive items or transfer stock into this store to see balances.',
      emptyAction: store == null ? null : receiveAction,
      columns: [
        IcueTableColumn(
          id: 'item',
          label: 'Item',
          flex: 3,
          minWidth: 200,
          hideable: false,
          sortable: true,
          comparator: (balance) =>
              stockProvider.itemName(balance.itemId).toLowerCase(),
          cellBuilder: (context, balance) => IcueTableCellText(
            stockProvider.itemName(balance.itemId),
            subtitle: balance.batchNumber == null
                ? null
                : 'Batch ${balance.batchNumber}',
          ),
        ),
        IcueTableColumn(
          id: 'code',
          label: 'Code',
          cellBuilder: (context, balance) => IcueTableCellText(
            stockProvider.items[balance.itemId]?.code ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'available',
          label: 'Available',
          alignment: Alignment.centerRight,
          sortable: true,
          comparator: (balance) => balance.available,
          cellBuilder: (context, balance) => IcueTableCellText(
            '${balance.available.toQuantityText()} ${unit(balance)}',
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'damaged',
          label: 'Damaged',
          alignment: Alignment.centerRight,
          hideBelowWidth: 900,
          cellBuilder: (context, balance) => IcueTableCellText(
            balance.damaged.toQuantityText(),
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'expired',
          label: 'Expired',
          alignment: Alignment.centerRight,
          hideBelowWidth: 900,
          cellBuilder: (context, balance) => IcueTableCellText(
            balance.expired.toQuantityText(),
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'value',
          label: 'Value',
          alignment: Alignment.centerRight,
          sortable: true,
          comparator: (balance) => balance.value,
          cellBuilder: (context, balance) => IcueTableCellText(
            balance.value.toRupees(),
            style: IcueTableStyle.of(context).numeric,
          ),
        ),
        IcueTableColumn(
          id: 'level',
          label: 'Level',
          cellBuilder: (context, balance) => balance.isBelowReorderLevel
              ? IcueTableCellText(
                  'Low stock',
                  style: IcueTableStyle.of(context).secondary
                      .copyWith(color: Theme.of(context).colorScheme.error),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
