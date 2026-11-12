import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/circulation/widgets/loan_details_card.dart';
import 'package:school_library/src/ui/circulation/widgets/mark_lost_dialog.dart';
import 'package:school_library/src/ui/fines/widgets/fine_dialog.dart';

/// One active loan: renew it or take the book back (FRS 11.10–11.11).
class LoanDialog extends StatefulWidget {
  const LoanDialog({super.key, required this.loan, required this.title});

  final LibraryLoan loan;
  final String title;

  static Future<void> show(
    BuildContext context,
    LibraryLoan loan,
    String title,
  ) => showFormPage(context, () => LoanDialog(loan: loan, title: title));

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
    final navigator = Navigator.of(context);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
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
                      Text(
                        ' · ${loan.number}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
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
                icon: Icons.check_circle_outline_rounded,
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
                icon: Icons.heart_broken_outlined,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Copy will be marked damaged and an incident will be logged.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        IcueTextField(
          controller: _remarksController,
          label: _selectedCondition == 'damaged'
              ? 'Damage remarks (recommended)'
              : 'Return remarks (optional)',
          hintText: _selectedCondition == 'damaged'
              ? 'e.g. Broken binding, water stains'
              : null,
        ),
        const SizedBox(height: 16),
        IcueButton(
          label: _selectedCondition == 'damaged'
              ? 'Return book as damaged'
              : 'Return book',
          onPressed: _busy ? null : () => _returnBook(_selectedCondition),
          variant: _selectedCondition == 'damaged'
              ? IcueButtonVariant.destructive
              : IcueButtonVariant.primary,
          leadingIcon: _selectedCondition == 'damaged'
              ? Icons.heart_broken_rounded
              : Icons.assignment_returned_rounded,
          isLoading: _busy,
          isFullWidth: true,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: IcueButton(
                label: 'Renew loan',
                onPressed: _busy || !loan.canRenew
                    ? null
                    : () => _run(
                        (libraryProvider) => libraryProvider.renewLoan(loan.id),
                      ),
                variant: IcueButtonVariant.outline,
                leadingIcon: Icons.autorenew_rounded,
                isLoading: _busy,
                isFullWidth: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: IcueButton(
                label: 'Mark as lost',
                onPressed: _busy ? null : _markLost,
                variant: IcueButtonVariant.outline,
                leadingIcon: Icons.report_gmailerrorred_rounded,
                isLoading: _busy,
                isFullWidth: true,
              ),
            ),
          ],
        ),
        if (!loan.canRenew)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              !loan.isActive
                  ? 'Cannot renew: Loan is not active'
                  : 'Cannot renew: Maximum renewals reached (${loan.renewals}/${loan.maxRenewals})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
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
      return IcueStatusPill(
        label: 'Overdue by $overdueDays day${overdueDays == 1 ? '' : 's'}',
        color: colors.error,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (isDueToday) {
      return IcueStatusPill(
        label: 'Due today',
        color: Colors.amber.shade900,
        icon: Icons.schedule_rounded,
      );
    }
    return IcueStatusPill(
      label: 'Active · Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}',
      color: Colors.green.shade700,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  Widget _conditionCard({
    required ThemeData theme,
    required ColorScheme colors,
    required String label,
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.1)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? activeColor
                  : colors.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? activeColor : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? activeColor : colors.onSurface,
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
    final navigator = Navigator.of(context);
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
    final fine = await libraryProvider.fine('${loan.id}__overdue');
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
