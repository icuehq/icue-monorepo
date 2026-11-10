import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/items/widgets/item_card.dart';
import 'package:inventory/src/ui/masters/items/widgets/items_table.dart';
import 'package:provider/provider.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, this.categoryId});

  final String? categoryId;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final inventoryProvider = context.read<InventoryProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (inventoryProvider.categories.isEmpty) {
        await inventoryProvider.loadMasters();
      }
      await inventoryProvider.loadItems(
        search: '',
        categoryId: widget.categoryId,
        clearCategory: widget.categoryId == null,
      );
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        inventoryProvider.loadItems(more: true);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(InventoryItem item) async {
    final inventoryProvider = context.read<InventoryProvider>();
    final success = await inventoryProvider.setItemActive(
      item.id,
      active: !item.active,
    );
    if (!success && mounted) {
      showMessage(
        context,
        inventoryProvider.errorMessage ?? 'Failed to update item status',
      );
    }
  }

  void _open(InventoryItem item) =>
      context.push('${InventoryRoutes.inventoryItemDetails}?id=${item.id}');

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.items.manage');
    final searching = inventoryProvider.itemSearch.trim().isNotEmpty;
    final selectedCategory = inventoryProvider.itemCategoryId;
    final hasFilter = searching || selectedCategory != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Item Catalog')),
      floatingActionButton: canEdit && !context.isWide
          ? FloatingActionButton.extended(
              onPressed: () => context.push(InventoryRoutes.inventoryItemForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
            )
          : null,
      body: context.isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ItemsTable(
                canEdit: canEdit,
                onToggleActive: _toggleActive,
              ),
            )
          : IcueCenteredBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) =>
                          inventoryProvider.loadItems(search: value),
                      decoration: InputDecoration(
                        hintText: 'Search by item name or code…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: searching
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  inventoryProvider.loadItems(search: '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('All categories'),
                            selected: selectedCategory == null,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => inventoryProvider.loadItems(
                              clearCategory: true,
                            ),
                          ),
                        ),
                        for (final category in inventoryProvider.topCategories)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(category.name),
                              selected: selectedCategory == category.id,
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => inventoryProvider.loadItems(
                                categoryId: category.id,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          inventoryProvider.itemsLoading &&
                                  inventoryProvider.items.isEmpty
                              ? 'Loading items…'
                              : '${inventoryProvider.items.length} item${inventoryProvider.items.length == 1 ? '' : 's'}'
                                    '${hasFilter ? ' found' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hasFilter) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _search.clear();
                              inventoryProvider.loadItems(
                                search: '',
                                clearCategory: true,
                              );
                            },
                            child: Text(
                              'Clear filters',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => inventoryProvider.loadItems(
                        search: _search.text.trim(),
                        categoryId: selectedCategory,
                      ),
                      child: inventoryProvider.items.isEmpty
                          ? Center(
                              child: inventoryProvider.itemsLoading
                                  ? const CircularProgressIndicator()
                                  : SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.inventory_2_outlined,
                                                size: 36,
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              hasFilter
                                                  ? 'No matching items'
                                                  : 'No items in catalog',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              hasFilter
                                                  ? 'Try adjusting your search terms or category filter.'
                                                  : 'Add your first inventory item to begin tracking stock.',
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 18),
                                            if (hasFilter)
                                              IcueButton(
                                                label: 'Reset filters',
                                                onPressed: () {
                                                  _search.clear();
                                                  inventoryProvider.loadItems(
                                                    search: '',
                                                    clearCategory: true,
                                                  );
                                                },
                                                variant:
                                                    IcueButtonVariant.outline,
                                                leadingIcon: Icons
                                                    .filter_alt_off_outlined,
                                              )
                                            else if (canEdit)
                                              IcueButton(
                                                label: 'Add item',
                                                onPressed: () => context.push(
                                                  InventoryRoutes
                                                      .inventoryItemForm,
                                                ),
                                                leadingIcon: Icons.add,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                            )
                          : IcueAdaptiveList<InventoryItem>(
                              controller: _scroll,
                              items: inventoryProvider.items,
                              onTap: _open,
                              columns: [
                                IcueAdaptiveColumn.text(
                                  'Code',
                                  (item) => item.code,
                                ),
                                IcueAdaptiveColumn.text(
                                  'Name',
                                  (item) => item.name,
                                  flex: 3,
                                ),
                                IcueAdaptiveColumn.text(
                                  'Category',
                                  (item) =>
                                      inventoryProvider
                                          .category(item.categoryId)
                                          ?.name ??
                                      '—',
                                  flex: 2,
                                ),
                                IcueAdaptiveColumn.text(
                                  'Unit',
                                  (item) => item.stockUnit,
                                ),
                                IcueAdaptiveColumn.text(
                                  'Tracking',
                                  (item) => item.tracking.label,
                                ),
                                IcueAdaptiveColumn(
                                  label: '',
                                  cell: (context, item) => item.active
                                      ? const SizedBox.shrink()
                                      : const IcueInactiveBadge(),
                                ),
                              ],
                              cardBuilder: (context, item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: ItemCard(
                                  item: item,
                                  categoryName: inventoryProvider
                                      .category(item.categoryId)
                                      ?.name,
                                  canEdit: canEdit,
                                  onTap: () => _open(item),
                                  onEdit: (item) => context.push(
                                    InventoryRoutes.inventoryItemForm,
                                    extra: item,
                                  ),
                                  onToggleActive: _toggleActive,
                                ),
                              ),
                              footer: inventoryProvider.hasMoreItems
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : null,
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
