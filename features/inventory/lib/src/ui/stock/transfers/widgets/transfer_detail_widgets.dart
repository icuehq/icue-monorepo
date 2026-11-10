import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/transfers/transfer_rules.dart';

ShapeBorder _cardShape(ThemeData theme) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  side: BorderSide(color: theme.colorScheme.outlineVariant),
);

/// Route, status, progress and dates of a transfer.
class TransferSummaryCard extends StatelessWidget {
  const TransferSummaryCard({
    required this.transfer,
    required this.fromStoreName,
    required this.toStoreName,
    super.key,
  });

  final InventoryTransfer transfer;
  final String fromStoreName;
  final String toStoreName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = transferStatusColor(transfer.status);
    final level = switch (transfer.status) {
      'requested' || 'approved' || 'cancelled' => 0,
      'dispatched' => 1,
      _ => 2,
    };
    final steps = [
      'Requested',
      'In transit',
      transfer.status == 'partially_received' ? 'Partly received' : 'Received',
    ];
    Widget detail(String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$label: $value',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: _cardShape(theme),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'From',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    humanizeStatus(transfer.status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              fromStoreName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'To',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
            Text(
              toStoreName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (index, label) in steps.indexed) ...[
                  if (index > 0)
                    Expanded(
                      child: Divider(
                        thickness: 2,
                        color: index <= level
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                  Column(
                    children: [
                      Icon(
                        index <= level
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: index <= level
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 2),
                      Text(label, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            detail('Dispatched', transfer.dispatchedDate?.toDisplayDay()),
            detail('Received', transfer.receivedDate?.toDisplayDay()),
            if (transfer.fromCampusId != transfer.toCampusId)
              detail('Route', 'Inter-campus transfer'),
            detail('Remarks', transfer.remarks),
          ],
        ),
      ),
    );
  }
}

/// Requested items, then what was sent and received; the receiver enters quantities in place.
class TransferLinesCard extends StatelessWidget {
  const TransferLinesCard({
    required this.transfer,
    required this.itemName,
    required this.receiveControllers,
    super.key,
  });

  final InventoryTransfer transfer;
  final String Function(String itemId) itemName;

  /// One controller per dispatched line while the user can receive, else null.
  final List<TextEditingController>? receiveControllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final entering = receiveControllers;
    final requestedOnly = transfer.preDispatch;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: _cardShape(theme),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              requestedOnly
                  ? 'Items to dispatch (${transfer.requested.length})'
                  : 'Items (${transfer.lineItems.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (requestedOnly)
              for (final line in transfer.requested)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(itemName(line.itemId))),
                      Text(
                        line.quantity.toQuantityText(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
            else
              for (final (index, line) in transfer.lineItems.indexed) ...[
                if (index > 0) const Divider(height: 20),
                Text(
                  '${itemName(line.itemId)}'
                  '${line.batchNumber == null ? '' : ' · Batch ${line.batchNumber}'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: line.dispatched == 0
                      ? 0
                      : (line.received / line.dispatched).clamp(0, 1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sent ${line.dispatched.toQuantityText()} · '
                  'Received ${line.received.toQuantityText()}',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
                if (line.discrepancy > 0)
                  Text(
                    'Shortfall ${line.discrepancy.toQuantityText()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (entering != null && line.dispatched - line.received > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IcueTextField(
                      controller: entering[index],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [decimalInputFormatter],
                      label: 'Receive now',
                      helperText:
                          'Up to ${(line.dispatched - line.received).toQuantityText()}',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.done_all, size: 18),
                        tooltip: 'Everything remaining',
                        onPressed: () => entering[index].text =
                            (line.dispatched - line.received).toQuantityText(),
                      ),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}
