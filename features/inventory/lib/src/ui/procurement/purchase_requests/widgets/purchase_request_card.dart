import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

class PurchaseRequestCard extends StatelessWidget {
  const PurchaseRequestCard({
    required this.request,
    required this.getItemName,
    this.nextAction,
    this.onTap,
    super.key,
  });

  final InventoryPurchaseRequest request;
  final String Function(String itemId) getItemName;
  final String? nextAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusConfig = _getStatusConfig(request.status);
    final priorityConfig = _getPriorityConfig(request.priority);

    final totalOrdered = request.lineItems.fold<double>(
      0,
      (sum, line) => sum + line.quantityOrdered,
    );
    final totalRequested = request.lineItems.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );

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
              // Header: PR number, Status & Priority
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          request.number.isEmpty
                              ? 'Purchase Request'
                              : request.number,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBadge(priorityConfig),
                  const SizedBox(width: 6),
                  _buildBadge(statusConfig),
                ],
              ),
              const SizedBox(height: 8),

              // Purpose & Required Date
              Text(
                request.purpose,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Needed by ${request.requiredDate.toDisplayDay()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Line Items Preview
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in request.lineItems.take(2))
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
                    if (request.lineItems.length > 2)
                      Text(
                        '+ ${request.lineItems.length - 2} more items',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Footer: Total Est. Amount & Ordering Progress
              Row(
                children: [
                  Text(
                    'Estimated: ${request.total.toRupees()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (totalOrdered > 0)
                    Text(
                      'Ordered ${totalOrdered.toQuantityText()} / ${totalRequested.toQuantityText()}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(_BadgeConfig config) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: config.background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      config.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: config.foreground,
      ),
    ),
  );

  _BadgeConfig _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return _BadgeConfig(
          label: 'Pending',
          foreground: Colors.amber[900]!,
          background: Colors.amber.withValues(alpha: 0.15),
        );
      case 'approved':
        return _BadgeConfig(
          label: 'Approved',
          foreground: Colors.green[800]!,
          background: Colors.green.withValues(alpha: 0.15),
        );
      case 'partially_ordered':
        return _BadgeConfig(
          label: 'Partially Ordered',
          foreground: Colors.purple[800]!,
          background: Colors.purple.withValues(alpha: 0.15),
        );
      case 'ordered':
        return _BadgeConfig(
          label: 'Ordered',
          foreground: Colors.blue[800]!,
          background: Colors.blue.withValues(alpha: 0.15),
        );
      case 'revision_requested':
        return _BadgeConfig(
          label: 'Returned',
          foreground: Colors.orange[900]!,
          background: Colors.orange.withValues(alpha: 0.15),
        );
      case 'rejected':
        return _BadgeConfig(
          label: 'Rejected',
          foreground: Colors.red[800]!,
          background: Colors.red.withValues(alpha: 0.15),
        );
      case 'draft':
        return _BadgeConfig(
          label: 'Draft',
          foreground: Colors.blueGrey[800]!,
          background: Colors.blueGrey.withValues(alpha: 0.15),
        );
      case 'cancelled':
        return _BadgeConfig(
          label: 'Cancelled',
          foreground: Colors.grey[700]!,
          background: Colors.grey.withValues(alpha: 0.15),
        );
      default:
        return _BadgeConfig(
          label: humanizeStatus(status),
          foreground: Colors.grey[800]!,
          background: Colors.grey.withValues(alpha: 0.15),
        );
    }
  }

  _BadgeConfig _getPriorityConfig(String priority) {
    switch (priority) {
      case 'urgent':
        return _BadgeConfig(
          label: 'Urgent',
          foreground: Colors.red[900]!,
          background: Colors.red.withValues(alpha: 0.15),
        );
      case 'high':
        return _BadgeConfig(
          label: 'High',
          foreground: Colors.deepOrange[800]!,
          background: Colors.deepOrange.withValues(alpha: 0.15),
        );
      case 'low':
        return _BadgeConfig(
          label: 'Low',
          foreground: Colors.grey[700]!,
          background: Colors.grey.withValues(alpha: 0.12),
        );
      default:
        return _BadgeConfig(
          label: 'Normal',
          foreground: Colors.blue[800]!,
          background: Colors.blue.withValues(alpha: 0.12),
        );
    }
  }
}

class _BadgeConfig {
  const _BadgeConfig({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}
