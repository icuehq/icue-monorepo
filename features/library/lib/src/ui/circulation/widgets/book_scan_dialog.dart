import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Details of a scanned copy with the one action that applies: Issue Book, or Return Book when it is on loan.
/// Pops `true` when the librarian taps the action.
class BookScanDialog extends StatelessWidget {
  const BookScanDialog({
    required this.copy,
    required this.book,
    required this.loan,
    super.key,
  });

  final LibraryCopy copy;
  final LibraryBook? book;
  final LibraryLoan? loan;

  static Future<bool> show(
    BuildContext context, {
    required LibraryCopy copy,
    required LibraryBook? book,
    required LibraryLoan? loan,
  }) async =>
      await pushFormPage<bool>(
        context,
        () => BookScanDialog(copy: copy, book: book, loan: loan),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final book = this.book;
    final loan = this.loan;
    final onLoan = loan != null;
    final overdue = loan?.overdueOn(todayIST()) ?? 0;
    final canIssue = !onLoan && copy.status == CopyStatus.available;
    final statusLabel = onLoan
        ? (overdue > 0
              ? 'Overdue · $overdue day${overdue == 1 ? '' : 's'}'
              : 'Issued')
        : copy.status.replaceAll('_', ' ').capitalized;
    final statusColor = onLoan
        ? (overdue > 0 ? scheme.error : scheme.tertiary)
        : canIssue
        ? Colors.green.shade700
        : scheme.outline;
    final details = <(IconData, String, String?)>[
      (Icons.person_outline_rounded, 'Authors', book?.authors.join(', ')),
      (Icons.business_rounded, 'Publisher', book?.publisher),
      (Icons.layers_outlined, 'Edition', book?.edition),
      (Icons.calendar_today_outlined, 'Year', book?.year?.toString()),
      (Icons.translate_rounded, 'Language', book?.language),
      (Icons.menu_book_outlined, 'Pages', book?.pages?.toString()),
      (Icons.shelves, 'Shelf', copy.shelf ?? book?.shelf),
      (Icons.verified_outlined, 'Condition', copy.condition.capitalized),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book?.title ?? copy.barcode,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (book?.subtitle case final subtitle?)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: Text(copy.barcode),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: statusColor.withValues(alpha: 0.14),
                        avatar: Icon(
                          Icons.circle,
                          size: 10,
                          color: statusColor,
                        ),
                        label: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (loan != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.badge_outlined, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Issued to ${loan.memberLabel}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Issued ${loan.issuedDate.toDisplayDay()} · due ${loan.dueDate.toDisplayDay()}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final (icon, label, value) in details)
                if (value != null && value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 80,
                          child: Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(value, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        if (book?.description case final description?
            when description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 20),
        if (onLoan)
          IcueButton(
            autofocus: true,
            isFullWidth: true,
            label: 'Return Book',
            leadingIcon: Icons.assignment_return_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          )
        else if (canIssue)
          IcueButton(
            autofocus: true,
            isFullWidth: true,
            label: 'Issue Book',
            leadingIcon: Icons.outbox_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
      ],
    );
  }
}

extension on String {
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
