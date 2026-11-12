import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';

/// Confirmation dialog for marking a loan copy as lost.
/// Returns the loss reason and optional replacement charge, or `null` if cancelled.
class MarkLostDialog extends StatefulWidget {
  const MarkLostDialog({super.key, required this.loan});

  final LibraryLoan loan;

  static Future<({String? reason, double? charge})?> show(
    BuildContext context,
    LibraryLoan loan,
  ) => showDialog<({String? reason, double? charge})>(
    context: context,
    builder: (dialogContext) => MarkLostDialog(loan: loan),
  );

  @override
  State<MarkLostDialog> createState() => _MarkLostDialogState();
}

class _MarkLostDialogState extends State<MarkLostDialog> {
  final _reasonController = TextEditingController();
  final _chargeController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _chargeController.dispose();
    super.dispose();
  }

  void _confirm() {
    final chargeText = _chargeController.text.trim();
    double? charge;
    if (chargeText.isNotEmpty) {
      charge = double.tryParse(chargeText);
      if (charge == null || charge < 0) {
        showMessage(context, 'Enter a valid replacement amount');
        return;
      }
    }
    Navigator.of(context)
        .pop((reason: blankToNull(_reasonController), charge: charge));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loan = widget.loan;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report_gmailerrorred_rounded, color: colors.error),
          const SizedBox(width: 8),
          const Text('Mark Book Lost'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark "${loan.bookLabel}" (${loan.barcode}) as lost for ${loan.memberLabel}?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A replacement fine will be billed and the member will be temporarily blocked from borrowing.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            IcueTextField(
              controller: _reasonController,
              label: 'Reason for loss',
              hintText: 'e.g. Misplaced by student',
            ),
            const SizedBox(height: 10),
            IcueTextField(
              controller: _chargeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: 'Replacement charge (₹)',
              hintText: 'Leave empty for book catalog price',
            ),
          ],
        ),
      ),
      actions: [
        IcueButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: IcueButtonVariant.ghost,
        ),
        IcueButton(
          label: 'Confirm lost',
          onPressed: _confirm,
          variant: IcueButtonVariant.destructive,
        ),
      ],
    );
  }
}
