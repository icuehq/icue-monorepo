import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show textSearchSupported;
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Wide-screen stock balances: an [IcueTable] fed by the provider's server-side
/// store and low-stock filters, text search (web only) and cursor paging; it
/// fetches the next batch when the user pages past the balances loaded so far.
class StockBalanceTable extends StatefulWidget {
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
  State<StockBalanceTable> createState() => _StockBalanceTableState();
}

class _StockBalanceTableState extends State<StockBalanceTable> {
  int _pageSize = 25;
  int _page = 0;

  StockProvider get _provider => widget.stockProvider;

  Future<void> _load({InventoryStore? store, String? search, bool? lowOnly}) {
    setState(() => _page = 0);
    return _provider.loadBalances(store, search: search, lowOnly: lowOnly);
  }

  Future<void> _next() async {
    final loaded = _provider.balances.length;
    if ((_page + 1) * _pageSize >= loaded) await _provider.loadMoreBalances();
    if (!mounted) return;
    if ((_page + 1) * _pageSize < _provider.balances.length) {
      setState(() => _page++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = _provider;
    final stores = widget.stores;
    final onReceive = widget.onReceive;
    final store = stockProvider.store;
    final balances = stockProvider.balances;
    final pageCount = (balances.length / _pageSize).ceil();
    final page = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
    final rows = balances.skip(page * _pageSize).take(_pageSize).toList();
    String unit(InventoryBalance balance) =>
        stockProvider.items[balance.itemId]?.stockUnit ?? '';
    final receiveAction = onReceive == null
        ? null
        : IcueTableAction(
            label: 'Receive stock',
            icon: Icons.add_rounded,
            onPressed: onReceive,
          );

    return IcueTable<InventoryBalance>(
      title: 'Store stock',
      rows: rows,
      rowKey: (balance) => balance.id,
      rowLabel: (balance) => stockProvider.itemName(balance.itemId),
      status: IcueTableStatus.of(
        failed: stockProvider.errorMessage != null && balances.isEmpty,
        loading: stockProvider.isLoading && balances.isEmpty,
      ),
      errorMessage: stockProvider.errorMessage,
      onRetry: !stockProvider.balancesLoaded
          ? null
          : () => stockProvider.loadBalances(store),
      searchHint: 'Search by item name...',
      initialSearch: stockProvider.balanceSearch,
      onSearchChanged: textSearchSupported
          ? (query) => _load(store: store, search: query)
          : null,
      filters: [
        IcueTableFilter(
          id: 'store',
          label: 'Store',
          options: [
            for (final store in stores)
              IcueTableFilterOption(store.id, store.name),
          ],
          value: store?.id,
          onChanged: (id) =>
              _load(store: stores.where((store) => store.id == id).firstOrNull),
        ),
        IcueTableFilter(
          id: 'level',
          label: 'Level',
          options: const [IcueTableFilterOption('low', 'Low stock')],
          value: stockProvider.lowOnly ? 'low' : null,
          onChanged: (value) => _load(store: store, lowOnly: value == 'low'),
        ),
      ],
      isFiltered:
          stockProvider.balanceSearch.isNotEmpty || stockProvider.lowOnly,
      onClearFilters: () => _load(store: store, search: '', lowOnly: false),
      onRowTap: widget.onOpen,
      primaryAction: receiveAction,
      emptyTitle: 'No stock found',
      emptyMessage: store == null
          ? 'Receive items to see balances.'
          : 'Receive items into this store to see balances.',
      emptyAction: receiveAction,
      pagination: IcueTablePagination(
        pageIndex: page,
        pageSize: _pageSize,
        itemCount: rows.length,
        hasPrevious: page > 0,
        hasNext:
            (page + 1) * _pageSize < balances.length ||
            stockProvider.hasMoreBalances,
        isLoading: stockProvider.isLoading,
        onPrevious: () => setState(() => _page = page - 1),
        onNext: _next,
        onPageSizeChanged: (size) => setState(() {
          _pageSize = size;
          _page = 0;
        }),
      ),
      columns: [
        IcueTableColumn(
          id: 'item',
          label: 'Item',
          flex: 3,
          minWidth: 200,
          hideable: false,
          cellBuilder: (context, balance) => IcueTableCellText(
            stockProvider.itemName(balance.itemId),
            subtitle: balance.batchNumber == null
                ? null
                : 'Batch ${balance.batchNumber}',
          ),
        ),
        IcueTableColumn(
          id: 'store',
          label: 'Store',
          hideBelowWidth: 900,
          cellBuilder: (context, balance) => IcueTableCellText(
            stores
                    .where((store) => store.id == balance.storeId)
                    .firstOrNull
                    ?.name ??
                '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'available',
          label: 'Available',
          alignment: Alignment.centerRight,
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
