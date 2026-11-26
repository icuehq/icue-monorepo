import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:provider/provider.dart';

class PurchaseSection extends StatelessWidget {
  const PurchaseSection({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class PurchaseSummary extends StatelessWidget {
  const PurchaseSummary({required this.request, this.storeName, super.key});

  final InventoryPurchaseRequest request;
  final String? storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // A closing reason explains why the rest will not arrive.
    final last = request.history.lastOrNull;
    final reason = last?.action == 'close' ? last?.comment : null;
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );

    return PurchaseSection(
      icon: Icons.receipt_long_outlined,
      title: request.number,
      trailing: InventoryStatusChip(request.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.purpose,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (storeName != null) row(Icons.warehouse_outlined, storeName!),
          row(
            Icons.event_outlined,
            'Needed by ${request.requiredDate.toDisplayDay()}',
          ),
          row(
            Icons.flag_outlined,
            '${humanizeStatus(request.priority)} priority',
          ),
          if (request.createdAt != null)
            row(
              Icons.schedule_outlined,
              'Created on ${request.createdAt!.toIndianTime().toNumericDate()}',
            ),
          if (request.remarks?.isNotEmpty ?? false)
            row(Icons.notes_outlined, request.remarks!),
          if (reason?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: inventoryStatusColor(request.status)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Closed reason: $reason',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Each line: what was requested and what has arrived so far.
class PurchaseItems extends StatelessWidget {
  const PurchaseItems({
    required this.request,
    required this.lineName,
    super.key,
  });

  final InventoryPurchaseRequest request;
  final String Function(PurchaseRequestLine line) lineName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = context.read<ProcurementProvider>().items;
    final count = request.lineItems.length;
    return PurchaseSection(
      icon: Icons.checklist_rounded,
      title: 'Items',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count ${count == 1 ? 'item' : 'items'}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: Column(
        children: [
          for (final (index, line) in request.lineItems.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final unit = items[line.itemId]?.stockUnit ?? '';
                String amount(double value) =>
                    '${value.toQuantityText()}${unit.isEmpty ? '' : ' $unit'}';
                final progress = line.quantity > 0
                    ? (line.received / line.quantity).clamp(0.0, 1.0)
                    : 0.0;
                final complete = line.pending <= 0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lineName(line),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Requested: ${amount(line.quantity)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: complete
                              ? Colors.green.shade700
                              : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Received: ${amount(line.received)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: complete
                                  ? Colors.green.shade800
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (line.damaged > 0)
                            Text(
                              'Damaged: ${amount(line.damaged)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          if (line.pending > 0 && request.isOpen)
                            Text(
                              'Pending: ${amount(line.pending)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class PurchaseHistory extends StatelessWidget {
  const PurchaseHistory({required this.history, super.key});

  final List<PurchaseRequestHistoryEntry> history;

  static IconData _icon(String action) => switch (action) {
    'receive' => Icons.move_to_inbox_rounded,
    'update' => Icons.edit_rounded,
    'close' => Icons.block_rounded,
    _ => Icons.fiber_manual_record_rounded,
  };

  static Color _color(String action) => switch (action) {
    'receive' => Colors.green,
    'update' => Colors.orange,
    'close' => Colors.grey,
    _ => Colors.blue,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PurchaseSection(
      icon: Icons.history_rounded,
      title: 'History',
      child: Column(
        children: [
          for (final (index, entry) in history.indexed)
            Padding(
              padding: EdgeInsets.only(
                bottom: index < history.length - 1 ? 10 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _icon(entry.action),
                      size: 16,
                      color: _color(entry.action),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (entry.action) {
                            'create' => 'Created',
                            'update' => 'Edited',
                            'receive' => 'Items received',
                            'close' => 'Closed',
                            _ => humanizeStatus(entry.action),
                          },
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
                      entry.performedAt!.toIndianTime().toNumericDate(),
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
