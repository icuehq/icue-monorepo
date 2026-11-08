import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

/// One copy scan attempt in the current session.
class IssueScanRecord {
  const IssueScanRecord({
    required this.barcode,
    required this.success,
    required this.message,
    required this.timestamp,
    this.title,
    this.authors,
    this.copy,
    this.isPending = false,
  });

  final String barcode;
  final bool success;
  final String message;
  final DateTime timestamp;
  final String? title;
  final String? authors;
  final LibraryCopy? copy;
  final bool isPending;
}

/// Visual card representing one issued book, failed issue attempt, or pending pre-scanned book.
class IssueScanItemCard extends StatelessWidget {
  const IssueScanItemCard({required this.record, this.onRemove, super.key});

  final IssueScanRecord record;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPending = record.isPending;
    final isSuccess = record.success;
    final formattedTime = record.timestamp.toIndianTime().toTime12();

    final Color borderColor;
    final Color backgroundColor;
    final Color iconBackgroundColor;
    final Color iconColor;
    final IconData statusIcon;
    final String statusLabel;
    final Color statusTextColor;
    final Color statusBackgroundColor;

    if (isPending) {
      borderColor = colorScheme.tertiary.withValues(alpha: 0.4);
      backgroundColor = colorScheme.tertiaryContainer.withValues(alpha: 0.1);
      iconBackgroundColor = colorScheme.tertiaryContainer;
      iconColor = colorScheme.onTertiaryContainer;
      statusIcon = Icons.hourglass_top_rounded;
      statusLabel = 'Awaiting Borrower';
      statusTextColor = colorScheme.onTertiaryContainer;
      statusBackgroundColor = colorScheme.tertiaryContainer;
    } else if (isSuccess) {
      borderColor = Colors.green.withValues(alpha: 0.3);
      backgroundColor = Colors.green.withValues(alpha: 0.04);
      iconBackgroundColor = Colors.green.withValues(alpha: 0.14);
      iconColor = Colors.green.shade700;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Issued';
      statusTextColor = Colors.green.shade800;
      statusBackgroundColor = Colors.green.withValues(alpha: 0.15);
    } else {
      borderColor = colorScheme.error.withValues(alpha: 0.3);
      backgroundColor = colorScheme.error.withValues(alpha: 0.04);
      iconBackgroundColor = colorScheme.errorContainer;
      iconColor = colorScheme.error;
      statusIcon = Icons.error_outline_rounded;
      statusLabel = 'Failed';
      statusTextColor = colorScheme.onErrorContainer;
      statusBackgroundColor = colorScheme.errorContainer;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title ?? record.barcode,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (record.authors case final authors?
                      when authors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        authors,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              record.barcode,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (record.message.isNotEmpty &&
                          (!isSuccess || isPending))
                        Text(
                          record.message,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isPending
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusTextColor,
                        ),
                      ),
                    ),
                    if (isPending && onRemove != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onRemove,
                      ),
                    ],
                  ],
                ),
                if (!isPending) ...[
                  const SizedBox(height: 6),
                  Text(
                    formattedTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
