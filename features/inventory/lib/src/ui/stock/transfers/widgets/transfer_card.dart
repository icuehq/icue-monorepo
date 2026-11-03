import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

class TransferCard extends StatelessWidget {
  const TransferCard({
    required this.transfer,
    required this.fromStoreName,
    required this.toStoreName,
    required this.getItemName,
    this.nextAction,
    this.onTap,
    super.key,
  });

  final InventoryTransfer transfer;
  final String fromStoreName;
  final String toStoreName;
  final String Function(String itemId) getItemName;
  final String? nextAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusConfig = _getStatusConfig(transfer.status);
    final isCrossCampus = transfer.fromCampusId != transfer.toCampusId;

    // Discrepancy calculation
    final totalDiscrepancy = transfer.lineItems.fold<double>(
      0,
      (sum, line) => sum + line.discrepancy,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: totalDiscrepancy > 0
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Number, Date, Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer.number.isEmpty
                              ? 'Transfer'
                              : transfer.number,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (transfer.createdAt != null)
                          Text(
                            transfer.createdAt!.toNumericDate(),
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
                      color: statusConfig.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusConfig.icon,
                          size: 14,
                          color: statusConfig.foreground,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusConfig.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusConfig.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Route Display: From Store -> To Store
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fromStoreName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      Icons.warehouse_outlined,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        toStoreName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCrossCampus) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Inter-campus',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Items summary
              if (transfer.preDispatch) ...[
                for (final line in transfer.requested.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            getItemName(line.itemId),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '× ${line.quantity.toQuantityText()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (transfer.requested.length > 3)
                  Text(
                    '+ ${transfer.requested.length - 3} more items',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ] else ...[
                for (final line in transfer.lineItems.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: line.discrepancy > 0
                                ? theme.colorScheme.error
                                : theme.colorScheme.outline,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${getItemName(line.itemId)}${line.batchNumber == null ? '' : ' (${line.batchNumber})'}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${line.received.toQuantityText()} / ${line.dispatched.toQuantityText()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (line.discrepancy > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '(-${line.discrepancy.toQuantityText()})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (transfer.lineItems.length > 3)
                  Text(
                    '+ ${transfer.lineItems.length - 3} more items',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],

              if (nextAction != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      nextAction!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],

              // Shortfall warning banner if discrepancy exists
              if (totalDiscrepancy > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Shortfall of ${totalDiscrepancy.toQuantityText()} units recorded on receipt',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'requested':
        return _StatusConfig(
          label: 'Requested',
          icon: Icons.pending_actions_rounded,
          foreground: Colors.amber[900]!,
          background: Colors.amber.withValues(alpha: 0.15),
        );
      case 'approved':
        return _StatusConfig(
          label: 'Approved',
          icon: Icons.thumb_up_alt_outlined,
          foreground: Colors.teal[800]!,
          background: Colors.teal.withValues(alpha: 0.15),
        );
      case 'dispatched':
        return _StatusConfig(
          label: 'In Transit',
          icon: Icons.local_shipping_outlined,
          foreground: Colors.blue[800]!,
          background: Colors.blue.withValues(alpha: 0.15),
        );
      case 'partially_received':
        return _StatusConfig(
          label: 'Partially Received',
          icon: Icons.call_split_rounded,
          foreground: Colors.purple[800]!,
          background: Colors.purple.withValues(alpha: 0.15),
        );
      case 'received':
        return _StatusConfig(
          label: 'Received',
          icon: Icons.check_circle_outline_rounded,
          foreground: Colors.green[800]!,
          background: Colors.green.withValues(alpha: 0.15),
        );
      default:
        return _StatusConfig(
          label: humanizeStatus(status),
          icon: Icons.help_outline_rounded,
          foreground: Colors.grey[800]!,
          background: Colors.grey.withValues(alpha: 0.15),
        );
    }
  }
}

class _StatusConfig {
  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
}
