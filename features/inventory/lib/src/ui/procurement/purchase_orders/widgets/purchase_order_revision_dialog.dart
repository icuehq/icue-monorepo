import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/shared/order_widgets.dart';
import 'package:provider/provider.dart';

Future<Map<String, Object?>?> showPurchaseOrderRevisionDialog(
  BuildContext context, {
  required InventoryPurchaseOrder order,
}) => showDialog<Map<String, Object?>>(
  context: context,
  builder: (_) => _RevisionDialog(order: order),
);

/// Owns its controllers so they outlive the dialog's closing animation.
class _RevisionDialog extends StatefulWidget {
  const _RevisionDialog({required this.order});

  final InventoryPurchaseOrder order;

  @override
  State<_RevisionDialog> createState() => _RevisionDialogState();
}

class _RevisionDialogState extends State<_RevisionDialog> {
  late final _prices = [
    for (final orderLine in widget.order.lineItems)
      TextEditingController(text: orderLine.unitPrice.toQuantityText()),
  ];
  final _reason = TextEditingController();
  late final _expected = TextEditingController(text: widget.order.expectedDate);

  @override
  void dispose() {
    for (final controller in [..._prices, _reason, _expected]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_reason.text.trim().isEmpty) return;
    Navigator.pop(context, <String, Object?>{
      'reason': _reason.text.trim(),
      'expectedDate': _expected.text,
      'prices': [
        for (final (index, orderLine) in widget.order.lineItems.indexed)
          {
            'itemId': orderLine.itemId,
            'variantId': orderLine.variantId,
            'unitPrice':
                double.tryParse(_prices[index].text.trim()) ??
                orderLine.unitPrice,
          },
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.read<ProcurementProvider>();
    return AlertDialog(
      title: Text('Revise ${widget.order.number}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            AppTextField(
              controller: _reason,
              label: 'Revision reason *',
              hintText: 'e.g. Price fluctuation / renegotiated terms',
            ),
            const SizedBox(height: 8),
            dateField(context, _expected, 'Expected delivery date'),
            const SizedBox(height: 8),
            for (final (index, orderLine) in widget.order.lineItems.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppTextField(
                  controller: _prices[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  label:
                      '${procurementProvider.itemName(orderLine.itemId)} unit price (₹)',
                ),
              ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
          variant: AppButtonVariant.ghost,
        ),
        AppButton(label: 'Save Revision', onPressed: _save),
      ],
    );
  }
}
