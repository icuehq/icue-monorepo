import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

Widget _itemMetaPill(BuildContext context, IconData icon, String text) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.categoryName,
    required this.canEdit,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
  });

  final InventoryItem item;
  final String? categoryName;
  final bool canEdit;
  final VoidCallback onTap;
  final ValueChanged<InventoryItem> onEdit;
  final ValueChanged<InventoryItem> onToggleActive;

  IconData get _trackingIcon => switch (item.tracking) {
    Tracking.asset => Icons.devices_other_outlined,
    Tracking.batch => Icons.medication_outlined,
    Tracking.quantity => Icons.inventory_2_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reorder = item.reorderLevel;
    final price = item.defaultPrice;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.active
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.6,
                            )
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _trackingIcon,
                      color: item.active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!item.active) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Inactive',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (item.description != null &&
                            item.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit(item);
                        } else if (value == 'toggle') {
                          onToggleActive(item);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(
                                item.active
                                    ? Icons.block_outlined
                                    : Icons.check_circle_outline,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(item.active ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (categoryName != null)
                    _itemMetaPill(
                      context,
                      Icons.category_outlined,
                      categoryName!,
                    ),
                  _itemMetaPill(
                    context,
                    Icons.straighten_outlined,
                    item.stockUnit,
                  ),
                  _itemMetaPill(
                    context,
                    Icons.track_changes_outlined,
                    item.tracking.label,
                  ),
                  if (reorder != null)
                    _itemMetaPill(
                      context,
                      Icons.refresh_outlined,
                      'Reorder: ${reorder % 1 == 0 ? reorder.toInt() : reorder}',
                    ),
                  if (price != null)
                    _itemMetaPill(
                      context,
                      Icons.payments_outlined,
                      'Price: ${price % 1 == 0 ? price.toInt() : price}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
