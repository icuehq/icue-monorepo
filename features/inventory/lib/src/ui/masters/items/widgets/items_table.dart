import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Wide-screen item catalogue: an [IcueTable] fed by the provider's server-side
/// search, category filter and cursor paging; it fetches the next batch when the
/// user pages past the items loaded so far.
class ItemsTable extends StatefulWidget {
  const ItemsTable({
    required this.canEdit,
    required this.onToggleActive,
    super.key,
  });

  final bool canEdit;
  final void Function(InventoryItem item) onToggleActive;

  @override
  State<ItemsTable> createState() => _ItemsTableState();
}

class _ItemsTableState extends State<ItemsTable> {
  int _pageSize = 25;
  int _page = 0;

  void _addItem() => context.push(InventoryRoutes.inventoryItemForm);

  void _editItem(InventoryItem item) =>
      context.push(InventoryRoutes.inventoryItemForm, extra: item);

  void _openItem(InventoryItem item) =>
      context.push('${InventoryRoutes.inventoryItemDetails}?id=${item.id}');

  Future<void> _next(InventoryProvider provider) async {
    final needsMore = (_page + 1) * _pageSize >= provider.items.length;
    if (needsMore) await provider.loadItems(more: true);
    if (!mounted) return;
    if ((_page + 1) * _pageSize < provider.items.length) {
      setState(() => _page++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final items = provider.items;
    final search = provider.itemSearch.trim();
    final categoryId = provider.itemCategoryId;
    final storeId = provider.itemStoreId;
    final pageCount = (items.length / _pageSize).ceil();
    final page = pageCount == 0 ? 0 : _page.clamp(0, pageCount - 1);
    final rows = items.skip(page * _pageSize).take(_pageSize).toList();

    return IcueTable<InventoryItem>(
      title: 'Item catalogue',
      rows: rows,
      rowKey: (item) => item.id,
      rowLabel: (item) => item.name,
      status: IcueTableStatus.of(
        failed: provider.errorMessage != null && items.isEmpty,
        loading: provider.itemsLoading && items.isEmpty,
      ),
      errorMessage: provider.errorMessage,
      onRetry: () => provider.loadItems(storeId: storeId),
      searchHint: 'Search by item name...',
      initialSearch: provider.itemSearch,
      onSearchChanged: (query) {
        setState(() => _page = 0);
        provider.loadItems(search: query, storeId: storeId);
      },
      filters: [
        IcueTableFilter(
          id: 'category',
          label: 'Category',
          options: [
            for (final category in provider.topCategories)
              IcueTableFilterOption(category.id, category.name),
          ],
          value: categoryId,
          onChanged: (value) {
            setState(() => _page = 0);
            provider.loadItems(
              categoryId: value,
              clearCategory: value == null,
              storeId: storeId,
            );
          },
        ),
        if (provider.showStoreFilter)
          IcueTableFilter(
            id: 'store',
            label: 'Store',
            options: [
              for (final store in provider.stores)
                IcueTableFilterOption(store.id, store.name),
            ],
            value: storeId,
            onChanged: (value) {
              setState(() => _page = 0);
              provider.loadItems(storeId: value);
            },
          ),
      ],
      isFiltered: search.isNotEmpty || categoryId != null || storeId != null,
      onClearFilters: () {
        setState(() => _page = 0);
        provider.loadItems(search: '', clearCategory: true);
      },
      onRowTap: _openItem,
      primaryAction: widget.canEdit
          ? IcueTableAction(
              label: 'Item',
              icon: Icons.add_rounded,
              onPressed: _addItem,
            )
          : null,
      emptyTitle: 'No items in catalogue',
      emptyMessage: 'Add your first inventory item to begin tracking stock.',
      emptyAction: widget.canEdit
          ? IcueTableAction(
              label: 'Add item',
              icon: Icons.add_rounded,
              onPressed: _addItem,
            )
          : null,
      rowActions: (item) => widget.canEdit
          ? [
              IcueTableRowAction(
                label: 'Edit',
                icon: Icons.edit_outlined,
                inline: true,
                onPressed: _editItem,
              ),
              IcueTableRowAction(
                label: item.active ? 'Deactivate' : 'Activate',
                icon: item.active
                    ? Icons.block_outlined
                    : Icons.check_circle_outline_rounded,
                inline: true,
                onPressed: widget.onToggleActive,
              ),
            ]
          : const [],
      pagination: IcueTablePagination(
        pageIndex: page,
        pageSize: _pageSize,
        itemCount: rows.length,
        hasPrevious: page > 0,
        hasNext: (page + 1) * _pageSize < items.length || provider.hasMoreItems,
        isLoading: provider.itemsLoading,
        onPrevious: () => setState(() => _page = page - 1),
        onNext: () => _next(provider),
        onPageSizeChanged: (size) => setState(() {
          _pageSize = size;
          _page = 0;
        }),
      ),
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Item',
          flex: 3,
          minWidth: 200,
          hideable: false,
          cellBuilder: (context, item) => IcueTableCellText(
            item.name,
            leading: item.active ? null : const IcueInactiveBadge(),
          ),
        ),
        IcueTableColumn(
          id: 'category',
          label: 'Category',
          flex: 2,
          cellBuilder: (context, item) => IcueTableCellText(
            provider.category(item.categoryId)?.name ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'store',
          label: 'Store',
          cellBuilder: (context, item) => IcueTableCellText(
            provider.storeName(item.storeId) ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'unit',
          label: 'Unit',
          cellBuilder: (context, item) => IcueTableCellText(
            item.stockUnit,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'inStock',
          label: 'In stock',
          cellBuilder: (context, item) {
            final count = provider.inStock[item.id];
            if (count == null) {
              return IcueTableCellText(
                '—',
                style: IcueTableStyle.of(context).secondary,
              );
            }
            final low =
                item.reorderLevel != null && count <= item.reorderLevel!;
            return IcueTableCellText(
              '${count.toQuantityText()} ${item.stockUnit}',
              style: low
                  ? IcueTableStyle.of(context).secondary.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            );
          },
        ),
        IcueTableColumn(
          id: 'tracking',
          label: 'Item type',
          hideBelowWidth: 900,
          cellBuilder: (context, item) => IcueTableCellText(
            item.tracking.label,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
      ],
    );
  }
}
