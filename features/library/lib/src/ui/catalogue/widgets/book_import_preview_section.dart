import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/import/book_import.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_import_rows.dart';

/// Previews parsed books in a table on wide screens or cards on phones,
/// with import actions, progress and completion status.
class BookImportPreviewSection extends StatelessWidget {
  const BookImportPreviewSection({
    required this.plan,
    required this.results,
    required this.isImporting,
    required this.isFinished,
    required this.failedCount,
    required this.copiesAdded,
    required this.onImport,
    required this.onReset,
    super.key,
  });

  final BookImportPlan plan;
  final Map<int, BookImportResult> results;
  final bool isImporting;
  final bool isFinished;
  final int failedCount;
  final int copiesAdded;
  final VoidCallback onImport;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWide = context.isWide;
    final booksCount = plan.books.length;
    final copiesCount = plan.copyCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFinished && !isImporting)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_outlined, color: scheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to import',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$booksCount books with $copiesCount physical copies are validated.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IcueButton(
                  label: 'Import $copiesCount copies of $booksCount books',
                  leadingIcon: Icons.playlist_add_check_rounded,
                  onPressed: booksCount == 0 ? null : onImport,
                ),
              ],
            ),
          ),
        if (isImporting)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Importing books into catalogue...',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${results.length} of $booksCount processed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: booksCount == 0 ? 0 : results.length / booksCount,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 8,
                ),
              ],
            ),
          ),
        if (isFinished)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: failedCount == 0
                  ? Colors.green.shade50
                  : scheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: failedCount == 0
                    ? Colors.green.shade300
                    : scheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  failedCount == 0
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: failedCount == 0
                      ? Colors.green.shade700
                      : scheme.error,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        failedCount == 0
                            ? 'Import completed successfully'
                            : 'Import completed with errors',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: failedCount == 0
                              ? Colors.green.shade800
                              : scheme.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$copiesAdded copies added to ${results.length - failedCount} books.'
                        '${failedCount > 0 ? ' $failedCount books stopped with an error.' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: failedCount == 0
                              ? Colors.green.shade900
                              : scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IcueButton(
                  label: 'Import another file',
                  variant: IcueButtonVariant.outline,
                  leadingIcon: Icons.refresh_rounded,
                  size: IcueButtonSize.small,
                  onPressed: onReset,
                ),
                const SizedBox(width: 8),
                IcueButton(
                  label: 'View catalogue',
                  leadingIcon: Icons.arrow_forward_rounded,
                  size: IcueButtonSize.small,
                  onPressed: () =>
                      context.goNamed(LibraryRoutes.libraryCatalogueName),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (isWide)
          IcueClientTable<BookImportBook>(
            title: 'Catalogue preview ($booksCount books)',
            items: plan.books,
            rowKey: (book) => book.firstLine,
            rowLabel: (book) => book.title,
            searchText: (book) {
              final authors =
                  (book.book['authors'] as List<String>?)?.join(' ') ?? '';
              final barcodes = book.copies
                  .map((copy) => copy.barcode)
                  .join(' ');
              return '${book.title} $authors $barcodes';
            },
            searchHint: 'Search title, author, barcode...',
            columns: [
              IcueTableColumn<BookImportBook>(
                id: 'row',
                label: 'Row',
                width: 70,
                cellBuilder: (context, book) => Text(
                  '#${book.firstLine}',
                  style: TextStyle(
                    color: scheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IcueTableColumn<BookImportBook>(
                id: 'title',
                label: 'Title & authors',
                sortable: true,
                comparator: (book) => book.title,
                cellBuilder: (context, book) {
                  final authors =
                      (book.book['authors'] as List<String>?)?.join(', ') ?? '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (authors.isNotEmpty)
                        Text(
                          authors,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                },
              ),
              IcueTableColumn<BookImportBook>(
                id: 'category',
                label: 'Category',
                cellBuilder: (context, book) {
                  final category = context.watch<LibraryProvider>().category(
                    book.categoryId,
                  );
                  return Text(category?.name ?? '—');
                },
              ),
              IcueTableColumn<BookImportBook>(
                id: 'copies',
                label: 'Copies',
                width: 90,
                alignment: Alignment.center,
                sortable: true,
                comparator: (book) => book.copies.length,
                cellBuilder: (context, book) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${book.copies.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              IcueTableColumn<BookImportBook>(
                id: 'barcodes',
                label: 'Barcodes',
                cellBuilder: (context, book) {
                  final first = book.copies.first.barcode;
                  final label = book.copies.length > 1
                      ? '$first … ${book.copies.last.barcode}'
                      : first;
                  return Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  );
                },
              ),
              IcueTableColumn<BookImportBook>(
                id: 'status',
                label: 'Status',
                width: 150,
                cellBuilder: (context, book) {
                  final result = results[book.firstLine];
                  return _StatusBadge(result: result);
                },
              ),
            ],
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: plan.books.length,
            itemBuilder: (context, index) => BookImportBookTile(
              book: plan.books[index],
              result: results[plan.books[index].firstLine],
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.result});

  final BookImportResult? result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final importResult = result;
    if (importResult == null) {
      return IcueStatusPill(
        label: 'Ready',
        color: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHighest,
        icon: Icons.hourglass_empty_rounded,
        bordered: false,
      );
    }
    if (importResult.error != null) {
      return IcueStatusPill(
        label: 'Failed',
        color: scheme.error,
        background: scheme.errorContainer,
        icon: Icons.error_outline_rounded,
        bordered: false,
      );
    }
    return IcueStatusPill(
      label: importResult.created ? 'New Book' : 'Added Copies',
      color: Colors.green.shade800,
      background: Colors.green.shade50,
      icon: Icons.check_circle_rounded,
      bordered: false,
    );
  }
}
