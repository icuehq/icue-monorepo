import 'package:flutter/material.dart';
import 'package:school_library/src/import/book_import.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_rows.dart';

/// Shows validation errors in spreadsheet rows that block import.
class BookImportIssuesCard extends StatelessWidget {
  const BookImportIssuesCard({required this.issues, super.key});

  final List<BookImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${issues.length} ${issues.length == 1 ? 'row has' : 'rows have'} validation errors',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Nothing is imported until all errors are resolved. Please correct these issues in your spreadsheet and upload the file again.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: issues.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  BookImportIssueTile(issue: issues[index]),
            ),
          ),
        ],
      ),
    );
  }
}
