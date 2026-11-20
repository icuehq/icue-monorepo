import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Read-only details of a fine.
class FineDialog extends StatelessWidget {
  const FineDialog({super.key, required this.fine});

  final LibraryFine fine;

  static Future<void> show(BuildContext context, LibraryFine fine) =>
      showDialog<void>(
        context: context,
        builder: (_) => FineDialog(fine: fine),
      );

  @override
  Widget build(BuildContext context) {
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
      ],
    );

    return IcueDialog(
      title: '${fineTypeLabel(fine.type)} fine',
      size: IcueDialogSize.large,
      content: content,
      primaryAction: IcueDialogAction(
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
