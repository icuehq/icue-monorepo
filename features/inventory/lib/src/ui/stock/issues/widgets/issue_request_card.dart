import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';

IconData _statusIcon(String status) => switch (status) {
  'approved' => Icons.check_circle_outline,
  'partially_issued' => Icons.timelapse_outlined,
  'issued' => Icons.done_all_rounded,
  'rejected' => Icons.cancel_outlined,
  'cancelled' || 'closed' => Icons.block_outlined,
  _ => Icons.hourglass_top_rounded,
};

class IssueRequestCard extends StatelessWidget {
  const IssueRequestCard({
    super.key,
    required this.request,
    required this.storeName,
    required this.itemName,
    required this.onTap,
  });

  final InventoryIssueRequest request;
  final String storeName;
  final String Function(String itemId) itemName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = inventoryStatusColor(request.status);
    final statusBg = inventoryStatusColor(request.status)
        .withValues(alpha: 0.12);
    final itemsCount = request.lineItems.length;
    final primaryTitle = request.lineItems.isEmpty
        ? (request.purpose.isNotEmpty ? request.purpose : 'Issue Request')
        : itemName(request.lineItems.first.itemId);
    final extraItemsText = itemsCount > 1 ? ' (+${itemsCount - 1} more)' : '';

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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _statusIcon(request.status),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                                    '$primaryTitle$extraItemsText',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (request.purpose.isNotEmpty &&
                                      request.lineItems.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      request.purpose,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                humanizeStatus(request.status),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (request.destination != null &&
                            request.destination!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  request.destination!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var i = 0;
                      i < (itemsCount > 3 ? 3 : itemsCount);
                      i++
                    ) ...[
                      if (i > 0) const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              itemName(request.lineItems[i].itemId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '× ${request.lineItems[i].requested.toQuantityText()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (itemsCount > 3) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+ ${itemsCount - 3} more item${itemsCount - 3 == 1 ? '' : 's'}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (request.createdAt != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.createdAt!.toNumericDate(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
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
