import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/issue_scan_item_card.dart';

/// Card showing the scan input, pending pre-scanned copy, and the list of issued books.
class IssueBooksCard extends StatelessWidget {
  const IssueBooksCard({
    required this.person,
    required this.pendingRecord,
    required this.records,
    required this.successfulCount,
    required this.busy,
    required this.onScan,
    required this.onRemovePending,
    required this.onIssuePending,
    required this.onDone,
    super.key,
  });

  final LibraryPerson? person;
  final IssueScanRecord? pendingRecord;
  final List<IssueScanRecord> records;
  final int successfulCount;
  final bool busy;
  final ValueChanged<String> onScan;
  final VoidCallback onRemovePending;
  final VoidCallback onIssuePending;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPerson = person != null;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Books to Issue',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        hasPerson
                            ? 'Scan or type book barcode'
                            : 'Select borrower to begin scanning',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (successfulCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$successfulCount issued',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            // A book scanned before the page opened is already chosen.
            if (pendingRecord == null)
              ScanField(
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
            if (pendingRecord case final pending?)
              IssueScanItemCard(record: pending, onRemove: onRemovePending),
            if (pendingRecord != null && hasPerson)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  onPressed: busy ? null : onIssuePending,
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text('Issue book'),
                ),
              ),
            for (final record in records) IssueScanItemCard(record: record),
            if (pendingRecord == null && records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
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
                  child: FilledButton.icon(
                    onPressed: busy ? null : onDone,
                    icon: Icon(
                      successfulCount > 0
                          ? Icons.check_rounded
                          : Icons.arrow_back_rounded,
                      size: 18,
                    ),
                    label: Text(
                      successfulCount > 0 ? 'Issue Book(s)' : 'Cancel',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
