import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/items/widgets/item_info_row.dart';
import 'package:inventory/src/ui/masters/items/widgets/item_stat_tile.dart';
import 'package:provider/provider.dart';

class ItemDetailsPage extends StatefulWidget {
  const ItemDetailsPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  InventoryItem? _item;
  List<InventoryVariant> _variants = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    if (inventoryProvider.categories.isEmpty) {
      await inventoryProvider.loadMasters();
    }
    final item = await inventoryProvider.item(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _loaded = true;
    });
    if (item == null) return;
    final variants = await inventoryProvider.variants(item.id);
    await inventoryProvider.loadStockOf(item);
    if (mounted) setState(() => _variants = variants);
  }

  IconData _trackingIcon(Tracking tracking) => switch (tracking) {
    Tracking.asset => Icons.devices_other_outlined,
    Tracking.batch => Icons.medication_outlined,
    Tracking.quantity => Icons.inventory_2_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final theme = Theme.of(context);
    final item = _item;
    const canEdit = true;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item details')),
        body: Center(
          child: _loaded
              ? const Text('Item not found')
              : const CircularProgressIndicator(),
        ),
      );
    }

    final category = inventoryProvider.category(item.categoryId);
    final subcategory = item.subcategoryId != null
        ? inventoryProvider.category(item.subcategoryId!)
        : null;
    final reorder = item.reorderLevel;
    final price = item.defaultPrice;
    final stock = inventoryProvider.inStock[item.id];
    final low = stock != null && reorder != null && stock <= reorder;
    final wide = context.isWide;

    final stats = [
      ItemStatTile(
        label: 'In stock',
        value: stock == null
            ? '—'
            : '${stock.toQuantityText()} ${item.stockUnit}',
        caption: low ? 'Low stock' : null,
        color: low ? theme.colorScheme.error : null,
      ),
      ItemStatTile(
        label: 'Reorder level',
        value: reorder == null
            ? 'Not set'
            : '${reorder.toQuantityText()} ${item.stockUnit}',
      ),
      ItemStatTile(
        label: 'Default price',
        value: price == null ? 'Not set' : price.toRupees(),
        caption: price == null ? null : 'per ${item.stockUnit}',
      ),
    ];

    final details = IcueFormSectionCard(
      title: 'Item details',
      icon: Icons.category_outlined,
      children: [
        ItemInfoRow(
          icon: Icons.store_mall_directory_outlined,
          label: 'Store',
          value: inventoryProvider.storeName(item.storeId) ?? '—',
        ),
        ItemInfoRow(
          icon: Icons.folder_outlined,
          label: 'Category',
          value: category?.name ?? '—',
          helper: subcategory != null ? 'Sub: ${subcategory.name}' : null,
        ),
        ItemInfoRow(
          icon: Icons.straighten_outlined,
          label: 'Stock unit',
          value: item.stockUnit,
        ),
        ItemInfoRow(
          icon: Icons.track_changes_outlined,
          label: 'Item type',
          value: item.tracking.label,
          helper: switch (item.tracking) {
            Tracking.quantity => 'Counted in bulk quantities',
            Tracking.batch => 'Tracked by batch number and expiry date',
            Tracking.asset => 'Tracked as individual assets',
          },
        ),
      ],
    );
    final hasDescription =
        item.description != null && item.description!.trim().isNotEmpty;
    final description = hasDescription
        ? IcueFormSectionCard(
            title: 'Description',
            icon: Icons.notes_outlined,
            children: [
              Text(
                item.description!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          )
        : null;
    final variantList = _variants.isEmpty
        ? null
        : IcueFormSectionCard(
            title: 'Variants (${_variants.length})',
            icon: Icons.style_outlined,
            children: [
              for (final variant in _variants)
                ItemInfoRow(
                  icon: Icons.sell_outlined,
                  label: variant.sku,
                  value: variant.attrs.isEmpty
                      ? '—'
                      : variant.attrs.entries
                            .map((entry) => '${entry.key}: ${entry.value}')
                            .join(', '),
                  helper: variant.active ? null : 'Inactive',
                ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item details'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit item',
              onPressed: () async {
                await context.push(
                  InventoryRoutes.inventoryItemForm,
                  extra: item,
                );
                await _load();
              },
            ),
        ],
      ),
      body: IcueCenteredBody(
        child: ListView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          children: [
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.active
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _trackingIcon(item.tracking),
                            size: 26,
                            color: item.active
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    label: Text(item.tracking.label),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (!item.active) const IcueInactiveBadge(),
                                  if (low)
                                    Chip(
                                      label: const Text('Low stock'),
                                      visualDensity: VisualDensity.compact,
                                      labelStyle: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (canEdit) ...[
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Active in catalog',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item.active
                              ? 'Available for purchase requests and stock issuance'
                              : 'Hidden from new requests and purchases',
                        ),
                        value: item.active,
                        onChanged: (value) async {
                          if (await inventoryProvider.setItemActive(
                            item.id,
                            active: value,
                          )) {
                            await _load();
                          } else if (context.mounted) {
                            IcueToast.error(
                              context,
                              inventoryProvider.errorMessage ?? 'Failed',
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (wide)
              Row(
                children: [
                  for (final tile in stats) ...[
                    Expanded(child: tile),
                    if (tile != stats.last) const SizedBox(width: 12),
                  ],
                ],
              )
            else
              Column(
                children: [
                  for (final tile in stats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(width: double.infinity, child: tile),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            details,
            ?description,
            ?variantList,
            const SizedBox(height: 8),
            Align(
              alignment: wide ? Alignment.centerLeft : Alignment.center,
              child: IcueButton(
                label: 'View stock levels in stores',
                onPressed: () => context.push(InventoryRoutes.inventoryStock),
                variant: IcueButtonVariant.outline,
                leadingIcon: Icons.stacked_bar_chart_outlined,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
