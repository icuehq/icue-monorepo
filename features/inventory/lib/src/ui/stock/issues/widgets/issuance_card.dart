import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/person_search_field.dart';

/// One issue against a request: what left the store, receipt status and returns.
class IssuanceCard extends StatelessWidget {
  const IssuanceCard({
    required this.issue,
    required this.itemName,
    required this.busy,
    required this.onConfirmReceipt,
    required this.onReturn,
    super.key,
  });

  final InventoryIssue issue;
  final String Function(String itemId) itemName;
  final bool busy;
  final VoidCallback onConfirmReceipt;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final hasOutstanding = issue.lineItems.any((line) => line.outstanding > 0);
    final recipientId = issue.recipientId;
    final confirmedColor = issue.acknowledged
        ? Colors.green.shade700
        : Colors.orange.shade800;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue.number,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                issue.acknowledged ? 'Receipt confirmed' : 'Awaiting receipt',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: confirmedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (issue.createdAt != null || recipientId != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (recipientId != null)
                    'To ${issue.recipientType == 'staff' ? staffDisplayName(recipientId) : '${issue.recipientType} #$recipientId'}',
                  if (issue.createdAt != null) issue.createdAt!.toNumericDate(),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          const SizedBox(height: 8),
          for (final line in issue.lineItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${itemName(line.itemId)}'
                      '${line.batchNumber == null ? '' : ' (${line.batchNumber})'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${line.quantity.toQuantityText()}'
                    '${line.returned > 0 ? ' · returned ${line.returned.toQuantityText()}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (!issue.acknowledged || hasOutstanding) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (!issue.acknowledged)
                  Expanded(
                    child: AppButton(
                      label: 'Confirm receipt',
                      onPressed: busy ? null : onConfirmReceipt,
                      variant: AppButtonVariant.secondary,
                    ),
                  ),
                if (!issue.acknowledged && hasOutstanding)
                  const SizedBox(width: 8),
                if (hasOutstanding)
                  Expanded(
                    child: AppButton(
                      label: 'Return items',
                      onPressed: busy ? null : onReturn,
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.undo_rounded,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
