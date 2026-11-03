import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/purchase_request_rules.dart';

String formatPurchaseDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

class PurchaseSection extends StatelessWidget {
  const PurchaseSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class PurchaseSummary extends StatelessWidget {
  const PurchaseSummary({required this.request, super.key});

  final InventoryPurchaseRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // The latest comment explains a return, rejection or cancellation.
    final reason = request.history.lastOrNull?.comment;
    final showReason =
        (reason?.isNotEmpty ?? false) &&
        const [
          'revision_requested',
          'rejected',
          'cancelled',
        ].contains(request.status);
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );

    return PurchaseSection(
      title: request.number,
      trailing: PurchaseStatusPill(request.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.purpose,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          row(Icons.event_outlined, 'Needed by ${request.requiredDate}'),
          row(
            Icons.flag_outlined,
            '${humanizeStatus(request.priority)} priority',
          ),
          row(Icons.apartment_outlined, 'Campus ${request.campusId}'),
          if (request.createdAt != null)
            row(
              Icons.schedule_outlined,
              'Raised on ${formatPurchaseDate(request.createdAt!)}',
            ),
          if (request.remarks?.isNotEmpty ?? false)
            row(Icons.notes_outlined, request.remarks!),
          if (showReason) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: purchaseStatusColor(request.status)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(reason!, style: theme.textTheme.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

class PurchaseItems extends StatelessWidget {
  const PurchaseItems({
    required this.request,
    required this.itemName,
    super.key,
  });

  final InventoryPurchaseRequest request;
  final String Function(String itemId) itemName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PurchaseSection(
      title: 'Items (${request.lineItems.length})',
      child: Column(
        children: [
          for (final (index, line) in request.lineItems.indexed) ...[
            if (index > 0) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName(line.itemId),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${formatQuantity(line.quantity)} × ₹${formatQuantity(line.estimatedPrice)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${formatQuantity(line.quantity * line.estimatedPrice)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (line.quantityOrdered > 0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (line.quantityOrdered / line.quantity).clamp(0, 1),
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 2),
              Text(
                'Ordered ${formatQuantity(line.quantityOrdered)} of ${formatQuantity(line.quantity)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Total estimate')),
              Text(
                '₹${formatQuantity(request.total)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PurchaseHistory extends StatelessWidget {
  const PurchaseHistory({required this.history, super.key});

  final List<PurchaseRequestHistoryEntry> history;

  static IconData _icon(String action) => switch (action) {
    'approve' => Icons.check_circle_rounded,
    'reject' => Icons.cancel_rounded,
    'revise' => Icons.replay_rounded,
    'cancel' => Icons.block_rounded,
    _ => Icons.fiber_manual_record_rounded,
  };

  static Color _color(String action) => switch (action) {
    'approve' => Colors.green,
    'reject' => Colors.red,
    'revise' => Colors.orange,
    'cancel' => Colors.grey,
    _ => Colors.blue,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PurchaseSection(
      title: 'History',
      child: Column(
        children: [
          for (final entry in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _icon(entry.action),
                    size: 16,
                    color: _color(entry.action),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          humanizeStatus(entry.action),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (entry.comment?.isNotEmpty ?? false)
                          Text(
                            entry.comment!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (entry.performedAt != null)
                    Text(
                      formatPurchaseDate(entry.performedAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
