import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/stock/item_picker.dart';
import 'package:inventory/inventory.dart';

/// One editable stock line. Controllers live here so the editor can rebuild freely.
class LineDraft {
  LineDraft(this.item, this.variant);

  final InvItem item;
  final InvVariant? variant;
  final qty = TextEditingController();
  final rejected = TextEditingController();
  final batchNo = TextEditingController();
  final expiry = TextEditingController();
  final cost = TextEditingController();

  void dispose() {
    for (final c in [qty, rejected, batchNo, expiry, cost]) {
      c.dispose();
    }
  }

  /// Request payload; only the fields the screen asked for are sent.
  Map<String, Object?> toMap({
    String qtyKey = 'qty',
    bool batch = false,
    bool receipt = false,
  }) {
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    return {
      'itemId': item.id,
      'variantId': ?variant?.id,
      qtyKey: double.tryParse(qty.text.trim()) ?? 0,
      if (receipt) 'qtyRejected': double.tryParse(rejected.text.trim()) ?? 0,
      if (receipt) 'unitCost': ?double.tryParse(cost.text.trim()),
      if (batch && item.tracking == Tracking.batch) ...{
        'batchNo': text(batchNo),
        'expiryDate': text(expiry),
      },
    };
  }
}

/// Add/remove item lines with quantity (and optionally receipt/batch fields).
class LineEditor extends StatelessWidget {
  const LineEditor({
    required this.lines,
    required this.onChanged,
    this.qtyLabel = 'Quantity',
    this.receipt = false,
    super.key,
  });

  final List<LineDraft> lines;
  final VoidCallback onChanged;
  final String qtyLabel;

  /// Show rejected quantity, unit cost, batch number and expiry.
  final bool receipt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (n, l) in lines.indexed)
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
                          lines.removeAt(n).dispose();
                          onChanged();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _num(l.qty, receipt ? 'Accepted' : qtyLabel),
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
                            controller: l.batchNo,
                            decoration: const InputDecoration(
                              labelText: 'Batch no.',
                            ),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Required' : null,
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
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: DateTime.now(),
                              );
                              if (d != null) {
                                l.expiry.text = d.toIso8601String().substring(
                                  0,
                                  10,
                                );
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
              lines.add(LineDraft(picked.item, picked.variant));
              onChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _num(TextEditingController c, String label) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) {
        return label == 'Rejected' || label == 'Unit cost' ? null : 'Required';
      }
      final n = double.tryParse(t);
      return n == null || n < 0 ? 'Invalid' : null;
    },
  );
}
