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
        IcueToast.warning(context, 'Enter a valid replacement amount');
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
    final member = loan.memberName ?? 'the member';

    return IcueDialog(
      title: 'Mark Book Lost',
      icon: Icons.report_gmailerrorred_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.bookTitle ?? 'This book',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Borrowed by $member',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$member will be charged a replacement fine for this book.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ],
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            label: 'Replacement charge (₹)',
            hintText: 'Leave empty for book catalog price',
          ),
        ],
      ),
      secondaryAction: IcueDialogAction(
        label: 'Cancel',
        variant: IcueButtonVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      primaryAction: IcueDialogAction(
        label: 'Confirm lost',
        variant: IcueButtonVariant.destructive,
        onPressed: _confirm,
      ),
    );
  }
}
