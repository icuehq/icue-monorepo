import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Card showing one raised issue request with its number, store, status, date, and line items.
class RequestedItemCard extends StatelessWidget {
  const RequestedItemCard({
    required this.request,
    required this.storeName,
    required this.itemName,
    super.key,
  });

  final InventoryIssueRequest request;
  final String storeName;
  final String Function(String itemId) itemName;

  (Color, Color, Color) _statusColors(String status) => switch (status) {
    'approved' => (
      const Color(0xFFE3F2FD),
      const Color(0xFF1565C0),
      const Color(0xFF90CAF9),
    ),
    'issued' => (
      const Color(0xFFE8F5E9),
      const Color(0xFF2E7D32),
      const Color(0xFFA5D6A7),
    ),
    'partially_issued' => (
      const Color(0xFFF3E5F5),
      const Color(0xFF7B1FA2),
      const Color(0xFFCE93D8),
    ),
    'rejected' || 'cancelled' => (
      const Color(0xFFFFEBEE),
      const Color(0xFFC62828),
      const Color(0xFFEF9A9A),
    ),
    'closed' => (
      const Color(0xFFECEFF1),
      const Color(0xFF455A64),
      const Color(0xFFB0BEC5),
    ),
    _ => (
      const Color(0xFFFFF3E0),
      const Color(0xFFE65100),
      const Color(0xFFFFCC80),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, border) = _statusColors(request.status);
    final formattedDate = request.createdAt?.toNumericDateTime();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Request number + Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      request.number,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    humanizeStatus(request.status),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Metadata: Store and Date
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (storeName.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        storeName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (formattedDate != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            if (request.purpose.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.purpose.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),

            // Line items preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in request.lineItems.take(3)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              itemName(line.itemId),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Requested: ${line.requested == line.requested.toInt() ? line.requested.toInt() : line.requested}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (request.lineItems.length > 3) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+ ${request.lineItems.length - 3} more items',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
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
  }
}
