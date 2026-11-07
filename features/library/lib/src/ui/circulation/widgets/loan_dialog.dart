import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

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

  Future<void> _run(
    Future<bool> Function(LibraryProvider libraryProvider) action,
  ) async {
    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final ok = await action(libraryProvider);
    if (!mounted) return;
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
      showMessage(context, libraryProvider.errorMessage ?? 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final today = todayIST();
    final late = loan.overdueOn(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${loan.accessionNumber} · ${loan.memberLabel} · ${loan.number}\n'
          'Issued ${loan.issuedDate.toDisplayDay()} · due ${loan.dueDate.toDisplayDay()}'
          '${late > 0 ? ' · $late day${late == 1 ? '' : 's'} overdue' : ''}\n'
          'Renewed ${loan.renewals} of ${loan.maxRenewals}',
        ),
        const SizedBox(height: 12),
        AppTextField(controller: _remarks, label: 'Return remarks'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      (libraryProvider) => libraryProvider.returnLoan({
                        'id': loan.id,
                        'condition': 'good',
                        'remarks': ?blankToNull(_remarks),
                      }),
                    ),
              child: const Text('Return'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      (libraryProvider) => libraryProvider.returnLoan({
                        'id': loan.id,
                        'condition': 'damaged',
                        'remarks': ?blankToNull(_remarks),
                      }),
                    ),
              child: const Text('Return damaged'),
            ),
            OutlinedButton(
              onPressed: _busy || !loan.canRenew
                  ? null
                  : () => _run(
                      (libraryProvider) => libraryProvider.renewLoan(loan.id),
                    ),
              child: const Text('Renew'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _markLost,
              child: const Text('Mark lost'),
            ),
          ],
        ),
      ],
    );
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
              'Mark ${widget.loan.accessionNumber} as lost for ${widget.loan.memberLabel}?',
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm lost'),
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
