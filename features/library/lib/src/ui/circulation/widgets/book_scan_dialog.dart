import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Details of a scanned copy with the actions that apply:
/// Issue Book (when available), or Return / Renew Book (when on loan).
/// Pops `true` when the librarian taps to proceed (e.g. Return Book or Issue Book).
class BookScanDialog extends StatefulWidget {
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
      await showDialog<bool>(
        context: context,
        builder: (_) => BookScanDialog(copy: copy, book: book, loan: loan),
      ) ??
      false;

  @override
  State<BookScanDialog> createState() => _BookScanDialogState();
}

class _BookScanDialogState extends State<BookScanDialog> {
  bool _busy = false;

  Future<void> _renew() async {
    final loan = widget.loan;
    if (loan == null) return;
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final isSuccess = await libraryProvider.renewLoan(loan.id);
    if (!mounted) return;
    if (isSuccess) {
      navigator.pop(false);
      showMessage(
        context,
        'Loan for ${widget.book?.title ?? widget.copy.barcode} renewed successfully.',
      );
    } else {
      setState(() => _busy = false);
      showMessage(
        context,
        libraryProvider.errorMessage ?? 'Failed to renew loan',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final book = widget.book;
    final loan = widget.loan;
    final onLoan = loan != null;
    final overdue = loan?.overdueOn(todayIST()) ?? 0;
    final isOverdue = overdue > 0;
    final canIssue = !onLoan && widget.copy.status == CopyStatus.available;
    final canRenew = onLoan && loan.canRenew && !isOverdue;

    String? cannotRenewReason;
    if (onLoan && !canRenew) {
      if (!loan.isActive) {
        cannotRenewReason = 'Cannot renew: Loan is not active';
      } else if (isOverdue) {
        cannotRenewReason =
            'Cannot renew: Book is overdue by $overdue day${overdue == 1 ? '' : 's'}';
      } else if (loan.renewals >= loan.maxRenewals) {
        cannotRenewReason =
            'Cannot renew: Renewal limit reached (${loan.renewals}/${loan.maxRenewals})';
      }
    }

    final statusLabel = onLoan
        ? (overdue > 0
              ? 'Overdue · $overdue day${overdue == 1 ? '' : 's'}'
              : 'Issued')
        : widget.copy.status.replaceAll('_', ' ').capitalized;
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
      (Icons.shelves, 'Shelf', widget.copy.shelf ?? book?.shelf),
      (Icons.verified_outlined, 'Condition', widget.copy.condition.capitalized),
    ];
    final content = Column(
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
                    book?.title ?? widget.copy.barcode,
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
                        label: Text(widget.copy.barcode),
                      ),
                      LibraryStatusChip(
                        onLoan
                            ? (overdue > 0 ? 'overdue' : 'issued')
                            : widget.copy.status,
                        label: statusLabel,
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
                      const SizedBox(height: 2),
                      Text(
                        'Issued ${loan.issuedDate.toDisplayDay()} · due ${loan.dueDate.toDisplayDay()} · ${loan.renewals}/${loan.maxRenewals} renewals used',
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
        if (cannotRenewReason != null) ...[
          const SizedBox(height: 12),
          Text(
            cannotRenewReason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );

    void close(bool proceed) =>
        Navigator.of(context, rootNavigator: true).pop(proceed);

    return IcueDialog(
      title: 'Scanned book',
      size: IcueDialogSize.large,
      content: content,
      secondaryAction: onLoan
          ? IcueDialogAction(
              label: 'Renew',
              icon: Icons.autorenew_rounded,
              variant: IcueButtonVariant.outline,
              isLoading: _busy,
              onPressed: (_busy || !canRenew) ? null : _renew,
            )
          : null,
      primaryAction: onLoan
          ? IcueDialogAction(
              label: 'Return Book',
              icon: Icons.assignment_return_rounded,
              onPressed: _busy ? null : () => close(true),
            )
          : canIssue
          ? IcueDialogAction(
              label: 'Issue Book',
              icon: Icons.outbox_rounded,
              onPressed: () => close(true),
            )
          : IcueDialogAction(
              label: 'Close',
              variant: IcueButtonVariant.ghost,
              onPressed: () => close(false),
            ),
    );
  }
}

extension on String {
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
