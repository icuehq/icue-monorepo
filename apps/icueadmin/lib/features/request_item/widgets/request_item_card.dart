import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Card displaying an inventory item in the catalog with store, category, and add action.
class RequestItemCard extends StatelessWidget {
  const RequestItemCard({
    required this.item,
    required this.storeName,
    required this.categoryName,
    required this.onAdd,
    this.isSelected = false,
    this.selectedQuantity,
    super.key,
  });

  final InventoryItem item;
  final String storeName;
  final String categoryName;
  final bool isSelected;
  final double? selectedQuantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.description != null &&
                  item.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.description!.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (storeName.isNotEmpty)
                    _MetadataChip(
                      icon: Icons.storefront_outlined,
                      label: storeName,
                    ),
                  if (categoryName.isNotEmpty)
                    _MetadataChip(
                      icon: Icons.category_outlined,
                      label: categoryName,
                    ),
                  _MetadataChip(
                    icon: Icons.scale_outlined,
                    label: item.stockUnit,
                  ),
                  if (item.tracking != Tracking.quantity)
                    IcueStatusPill(
                      label: item.tracking.label,
                      color: Colors.deepPurple,
                      compact: true,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selectedQuantity != null
                                ? 'In request: ${selectedQuantity == selectedQuantity!.toInt() ? selectedQuantity!.toInt() : selectedQuantity} ${item.stockUnit}'
                                : 'In request',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  IcueButton(
                    label: isSelected ? 'Add More' : 'Add',
                    size: IcueButtonSize.small,
                    variant: isSelected
                        ? IcueButtonVariant.outline
                        : IcueButtonVariant.primary,
                    leadingIcon: Icons.add_rounded,
                    onPressed: onAdd,
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

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurface),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
