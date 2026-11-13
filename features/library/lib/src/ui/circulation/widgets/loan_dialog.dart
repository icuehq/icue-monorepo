import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_details_card.dart';
import 'package:school_library/src/ui/circulation/widgets/mark_lost_dialog.dart';
import 'package:school_library/src/ui/fines/widgets/fine_dialog.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// One active loan: return the book or mark it as lost (FRS 11.10–11.11).
class LoanDialog extends StatefulWidget {
  const LoanDialog({super.key, required this.loan, required this.title});

  final LibraryLoan loan;
  final String title;

  static Future<void> show(
    BuildContext context,
    LibraryLoan loan,
    String title,
  ) => showDialog<void>(
    context: context,
    builder: (_) => LoanDialog(loan: loan, title: title),
  );

  @override
  State<LoanDialog> createState() => _LoanDialogState();
}

class _LoanDialogState extends State<LoanDialog> {
  final _remarksController = TextEditingController();
  String _selectedCondition = 'good';
  bool _busy = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<bool> _run(
    Future<bool> Function(LibraryProvider libraryProvider) action,
  ) async {
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final isSuccess = await action(libraryProvider);
    if (!mounted) return false;
    if (isSuccess) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
      showMessage(context, libraryProvider.errorMessage ?? 'Failed');
    }
    return isSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final today = todayIST();
    final overdueDays = loan.overdueOn(today);
    final isOverdue = overdueDays > 0;
    final isDueToday = !isOverdue && loan.dueDate == today;
    final fineAmount = loan.fineOn(today);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    int daysUntilDue = 0;
    if (!isOverdue && !isDueToday) {
      try {
        daysUntilDue = DateTime.parse('${loan.dueDate}T00:00:00Z')
            .difference(DateTime.parse('${today}T00:00:00Z'))
            .inDays;
      } catch (_) {
        daysUntilDue = 0;
      }
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 28,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusPill(
                    colors,
                    isOverdue: isOverdue,
                    isDueToday: isDueToday,
                    overdueDays: overdueDays,
                    daysUntilDue: daysUntilDue,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 15,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        loan.barcode,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LoanDetailsCard(
          loan: loan,
          isOverdue: isOverdue,
          overdueDays: overdueDays,
          fineAmount: fineAmount,
        ),
        const SizedBox(height: 16),
        Text(
          'Return condition',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _conditionCard(
                theme: theme,
                colors: colors,
                label: 'Good condition',
                subtitle: 'Normal wear & tear',
                icon: Icons.check_circle_rounded,
                selected: _selectedCondition == 'good',
                onTap: _busy
                    ? null
                    : () => setState(() => _selectedCondition = 'good'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _conditionCard(
                theme: theme,
                colors: colors,
                label: 'Damaged',
                subtitle: 'Torn, broken or stained',
                icon: Icons.heart_broken_rounded,
                selected: _selectedCondition == 'damaged',
                selectedColor: colors.error,
                onTap: _busy
                    ? null
                    : () => setState(() => _selectedCondition = 'damaged'),
              ),
            ),
          ],
        ),
        if (_selectedCondition == 'damaged') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: colors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copy will be marked damaged and an incident will be logged in the library register.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        IcueTextField(
          controller: _remarksController,
          label: _selectedCondition == 'damaged'
              ? 'Damage remarks (describe damage)'
              : 'Return remarks (optional)',
          hintText: _selectedCondition == 'damaged'
              ? 'e.g. Broken spine, torn pages, water stains'
              : 'Add any optional note',
        ),
      ],
    );

    final damaged = _selectedCondition == 'damaged';
    return IcueDialog(
      title: 'Return book',
      size: IcueDialogSize.large,
      content: content,
      secondaryAction: IcueDialogAction(
        label: 'Mark as lost',
        icon: Icons.report_gmailerrorred_rounded,
        variant: IcueButtonVariant.outline,
        onPressed: _busy ? null : _markLost,
      ),
      primaryAction: IcueDialogAction(
        label: damaged ? 'Return as damaged' : 'Complete return',
        icon: damaged
            ? Icons.heart_broken_rounded
            : Icons.assignment_returned_rounded,
        variant: damaged
            ? IcueButtonVariant.destructive
            : IcueButtonVariant.primary,
        isLoading: _busy,
        onPressed: _busy ? null : () => _returnBook(_selectedCondition),
      ),
    );
  }

  Widget _buildStatusPill(
    ColorScheme colors, {
    required bool isOverdue,
    required bool isDueToday,
    required int overdueDays,
    required int daysUntilDue,
  }) {
    if (isOverdue) {
      return LibraryStatusChip(
        'overdue',
        label: 'Overdue by $overdueDays day${overdueDays == 1 ? '' : 's'}',
      );
    }
    if (isDueToday) {
      return const LibraryStatusChip('due_today', label: 'Due today');
    }
    return LibraryStatusChip(
      'on_time',
      label: 'Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}',
    );
  }

  Widget _conditionCard({
    required ThemeData theme,
    required ColorScheme colors,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
    Color? selectedColor,
  }) {
    final activeColor = selectedColor ?? colors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.08)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? activeColor
                  : colors.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? activeColor : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? activeColor : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _returnBook(String condition) async {
    final loan = widget.loan;
    final navigator = Navigator.of(context, rootNavigator: true);
    final libraryProvider = context.read<LibraryProvider>();
    final isFined = loan.fineOn(todayIST()) > 0;
    final isSuccess = await _run(
      (libraryProvider) => libraryProvider.returnLoan(
        id: loan.id,
        condition: condition,
        remarks: blankToNull(_remarksController),
      ),
    );
    if (!isSuccess || !isFined || !navigator.mounted) return;
    // The server raises the overdue fine under this id; open it so it can be collected now.
    final fine = await libraryProvider.service.fine('${loan.id}__overdue');
    if (fine != null && navigator.mounted) {
      await FineDialog.show(navigator.context, fine);
    }
  }

  Future<void> _markLost() async {
    final result = await MarkLostDialog.show(context, widget.loan);
    if (result == null || !mounted) return;

    await _run(
      (libraryProvider) => libraryProvider.markLoanLost(
        id: widget.loan.id,
        reason: result.reason,
        charge: result.charge,
      ),
    );
  }
}
