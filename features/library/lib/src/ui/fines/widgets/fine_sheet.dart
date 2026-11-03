import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Detailed view of a fine with actions to waive or record payment.
class FineSheet extends StatefulWidget {
  const FineSheet({super.key, required this.fine});

  final LibraryFine fine;

  static Future<void> show(BuildContext context, LibraryFine fine) =>
      showFormSheet(context, () => FineSheet(fine: fine));

  @override
  State<FineSheet> createState() => _FineSheetState();
}

class _FineSheetState extends State<FineSheet> {
  bool _busy = false;

  Future<void> _waive() async {
    final amountController = TextEditingController(
      text: widget.fine.outstanding.toAmountText(),
    );
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waive fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Max waivable: ${widget.fine.outstanding.toRupees()}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount to waive (₹)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason for waiver'),
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
            child: const Text('Confirm waive'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0 || amount > widget.fine.outstanding) {
      showMessage(
        context,
        'Enter a valid waiver amount up to outstanding balance',
      );
      return;
    }
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      showMessage(context, 'A reason is required to waive a fine');
      return;
    }

    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final result = await libraryProvider.waiveFine({
      'id': widget.fine.id,
      'amount': amount,
      'reason': reason,
    });
    if (!mounted) return;
    if (result) {
      navigator.pop();
      showMessage(context, 'Fine waived successfully');
    } else {
      setState(() => _busy = false);
      showMessage(
        context,
        libraryProvider.errorMessage ?? 'Failed to waive fine',
      );
    }
  }

  Future<void> _recordPayment() async {
    final amountController = TextEditingController(
      text: widget.fine.outstanding.toAmountText(),
    );
    final refController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record fine payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Outstanding: ${widget.fine.outstanding.toRupees()}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Paid amount (₹)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: refController,
              decoration: const InputDecoration(
                labelText: 'Payment receipt / reference',
                hintText: 'e.g. REC-1234',
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
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0 || amount > widget.fine.outstanding) {
      showMessage(
        context,
        'Enter a valid payment amount up to outstanding balance',
      );
      return;
    }

    setState(() => _busy = true);
    final libraryProvider = context.read<LibraryProvider>();
    final navigator = Navigator.of(context);
    final result = await libraryProvider.setFinePayment({
      'id': widget.fine.id,
      'paidAmount': amount,
      'reference': ?blankToNull(refController),
    });
    if (!mounted) return;
    if (result) {
      navigator.pop();
      showMessage(context, 'Payment recorded successfully');
    } else {
      setState(() => _busy = false);
      showMessage(
        context,
        libraryProvider.errorMessage ?? 'Failed to record payment',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fine = widget.fine;
    final libraryProvider = context.watch<LibraryProvider>();
    final canWaive = libraryProvider.access.can('library.fines.waive');
    final canPay = libraryProvider.access.can('library.circulation.operate');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              fine.fineNumber,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Chip(
              label: Text(humanizeStatus(fine.status)),
              backgroundColor: fine.isOutstanding
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Member: ${fine.memberLabel}'),
        Text('Fine type: ${fineTypeLabel(fine.type)}'),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AmountCol(label: 'Total', value: fine.amount),
            _AmountCol(label: 'Waived', value: fine.waived),
            _AmountCol(label: 'Paid', value: fine.paid),
            _AmountCol(
              label: 'Outstanding',
              value: fine.outstanding,
              isError: fine.isOutstanding,
            ),
          ],
        ),
        if (fine.fineCalculation != null &&
            fine.fineCalculation!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Calculation: ${fine.fineCalculation}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (fine.waivers.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Waivers:', style: Theme.of(context).textTheme.labelMedium),
          for (final fineWaiver in fine.waivers)
            Text(
              '• ${fineWaiver.amount.toRupees()} on ${fineWaiver.performedAt?.toLocal().toNumericDateTime() ?? '-'} (${fineWaiver.reason})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (fine.payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Payments:', style: Theme.of(context).textTheme.labelMedium),
          for (final pay in fine.payments)
            Text(
              '• ${pay.amount.toRupees()} on ${pay.date?.toDisplayDay() ?? '-'} (${pay.reference ?? 'no ref'})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (fine.isOutstanding && (canWaive || canPay)) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (canWaive)
                FilledButton.tonal(
                  onPressed: _busy ? null : _waive,
                  child: const Text('Waive'),
                ),
              if (canWaive && canPay) const SizedBox(width: 8),
              if (canPay)
                FilledButton(
                  onPressed: _busy ? null : _recordPayment,
                  child: const Text('Record payment'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AmountCol extends StatelessWidget {
  const _AmountCol({
    required this.label,
    required this.value,
    this.isError = false,
  });

  final String label;
  final double value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value.toRupees(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isError ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}
