import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/stock/item_picker.dart';
import 'package:inventory/inventory.dart';

/// One editable stock line. Controllers live here so the editor can rebuild freely.
class LineDraft {
  LineDraft(this.item, this.variant);

  final InventoryItem item;
  final InventoryVariant? variant;
  final quantity = TextEditingController();
  final rejected = TextEditingController();
  final batchNumber = TextEditingController();
  final expiry = TextEditingController();
  final cost = TextEditingController();

  void dispose() {
    for (final controller in [quantity, rejected, batchNumber, expiry, cost]) {
      controller.dispose();
    }
  }

  /// Request payload; only the fields the screen asked for are sent.
  Map<String, Object?> toMap({
    String quantityKey = 'quantity',
    bool batch = false,
    bool receipt = false,
  }) {
    String? text(TextEditingController controller) =>
        controller.text.trim().isEmpty ? null : controller.text.trim();
    return {
      'itemId': item.id,
      'variantId': ?variant?.id,
      quantityKey: double.tryParse(quantity.text.trim()) ?? 0,
      if (receipt)
        'quantityRejected': double.tryParse(rejected.text.trim()) ?? 0,
      if (receipt) 'unitCost': ?double.tryParse(cost.text.trim()),
      if (batch && item.tracking == Tracking.batch) ...{
        'batchNumber': text(batchNumber),
        'expiryDate': text(expiry),
      },
    };
  }
}

/// Add/remove item lines with quantity (and optionally receipt/batch fields).
class LineEditor extends StatelessWidget {
  const LineEditor({
    required this.lineItems,
    required this.onChanged,
    this.quantityLabel = 'Quantity',
    this.receipt = false,
    super.key,
  });

  final List<LineDraft> lineItems;
  final VoidCallback onChanged;
  final String quantityLabel;

  /// Show rejected quantity, unit cost, batch number and expiry.
  final bool receipt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (n, l) in lineItems.indexed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.variant == null
                              ? l.item.name
                              : '${l.item.name} · ${l.variant!.sku}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          lineItems.removeAt(n).dispose();
                          onChanged();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _num(
                          l.quantity,
                          receipt ? 'Accepted' : quantityLabel,
                        ),
                      ),
                      if (receipt) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _num(l.rejected, 'Rejected')),
                        const SizedBox(width: 8),
                        Expanded(child: _num(l.cost, 'Unit cost')),
                      ],
                    ],
                  ),
                  if (receipt && l.item.tracking == Tracking.batch)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: l.batchNumber,
                            decoration: const InputDecoration(
                              labelText: 'Batch no.',
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: l.expiry,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Expiry',
                              suffixIcon: Icon(Icons.event_rounded),
                            ),
                            validator: (value) =>
                                (value ?? '').compareTo(
                                          DateTime.now()
                                              .toIso8601String()
                                              .substring(0, 10),
                                        ) <
                                        0 &&
                                    (value ?? '').isNotEmpty
                                ? 'Expired batches cannot be received'
                                : null,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                                initialDate: DateTime.now(),
                              );
                              if (date != null) {
                                l.expiry.text = date
                                    .toIso8601String()
                                    .substring(0, 10);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
            onPressed: () async {
              final picked = await pickItem(context);
              if (picked == null) return;
              lineItems.add(LineDraft(picked.item, picked.variant));
              onChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _num(TextEditingController controller, String label) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (currentValue) {
      final value = (currentValue ?? '').trim();
      if (value.isEmpty) {
        return label == 'Rejected' || label == 'Unit cost' ? null : 'Required';
      }
      final number = double.tryParse(value);
      return number == null || number < 0 ? 'Invalid' : null;
    },
  );
}
