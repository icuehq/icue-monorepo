import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/transfers/widgets/transfer_widgets.dart';

/// Header of a transfer: route, status, progress and dates.
class TransferSummary extends StatelessWidget {
  const TransferSummary({
    required this.transfer,
    required this.fromName,
    required this.toName,
    super.key,
  });

  final LibraryTransfer transfer;
  final String fromName;
  final String toName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final level = switch (transfer.status) {
      'requested' => 0,
      'approved' => 1,
      'dispatched' => 2,
      _ => 3,
    };
    final steps = [
      'Requested',
      'Approved',
      'In transit',
      transfer.status == 'partially_received' ? 'Partly received' : 'Received',
    ];
    Widget dateRow(String label, String? date) => date == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$label: $date',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          );

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
                    'From',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
                TransferStatusPill(transfer.status),
              ],
            ),
            Text(
              fromName,
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
              toName,
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
            dateRow('Requested', transfer.requestedDate),
            dateRow('Dispatched', transfer.dispatchedDate),
            dateRow('Received', transfer.receivedDate),
            if (transfer.remarks?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Remarks: ${transfer.remarks}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A copy arriving at the destination: tick it off and note its condition.
class TransferReceiveRow extends StatelessWidget {
  const TransferReceiveRow({
    required this.line,
    required this.selected,
    required this.condition,
    required this.onSelected,
    required this.onCondition,
    super.key,
  });

  final LibraryTransferLine line;
  final bool selected;
  final String condition;
  final ValueChanged<bool> onSelected;
  final ValueChanged<String> onCondition;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Checkbox(value: selected, onChanged: (value) => onSelected(value!)),
      Expanded(
        child: Text(
          line.accessionNumber,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      DropdownButton<String>(
        value: condition,
        underline: const SizedBox.shrink(),
        items: [
          for (final value in copyConditions)
            DropdownMenuItem(
              value: value,
              child: Text('${value[0].toUpperCase()}${value.substring(1)}'),
            ),
        ],
        onChanged: selected ? (value) => onCondition(value!) : null,
      ),
    ],
  );
}
