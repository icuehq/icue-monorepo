import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/import/book_import.dart';

/// A book from the sheet with its copies and import status.
class BookImportBookTile extends StatelessWidget {
  const BookImportBookTile({required this.book, this.result, super.key});

  final BookImportBook book;
  final BookImportResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final importResult = result;
    final copiesCount = book.copies.length;
    final authorsList = book.book['authors'] as List<String>?;
    final authors = authorsList?.join(', ') ?? '';

    final (
      icon,
      iconColor,
      statusLabel,
      statusColor,
      statusBackground,
    ) = switch (importResult) {
      null => (
        Icons.hourglass_empty_rounded,
        scheme.outline,
        'Ready',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      BookImportResult(:final error?) => (
        Icons.error_rounded,
        scheme.error,
        'Failed',
        scheme.error,
        scheme.errorContainer,
      ),
      _ => (
        Icons.check_circle_rounded,
        Colors.green.shade700,
        importResult.created ? 'New Book' : 'Added Copies',
        Colors.green.shade800,
        Colors.green.shade50,
      ),
    };

    final subtitleText = switch (importResult) {
      null =>
        '$copiesCount ${copiesCount == 1 ? 'copy' : 'copies'} · Barcodes: ${book.copies.first.barcode}'
            '${copiesCount > 1 ? ' … ${book.copies.last.barcode}' : ''}',
      BookImportResult(:final error?) =>
        '${importResult.copiesAdded} of $copiesCount copies added. $error',
      _ =>
        '${importResult.copiesAdded} ${importResult.copiesAdded == 1 ? 'copy' : 'copies'} added across ${book.copies.length} rows',
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${book.firstLine}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          book.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (authors.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      authors,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: importResult?.error != null
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet row that cannot be imported, with its errors.
class BookImportIssueTile extends StatelessWidget {
  const BookImportIssueTile({required this.issue, super.key});

  final BookImportIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = scheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Row ${issue.line}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title.isEmpty ? '(No title specified)' : issue.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                for (final error in issue.errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: color, height: 1.3)),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
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
