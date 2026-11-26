import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';

class PurchaseRequestCard extends StatelessWidget {
  const PurchaseRequestCard({
    required this.request,
    required this.getItemName,
    this.storeName,
    this.onTap,
    super.key,
  });

  final InventoryPurchaseRequest request;
  final String Function(String itemId) getItemName;
  final String? storeName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusConfig = _getStatusConfig(request.status);
    final priorityConfig = _getPriorityConfig(request.priority);

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
                    [
                      ?storeName,
                      'Needed by ${request.requiredDate.toDisplayDay()}',
                    ].join(' · '),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(_BadgeConfig config) => IcueStatusPill(
    label: config.label,
    color: config.foreground,
    background: config.background,
    bordered: false,
  );

  _BadgeConfig _getStatusConfig(String status) {
    final color = inventoryStatusColor(status);
    return _BadgeConfig(
      label: inventoryStatusLabel(status),
      foreground: color,
      background: color.withValues(alpha: 0.15),
    );
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
