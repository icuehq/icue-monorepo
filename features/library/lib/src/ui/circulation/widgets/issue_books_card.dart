import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/issue_scan_item_card.dart';
import 'package:school_library/src/ui/circulation/widgets/issue_step_card.dart';

/// Card showing the scan input, pending pre-scanned copy, and the list of issued books.
class IssueBooksCard extends StatelessWidget {
  const IssueBooksCard({
    required this.person,
    required this.queue,
    required this.records,
    required this.successfulCount,
    required this.busy,
    required this.onScan,
    required this.onRemoveQueued,
    required this.onIssue,
    required this.onDone,
    super.key,
  });

  final LibraryPerson? person;
  final List<IssueScanRecord> queue;
  final List<IssueScanRecord> records;
  final int successfulCount;
  final bool busy;
  final ValueChanged<String> onScan;
  final ValueChanged<IssueScanRecord> onRemoveQueued;
  final VoidCallback onIssue;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPerson = person != null;

    return IssueStepCard(
      step: 2,
      title: 'Books to Issue',
      subtitle: hasPerson
          ? 'Scan or type book barcode'
          : 'Select borrower to begin scanning',
      active: hasPerson,
      trailing: successfulCount > 0
          ? Chip(
              label: Text('$successfulCount issued'),
              visualDensity: VisualDensity.compact,
              backgroundColor: colorScheme.primaryContainer,
              side: BorderSide.none,
            )
          : null,
      children: [
        IcueScanField(
          autofocus: hasPerson,
          hint: hasPerson
              ? 'Scan or type book barcode'
              : 'Select borrower first to scan',
          onScan: onScan,
          clearOnScan: true,
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(),
            ),
          )
        else
          const SizedBox(height: 12),
        for (final record in queue)
          IssueScanItemCard(
            record: record,
            onRemove: busy ? null : () => onRemoveQueued(record),
          ),
        for (final record in records) IssueScanItemCard(record: record),
        if (queue.isEmpty && records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasPerson ? 'Ready to scan books' : 'Select a borrower',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPerson
                      ? 'Use a barcode gun, camera, or type the code above.'
                      : 'Choose a student or staff member to activate scanning.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: IcueButton(
                label: queue.isNotEmpty
                    ? 'Issue Book(s)'
                    : successfulCount > 0
                    ? 'Done'
                    : 'Cancel',
                onPressed: busy || (queue.isNotEmpty && !hasPerson)
                    ? null
                    : queue.isNotEmpty
                    ? onIssue
                    : onDone,
                variant: queue.isEmpty && successfulCount == 0
                    ? IcueButtonVariant.outline
                    : IcueButtonVariant.primary,
                leadingIcon: queue.isNotEmpty || successfulCount > 0
                    ? Icons.check_rounded
                    : Icons.arrow_back_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
