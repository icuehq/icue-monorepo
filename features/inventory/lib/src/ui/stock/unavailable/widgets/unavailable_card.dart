import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Phone card of one damaged / expired record; a record the user may resolve opens the resolve screen.
class UnavailableCard extends StatelessWidget {
  const UnavailableCard({
    required this.item,
    required this.itemName,
    required this.storeName,
    required this.canOperate,
    required this.onResolve,
    super.key,
  });

  final InventoryUnavailable item;
  final String Function(String itemId) itemName;
  final String Function(String storeId) storeName;
  final bool canOperate;
  final void Function(InventoryUnavailable record) onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResolve = canOperate && item.status != 'resolved';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.status == 'open'
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: canResolve ? () => onResolve(item) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          itemName(item.itemId),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Store: ${storeName(item.storeId)}${item.batchNumber == null ? '' : ' · Batch ${item.batchNumber}'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.quantity.toQuantityText()} units',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _bucketBadge(item.bucket ?? item.reason),
                  const SizedBox(width: 8),
                  _statusBadge(item.status, item.resolution),
                  const Spacer(),
                  if (item.createdAt != null)
                    Text(
                      item.createdAt!.toNumericDate(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.remarks!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (canResolve) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to resolve',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bucketBadge(String bucket) {
    final isDamaged = bucket.toLowerCase().contains('damage');
    final isExpired = bucket.toLowerCase().contains('expire');
    final color = isDamaged
        ? Colors.red[800]!
        : isExpired
        ? Colors.amber[900]!
        : Colors.blueGrey[800]!;
    final backgroundColor = isDamaged
        ? Colors.red.withValues(alpha: 0.12)
        : isExpired
        ? Colors.amber.withValues(alpha: 0.12)
        : Colors.blueGrey.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        humanizeStatus(bucket),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _statusBadge(String status, String? resolution) {
    final text = resolution != null
        ? '${humanizeStatus(status)}: ${humanizeStatus(resolution)}'
        : humanizeStatus(status);
    final isResolved = status == 'resolved';
    final isInRepair = status == 'in_repair';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isResolved
            ? Colors.green.withValues(alpha: 0.12)
            : isInRepair
            ? Colors.blue.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isResolved
              ? Colors.green[800]
              : isInRepair
              ? Colors.blue[800]
              : Colors.orange[900],
        ),
      ),
    );
  }
}
