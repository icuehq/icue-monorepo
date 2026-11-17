import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:icueadmin/features/request_item/models/request_item_line.dart';

/// Card showing one selected item in the request summary panel, with a quantity stepper and remove button.
class RequestSelectedItemCard extends StatelessWidget {
  const RequestSelectedItemCard({
    required this.line,
    required this.storeName,
    required this.onRemove,
    this.onQuantityChanged,
    super.key,
  });

  final RequestItemLine line;
  final String storeName;
  final VoidCallback onRemove;
  final VoidCallback? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variantText = line.variant?.attrs.values.isEmpty ?? true
        ? line.variant?.sku
        : line.variant?.attrs.values.join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.item.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (storeName.isNotEmpty)
                          Text(
                            storeName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (variantText != null && variantText.isNotEmpty)
                          IcueStatusPill(
                            label: variantText,
                            color: theme.colorScheme.primary,
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Unit: ${line.item.stockUnit}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      line.decrement();
                      onQuantityChanged?.call();
                    },
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 58,
                    height: 34,
                    child: TextField(
                      controller: line.quantityController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [decimalInputFormatter],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) => onQuantityChanged?.call(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _StepperButton(
                    icon: Icons.add_rounded,
                    onPressed: () {
                      line.increment();
                      onQuantityChanged?.call();
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.onSurface),
      ),
    );
  }
}
