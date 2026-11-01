import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/lib_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Detailed view of a fine with actions to waive or record payment.
class FineSheet extends StatefulWidget {
  const FineSheet({super.key, required this.fine});

  final LibFine fine;

  static Future<void> show(BuildContext context, LibFine fine) =>
      showInvSheet(context, () => FineSheet(fine: fine));

  @override
  State<FineSheet> createState() => _FineSheetState();
}

class _FineSheetState extends State<FineSheet> {
  bool _busy = false;

  Future<void> _waive() async {
    final amountController = TextEditingController(
      text: widget.fine.outstanding.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Waive fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Max waivable: ₹${widget.fine.outstanding.toStringAsFixed(2)}',
            ),
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm waive'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0 || amount > widget.fine.outstanding) {
      invSnack(
        context,
        'Enter a valid waiver amount up to outstanding balance',
      );
      return;
    }
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      invSnack(context, 'A reason is required to waive a fine');
      return;
    }

    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    final nav = Navigator.of(context);
    final res = await p.waiveFine({
      'id': widget.fine.id,
      'amount': amount,
      'reason': reason,
    });
    if (!mounted) return;
    if (res) {
      nav.pop();
      invSnack(context, 'Fine waived successfully');
    } else {
      setState(() => _busy = false);
      invSnack(context, p.errorMessage ?? 'Failed to waive fine');
    }
  }

  Future<void> _recordPayment() async {
    final amountController = TextEditingController(
      text: widget.fine.outstanding.toStringAsFixed(2),
    );
    final refController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record fine payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Outstanding: ₹${widget.fine.outstanding.toStringAsFixed(2)}'),
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0 || amount > widget.fine.outstanding) {
      invSnack(
        context,
        'Enter a valid payment amount up to outstanding balance',
      );
      return;
    }

    setState(() => _busy = true);
    final p = context.read<LibraryProvider>();
    final nav = Navigator.of(context);
    final res = await p.setFinePayment({
      'id': widget.fine.id,
      'paidAmount': amount,
      'reference': ?blankToNull(refController),
    });
    if (!mounted) return;
    if (res) {
      nav.pop();
      invSnack(context, 'Payment recorded successfully');
    } else {
      setState(() => _busy = false);
      invSnack(context, p.errorMessage ?? 'Failed to record payment');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fine;
    final p = context.watch<LibraryProvider>();
    final canWaive = p.access.can('lib.fines.waive');
    final canPay = p.access.can('lib.circulation.operate');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(f.fineNumber, style: Theme.of(context).textTheme.titleMedium),
            Chip(
              label: Text(fineStatusLabel(f.status)),
              backgroundColor: f.isOutstanding
                  ? Theme.of(context).colorScheme.errorContainer
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Member: ${f.memberLabel}'),
        Text('Fine type: ${fineTypeLabel(f.type)}'),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AmountCol(label: 'Total', value: f.amount),
            _AmountCol(label: 'Waived', value: f.waived),
            _AmountCol(label: 'Paid', value: f.paid),
            _AmountCol(
              label: 'Outstanding',
              value: f.outstanding,
              isError: f.isOutstanding,
            ),
          ],
        ),
        if (f.calc != null && f.calc!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Calculation: ${f.calc}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (f.waivals.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Waivers:', style: Theme.of(context).textTheme.labelMedium),
          for (final w in f.waivals)
            Text(
              '• ₹${w.amount.toStringAsFixed(2)} on ${w.at} (${w.reason})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (f.payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Payments:', style: Theme.of(context).textTheme.labelMedium),
          for (final pay in f.payments)
            Text(
              '• ₹${pay.amount.toStringAsFixed(2)} on ${pay.date ?? '-'} (${pay.reference ?? 'no ref'})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        if (f.isOutstanding && (canWaive || canPay)) ...[
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
          '₹${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isError ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}
