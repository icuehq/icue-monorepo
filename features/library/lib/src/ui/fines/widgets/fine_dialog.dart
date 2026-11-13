import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Detailed view of a fine with actions to waive or record payment.
class FineDialog extends StatefulWidget {
  const FineDialog({super.key, required this.fine});

  final LibraryFine fine;

  static Future<void> show(BuildContext context, LibraryFine fine) =>
      showDialog<void>(
        context: context,
        builder: (_) => FineDialog(fine: fine),
      );

  @override
  State<FineDialog> createState() => _FineDialogState();
}

class _FineDialogState extends State<FineDialog> {
  bool _busy = false;

  Future<void> _waive() async {
    final amountController = TextEditingController(
      text: widget.fine.outstanding.toAmountText(),
    );
    final reasonController = TextEditingController();
    final ok = await _ask(
      title: 'Waive fine',
      confirmLabel: 'Confirm waive',
      description: 'Maximum waivable: ${widget.fine.outstanding.toRupees()}',
      fields: [
        IcueTextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          label: 'Amount to waive (₹)',
        ),
        IcueTextField(controller: reasonController, label: 'Reason for waiver'),
      ],
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
    final navigator = Navigator.of(context, rootNavigator: true);
    final result = await libraryProvider.waiveFine(
      id: widget.fine.id,
      amount: amount,
      reason: reason,
    );
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
    final ok = await _ask(
      title: 'Record fine payment',
      confirmLabel: 'Record payment',
      description: 'Outstanding: ${widget.fine.outstanding.toRupees()}',
      fields: [
        IcueTextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          label: 'Paid amount (₹)',
        ),
        IcueTextField(
          controller: refController,
          label: 'Payment receipt / reference',
          hintText: 'e.g. REC-1234',
        ),
      ],
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
    final navigator = Navigator.of(context, rootNavigator: true);
    final result = await libraryProvider.setFinePayment(
      id: widget.fine.id,
      amount: amount,
      reference: blankToNull(refController),
    );
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

  Future<bool> _ask({
    required String title,
    required String confirmLabel,
    required String description,
    required List<Widget> fields,
  }) async {
    void close(bool value) =>
        Navigator.of(context, rootNavigator: true).pop(value);
    final ok = await IcueDialog.show<bool>(
      context,
      title: title,
      description: description,
      size: IcueDialogSize.small,
      content: Column(
        children: [
          for (final field in fields) ...[field, const SizedBox(height: 12)],
        ],
      ),
      secondaryAction: IcueDialogAction(
        label: 'Cancel',
        variant: IcueButtonVariant.ghost,
        onPressed: () => close(false),
      ),
      primaryAction: IcueDialogAction(
        label: confirmLabel,
        onPressed: () => close(true),
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final fine = widget.fine;
    final theme = Theme.of(context);
    final calculation = fine.calculationLabel;
    final raisedAt = fine.createdAt?.toLocal().toNumericDateTime();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: LibraryStatusChip(fine.status),
        ),
        const SizedBox(height: 12),
        _Detail('Book', fine.bookTitle ?? '-'),
        if (fine.barcode != null) _Detail('Barcode', fine.barcode!),
        _Detail('Member', fine.memberLabel),
        if (raisedAt != null) _Detail('Raised on', raisedAt),
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
        if (calculation != null) ...[
          const SizedBox(height: 12),
          Text(calculation, style: theme.textTheme.bodySmall),
        ],
        if (fine.waivers.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Waivers', style: theme.textTheme.labelLarge),
          for (final fineWaiver in fine.waivers)
            Text(
              '${fineWaiver.amount.toRupees()} on ${fineWaiver.performedAt?.toLocal().toNumericDateTime() ?? '-'} (${fineWaiver.reason})',
              style: theme.textTheme.bodySmall,
            ),
        ],
        if (fine.payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Payments', style: theme.textTheme.labelLarge),
          for (final pay in fine.payments)
            Text(
              '${pay.amount.toRupees()} on ${pay.date?.toDisplayDay() ?? '-'} (${pay.reference ?? 'no reference'})',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ],
    );

    return IcueDialog(
      title: '${fineTypeLabel(fine.type)} fine',
      size: IcueDialogSize.large,
      content: content,
      secondaryAction: fine.isOutstanding
          ? IcueDialogAction(
              label: 'Waive',
              variant: IcueButtonVariant.outline,
              onPressed: _busy ? null : _waive,
            )
          : null,
      primaryAction: fine.isOutstanding
          ? IcueDialogAction(
              label: 'Record payment',
              isLoading: _busy,
              onPressed: _busy ? null : _recordPayment,
            )
          : IcueDialogAction(
              label: 'Close',
              variant: IcueButtonVariant.ghost,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
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
