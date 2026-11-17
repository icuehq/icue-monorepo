import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Modal dialog to select a specific variant of an inventory item.
class RequestVariantDialog extends StatefulWidget {
  const RequestVariantDialog({
    required this.item,
    required this.variants,
    super.key,
  });

  final InventoryItem item;
  final List<InventoryVariant> variants;

  static Future<InventoryVariant?> show(
    BuildContext context, {
    required InventoryItem item,
    required List<InventoryVariant> variants,
  }) {
    return showDialog<InventoryVariant>(
      context: context,
      builder: (_) => RequestVariantDialog(item: item, variants: variants),
    );
  }

  @override
  State<RequestVariantDialog> createState() => _RequestVariantDialogState();
}

class _RequestVariantDialogState extends State<RequestVariantDialog> {
  late InventoryVariant _selectedVariant;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.variants.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.style_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Variant',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.item.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.variants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final variant = widget.variants[index];
                    final isSelected = variant.id == _selectedVariant.id;
                    final attributeText = variant.attrs.values.isEmpty
                        ? variant.sku
                        : variant.attrs.values.join(' · ');

                    return InkWell(
                      onTap: () => setState(() => _selectedVariant = variant),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.35,
                                )
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(
                                    alpha: 0.6,
                                  ),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                  width: isSelected ? 5 : 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    attributeText,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (variant.sku.isNotEmpty &&
                                      variant.attrs.values.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'SKU: ${variant.sku}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IcueButton(
                    label: 'Cancel',
                    variant: IcueButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  IcueButton(
                    label: 'Select Variant',
                    leadingIcon: Icons.check_rounded,
                    onPressed: () =>
                        Navigator.of(context).pop(_selectedVariant),
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
