import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/procurement/shared/order_widgets.dart';
import 'package:provider/provider.dart';

Future<Map<String, Object?>?> showPurchaseOrderRevisionDialog(
  BuildContext context, {
  required InventoryPurchaseOrder order,
}) async {
  final procurementProvider = context.read<ProcurementProvider>();
  final prices = [
    for (final orderLine in order.lineItems)
      TextEditingController(text: formatQuantity(orderLine.unitPrice)),
  ];
  final reason = TextEditingController();
  final expected = TextEditingController(text: order.expectedDate);

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Revise ${order.number}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Revision reason *',
                hintText: 'e.g. Price fluctuation / renegotiated terms',
              ),
            ),
            const SizedBox(height: 8),
            dateField(dialogContext, expected, 'Expected delivery date'),
            const SizedBox(height: 8),
            for (final (index, orderLine) in order.lineItems.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: prices[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '${procurementProvider.itemName(orderLine.itemId)} unit price (₹)',
                    isDense: true,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (reason.text.trim().isEmpty) return;
            Navigator.pop(dialogContext, true);
          },
          child: const Text('Save Revision'),
        ),
      ],
    ),
  );

  final data = <String, Object?>{
    'reason': reason.text.trim(),
    'expectedDate': expected.text,
    'prices': [
      for (final (index, orderLine) in order.lineItems.indexed)
        {
          'itemId': orderLine.itemId,
          'unitPrice':
              double.tryParse(prices[index].text.trim()) ?? orderLine.unitPrice,
        },
    ],
  };

  for (final controller in [...prices, reason, expected]) {
    controller.dispose();
  }

  if (ok == true) {
    return data;
  }
  return null;
}
