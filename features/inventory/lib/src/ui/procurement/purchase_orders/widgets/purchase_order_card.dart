import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

class PurchaseOrderCard extends StatelessWidget {
  const PurchaseOrderCard({
    required this.order,
    required this.vendorName,
    this.onTap,
    super.key,
  });

  final InventoryPurchaseOrder order;
  final String vendorName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusConfig = _getStatusConfig(order.status);

    final totalOrdered = order.lineItems.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );
    final totalAccepted = order.lineItems.fold<double>(
      0,
      (sum, line) => sum + line.quantityAccepted,
    );
    final totalRejected = order.lineItems.fold<double>(
      0,
      (sum, line) => sum + line.quantityRejected,
    );

    final progress = totalOrdered > 0
        ? (totalAccepted / totalOrdered).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: PO Number, Revision, Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              order.number.isEmpty
                                  ? 'Purchase Order'
                                  : order.number,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (order.revision > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Rev ${order.revision}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vendorName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      color: statusConfig.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusConfig.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusConfig.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Campus and Delivery Date
              Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Campus ${order.deliveryCampusId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${order.expectedDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Receiving Progress Bar (if not draft/cancelled)
              if (!order.isDraft && order.status != 'cancelled') ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? Colors.green : Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(progress * 100).toInt()}% received',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Footer: Total & Item Details
              Row(
                children: [
                  Text(
                    'Total: ₹${formatQuantity(order.total)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${order.lineItems.length} items (${formatQuantity(totalAccepted)} / ${formatQuantity(totalOrdered)} rec\'d)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (totalRejected > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '(${formatQuantity(totalRejected)} rej)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'issued':
        return _StatusConfig(
          label: 'Issued',
          foreground: Colors.blue[800]!,
          background: Colors.blue.withValues(alpha: 0.15),
        );
      case 'acknowledged':
        return _StatusConfig(
          label: 'Acknowledged',
          foreground: Colors.teal[800]!,
          background: Colors.teal.withValues(alpha: 0.15),
        );
      case 'partially_received':
        return _StatusConfig(
          label: 'Partially Received',
          foreground: Colors.purple[800]!,
          background: Colors.purple.withValues(alpha: 0.15),
        );
      case 'fully_received':
        return _StatusConfig(
          label: 'Fully Received',
          foreground: Colors.green[800]!,
          background: Colors.green.withValues(alpha: 0.15),
        );
      case 'closed':
        return _StatusConfig(
          label: 'Closed',
          foreground: Colors.blueGrey[800]!,
          background: Colors.blueGrey.withValues(alpha: 0.15),
        );
      case 'cancelled':
        return _StatusConfig(
          label: 'Cancelled',
          foreground: Colors.red[800]!,
          background: Colors.red.withValues(alpha: 0.15),
        );
      case 'draft':
        return _StatusConfig(
          label: 'Draft',
          foreground: Colors.amber[900]!,
          background: Colors.amber.withValues(alpha: 0.15),
        );
      default:
        return _StatusConfig(
          label: humanizeStatus(status),
          foreground: Colors.grey[800]!,
          background: Colors.grey.withValues(alpha: 0.15),
        );
    }
  }
}

class _StatusConfig {
  const _StatusConfig({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}
