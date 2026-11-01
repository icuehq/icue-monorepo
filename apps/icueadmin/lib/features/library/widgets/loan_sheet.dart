import 'package:flutter/material.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// One active loan: renew it or take the book back (FRS 11.10–11.11).
class LoanSheet extends StatefulWidget {
  const LoanSheet({super.key, required this.loan, required this.title});

  final LibraryLoan loan;
  final String title;

  static Future<void> show(
    BuildContext context,
    LibraryLoan loan,
    String title,
  ) => showFormSheet(context, () => LoanSheet(loan: loan, title: title));

  @override
  State<LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends State<LoanSheet> {
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
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final late = loan.overdueOn(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${loan.accessionNumber} · ${loan.memberLabel} · ${loan.number}\n'
          'Issued ${loan.issuedDate} · due ${loan.dueDate}'
          '${late > 0 ? ' · $late day${late == 1 ? '' : 's'} overdue' : ''}\n'
          'Renewed ${loan.renewals} of ${loan.maxRenewals}',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remarks,
          decoration: const InputDecoration(labelText: 'Return remarks'),
        ),
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
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason for loss'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: chargeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Replacement charge (₹)',
                hintText: 'Leave empty for book price',
              ),
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
