import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

class ItemDetailsPage extends StatefulWidget {
  const ItemDetailsPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  InventoryItem? _item;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inventoryProvider = context.read<InventoryProvider>();
    final item = await inventoryProvider.item(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      _loaded = true;
    });
  }

  IconData _trackingIcon(Tracking tracking) => switch (tracking) {
    Tracking.asset => Icons.devices_other_outlined,
    Tracking.batch => Icons.medication_outlined,
    Tracking.quantity => Icons.inventory_2_outlined,
  };

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? helper,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (helper != null) ...[
                const SizedBox(height: 1),
                Text(
                  helper,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final theme = Theme.of(context);
    final item = _item;
    final canEdit = inventoryProvider.access.can('inventory.items.manage');

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
      body: CenteredBody(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Hero Header Card
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
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.active
                                ? theme.colorScheme.primaryContainer.withValues(
                                    alpha: 0.6,
                                  )
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _trackingIcon(item.tracking),
                            size: 26,
                            color: item.active
                                ? theme.colorScheme.primary
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.qr_code_2_outlined,
                                          size: 14,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.code,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'monospace',
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.active
                                          ? theme.colorScheme.primaryContainer
                                                .withValues(alpha: 0.5)
                                          : theme.colorScheme.errorContainer
                                                .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.active ? 'Active' : 'Inactive',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: item.active
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        value: item.active,
                        onChanged: (value) async {
                          if (await inventoryProvider.setItemActive(
                            item.id,
                            active: value,
                          )) {
                            await _load();
                          } else if (context.mounted) {
                            showMessage(
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

            // Classification & Units Section
            FormSectionCard(
              title: 'Classification & units',
              icon: Icons.category_outlined,
              children: [
                _infoRow(
                  context,
                  icon: Icons.folder_outlined,
                  label: 'Category',
                  value: category?.name ?? '—',
                  helper: subcategory != null
                      ? 'Sub: ${subcategory.name}'
                      : null,
                ),
                _infoRow(
                  context,
                  icon: Icons.straighten_outlined,
                  label: 'Stock unit',
                  value: item.stockUnit,
                  helper: 'Base unit used for physical inventory and balances',
                ),
                _infoRow(
                  context,
                  icon: Icons.track_changes_outlined,
                  label: 'Tracking method',
                  value: item.tracking.label,
                  helper: switch (item.tracking) {
                    Tracking.quantity =>
                      'Tracked in bulk quantities without serialization',
                    Tracking.batch =>
                      'Tracked with batch numbers and expiration dates',
                    Tracking.asset =>
                      'Tracked as individual serialized capital assets',
                  },
                ),
              ],
            ),

            // Stock & Pricing Controls
            FormSectionCard(
              title: 'Stock & pricing parameters',
              icon: Icons.tune_outlined,
              children: [
                _infoRow(
                  context,
                  icon: Icons.refresh_outlined,
                  label: 'Reorder alert level',
                  value: reorder != null
                      ? '${reorder % 1 == 0 ? reorder.toInt() : reorder} ${item.stockUnit}'
                      : 'Not configured',
                  helper: reorder != null
                      ? 'Triggers restock alert when available stock is low'
                      : 'Configure in edit item to enable low-stock alerts',
                ),
                _infoRow(
                  context,
                  icon: Icons.payments_outlined,
                  label: 'Default purchase price',
                  value: price != null
                      ? '${price.toRupees()} / ${item.stockUnit}'
                      : 'Not configured',
                  helper: 'Estimated unit cost auto-filled on purchase requisitions',
                ),
              ],
            ),

            // Description Section (if available)
            if (item.description != null && item.description!.trim().isNotEmpty)
              FormSectionCard(
                title: 'Description & specifications',
                icon: Icons.notes_outlined,
                children: [
                  Text(
                    item.description!.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 8),

            // Action Buttons
            AppButton(
              label: 'View stock levels in stores',
              onPressed: () => context.push(InventoryRoutes.inventoryStock),
              variant: AppButtonVariant.outline,
              leadingIcon: Icons.stacked_bar_chart_outlined,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
