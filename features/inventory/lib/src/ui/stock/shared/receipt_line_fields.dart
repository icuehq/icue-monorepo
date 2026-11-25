import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/stock/shared/line_editor.dart';
import 'package:inventory/src/ui/stock/shared/stock_validators.dart';

/// Quantity, unit cost and batch fields of one received item, with the line
/// total underneath.
class ReceiptLineFields extends StatelessWidget {
  const ReceiptLineFields({required this.lineDraft, super.key});

  final LineDraft lineDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = lineDraft.item;
    final unit = item.stockUnit;
    final isAsset = item.tracking == Tracking.asset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: IcueTextField(
                controller: lineDraft.quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: isAsset
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : quantityFormatters,
                validator: isAsset ? validateWholeQuantity : validateQuantity,
                label: isAsset ? 'How many received' : 'Quantity',
                hintText: '0',
                icon: Icons.numbers_rounded,
                suffixText: unit.isEmpty ? null : unit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: IcueTextField(
                controller: lineDraft.cost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: amountFormatters,
                validator: validateAmount,
                label: isAsset
                    ? 'Cost of each (optional)'
                    : 'Unit cost (optional)',
                hintText: '0.00',
                icon: Icons.currency_rupee_rounded,
                helperText: unit.isEmpty ? 'Per unit' : 'Per $unit',
              ),
            ),
          ],
        ),
        if (isAsset) ...[
          const SizedBox(height: 8),
          Text(
            'Each one is added as an unregistered asset. Register it with its '
            'details in Asset management.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (item.tracking == Tracking.batch) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IcueTextField(
                  controller: lineDraft.batchNumber,
                  maxLength: 50,
                  validator: validateRequiredText,
                  label: 'Batch number',
                  icon: Icons.qr_code_2_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IcueDateField(
                  controller: lineDraft.expiry,
                  label: 'Expiry date',
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  validator: (value) {
                    final date = value ?? '';
                    return date.isNotEmpty && date.compareTo(todayIST()) < 0
                        ? 'Expired batches cannot be received'
                        : null;
                  },
                ),
              ),
            ],
          ),
        ],
        ListenableBuilder(
          listenable: Listenable.merge([lineDraft.quantity, lineDraft.cost]),
          builder: (context, _) {
            final quantity = double.tryParse(lineDraft.quantity.text.trim());
            final cost = double.tryParse(lineDraft.cost.text.trim());
            if (quantity == null ||
                quantity <= 0 ||
                cost == null ||
                cost <= 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text.rich(
                  TextSpan(
                    text: 'Line total  ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: (quantity * cost).toRupees(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A whole number of 1 or more (assets are counted one by one).
String? validateWholeQuantity(String? text) {
  final value = int.tryParse((text ?? '').trim());
  return value == null || value < 1 ? 'Enter a whole number' : null;
}
