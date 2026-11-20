import 'package:flutter/material.dart';
import 'package:school_library/src/import/book_import.dart';

/// Responsive metrics summarizing the parsed spreadsheet plan.
class BookImportSummaryCards extends StatelessWidget {
  const BookImportSummaryCards({
    required this.plan,
    required this.resultsCount,
    required this.failedCount,
    required this.isFinished,
    required this.isImporting,
    super.key,
  });

  final BookImportPlan plan;
  final int resultsCount;
  final int failedCount;
  final bool isFinished;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasErrors = plan.issues.isNotEmpty;
    final successCount = resultsCount - failedCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 780
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              width: cardWidth,
              icon: Icons.menu_book_rounded,
              label: 'Unique titles',
              value: '${plan.books.length}',
              caption: 'Books to add or update',
              accentColor: scheme.primary,
            ),
            _MetricCard(
              width: cardWidth,
              icon: Icons.copy_rounded,
              label: 'Total copies',
              value: '${plan.copyCount}',
              caption: 'Accession barcodes',
              accentColor: Colors.blue.shade700,
            ),
            _MetricCard(
              width: cardWidth,
              icon: hasErrors
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              label: 'Validation',
              value: hasErrors ? '${plan.issues.length} errors' : 'All valid',
              caption: hasErrors
                  ? 'Resolve issues to import'
                  : 'Ready for catalogue',
              accentColor: hasErrors ? scheme.error : Colors.green.shade700,
            ),
            _MetricCard(
              width: cardWidth,
              icon: isFinished
                  ? (failedCount == 0
                        ? Icons.task_alt_rounded
                        : Icons.warning_amber_rounded)
                  : isImporting
                  ? Icons.sync_rounded
                  : Icons.pending_actions_rounded,
              label: 'Status',
              value: isFinished
                  ? '$successCount done'
                  : isImporting
                  ? '$resultsCount/${plan.books.length}'
                  : hasErrors
                  ? 'Blocked'
                  : 'Ready',
              caption: isFinished
                  ? (failedCount > 0
                        ? '$failedCount errors'
                        : 'Import finished')
                  : isImporting
                  ? 'Importing books...'
                  : hasErrors
                  ? 'Fix rows in spreadsheet'
                  : 'Click import below',
              accentColor: isFinished
                  ? (failedCount == 0 ? Colors.green.shade700 : scheme.error)
                  : (hasErrors ? scheme.error : scheme.primary),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.accentColor,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        color: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accentColor, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
