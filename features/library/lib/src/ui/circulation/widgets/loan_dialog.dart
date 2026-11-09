import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
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
  final _remarks = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<bool> _run(
    Future<bool> Function(LibraryProvider libraryProvider) action,
  ) async {
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final ok = await action(libraryProvider);
    if (!mounted) return false;
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
      showMessage(context, libraryProvider.errorMessage ?? 'Failed');
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final today = todayIST();
    final late = loan.overdueOn(today);
    final fine = loan.fineOn(today);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget detail(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${loan.memberLabel} · ${loan.number}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (late > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fine > 0
                        ? 'Overdue by $late day${late == 1 ? '' : 's'} · '
                              'Fine ${fine.toRupees()}'
                        : 'Overdue by $late day${late == 1 ? '' : 's'} · '
                              'No fine',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              detail(Icons.qr_code_2_rounded, 'Barcode', loan.barcode),
              detail(
                Icons.event_available_rounded,
                'Issued',
                loan.issuedDate.toDisplayDay(),
              ),
              detail(Icons.event_rounded, 'Due', loan.dueDate.toDisplayDay()),
              detail(
                Icons.autorenew_rounded,
                'Renewals',
                '${loan.renewals} of ${loan.maxRenewals}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(controller: _remarks, label: 'Return remarks (optional)'),
        const SizedBox(height: 16),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        AppButton(
          label: 'Return book',
          onPressed: _busy ? null : () => _return('good'),
          leadingIcon: Icons.assignment_returned_rounded,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Damaged',
                onPressed: _busy ? null : () => _return('damaged'),
                variant: AppButtonVariant.outline,
                leadingIcon: Icons.heart_broken_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Renew',
                onPressed: _busy || !loan.canRenew
                    ? null
                    : () => _run(
                        (libraryProvider) => libraryProvider.renewLoan(loan.id),
                      ),
                variant: AppButtonVariant.outline,
                leadingIcon: Icons.autorenew_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AppButton(
          label: 'Mark as lost',
          onPressed: _busy ? null : _markLost,
          variant: AppButtonVariant.destructive,
          leadingIcon: Icons.report_gmailerrorred_rounded,
        ),
      ],
    );
  }

  Future<void> _return(String condition) async {
    final loan = widget.loan;
    final navigator = Navigator.of(context);
    final libraryProvider = context.read<LibraryProvider>();
    final fined = loan.fineOn(todayIST()) > 0;
    final ok = await _run(
      (libraryProvider) => libraryProvider.returnLoan({
        'id': loan.id,
        'condition': condition,
        'remarks': ?blankToNull(_remarks),
      }),
    );
    if (!ok || !fined || !navigator.mounted) return;
    // The server raises the overdue fine under this id; open it so it can be collected now.
    final fine = await libraryProvider.fine('${loan.id}__overdue');
    if (fine != null && navigator.mounted) {
      await FineDialog.show(navigator.context, fine);
    }
  }

  Future<void> _markLost() async {
    final reasonController = TextEditingController();
    final chargeController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark book lost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mark ${widget.loan.barcode} as lost for ${widget.loan.memberLabel}?',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: reasonController,
              label: 'Reason for loss',
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: chargeController,
              keyboardType: TextInputType.number,
              label: 'Replacement charge (₹)',
              hintText: 'Leave empty for book price',
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            variant: AppButtonVariant.ghost,
          ),
          AppButton(
            label: 'Confirm lost',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final charge = double.tryParse(chargeController.text.trim());
    await _run(
      (libraryProvider) => libraryProvider.markLoanLost({
        'id': widget.loan.id,
        'reason': ?blankToNull(reasonController),
        'charge': ?charge,
      }),
    );
  }
}
