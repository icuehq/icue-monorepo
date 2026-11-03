import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

Widget _pill(
  BuildContext context, {
  required IconData icon,
  required String label,
  Color? color,
  Color? backgroundColor,
}) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:
          backgroundColor ??
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color ?? theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class StockBalanceCard extends StatelessWidget {
  const StockBalanceCard({
    super.key,
    required this.balance,
    required this.itemName,
    this.itemCode,
    this.stockUnit,
    this.reorderLevel,
    required this.onTap,
  });

  final InventoryBalance balance;
  final String itemName;
  final String? itemCode;
  final String? stockUnit;
  final double? reorderLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = stockUnit ?? '';
    final hasBatch = balance.batchNumber != null || balance.expiryDate != null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: balance.isBelowReorderLevel
              ? Colors.orange.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: balance.isBelowReorderLevel
                          ? Colors.orange.withValues(alpha: 0.15)
                          : theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.6,
                            ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      balance.isBelowReorderLevel
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2_outlined,
                      color: balance.isBelowReorderLevel
                          ? Colors.orange.shade800
                          : theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (itemCode != null)
                              Text(
                                itemCode!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (hasBatch) ...[
                              if (itemCode != null)
                                Text(
                                  ' · ',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (balance.batchNumber != null)
                                Text(
                                  'Batch ${balance.batchNumber}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (balance.expiryDate != null)
                                Text(
                                  ' (exp ${balance.expiryDate})',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatQuantity(balance.available)} $unit',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: balance.available == 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'available',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                  if (balance.isBelowReorderLevel)
                    _pill(
                      context,
                      icon: Icons.warning_amber_rounded,
                      label: reorderLevel != null
                          ? 'Low stock (reorder: ${formatQuantity(reorderLevel!)})'
                          : 'Low stock',
                      color: Colors.orange.shade900,
                      backgroundColor: Colors.orange.withValues(alpha: 0.15),
                    ),
                  _pill(
                    context,
                    icon: Icons.payments_outlined,
                    label: '₹${balance.value.toStringAsFixed(2)}',
                  ),
                  if (balance.issuedTotal > 0)
                    _pill(
                      context,
                      icon: Icons.outbox_outlined,
                      label:
                          '${formatQuantity(balance.issuedTotal)} out with users',
                    ),
                  if (balance.damaged > 0)
                    _pill(
                      context,
                      icon: Icons.broken_image_outlined,
                      label: '${formatQuantity(balance.damaged)} damaged',
                      color: Colors.red.shade800,
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
                    ),
                  if (balance.expired > 0)
                    _pill(
                      context,
                      icon: Icons.event_busy_outlined,
                      label: '${formatQuantity(balance.expired)} expired',
                      color: Colors.red.shade800,
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
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
