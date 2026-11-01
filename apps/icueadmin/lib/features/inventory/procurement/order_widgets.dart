import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';

/// One editable quotation / PO line: item label, quantity and unit price.
class OrderLineInput {
  OrderLineInput(
    this.itemId,
    this.variantId,
    this.name, {
    String qty = '',
    String price = '',
    this.priceLocked = false,
  }) : qty = TextEditingController(text: qty),
       price = TextEditingController(text: price);

  final String itemId;
  final String? variantId;
  final String name;
  final bool priceLocked;
  final TextEditingController qty;
  final TextEditingController price;

  double get qtyValue => double.tryParse(qty.text.trim()) ?? 0;
  double get priceValue => double.tryParse(price.text.trim()) ?? 0;

  Map<String, Object?> toJson(String qtyKey) => {
    'itemId': itemId,
    'variantId': ?variantId,
    qtyKey: qtyValue,
    'unitPrice': priceValue,
  };

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class OrderLineCard extends StatelessWidget {
  const OrderLineCard({
    required this.line,
    required this.onChanged,
    this.onRemove,
    super.key,
  });

  final OrderLineInput line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  static const _num = TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onRemove,
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.qty,
                  keyboardType: _num,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  onChanged: (_) => onChanged(),
                  validator: (v) {
                    final q = double.tryParse((v ?? '').trim());
                    return q == null || q <= 0 ? 'Invalid' : null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: line.price,
                  readOnly: line.priceLocked,
                  keyboardType: _num,
                  decoration: InputDecoration(
                    labelText: line.priceLocked
                        ? 'Unit price (quoted)'
                        : 'Unit price',
                  ),
                  onChanged: (_) => onChanged(),
                  validator: optionalNumber,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Discount / tax / delivery amounts with the computed total underneath.
class OrderTotals extends StatelessWidget {
  const OrderTotals({
    required this.lines,
    required this.discount,
    required this.tax,
    required this.delivery,
    required this.onChanged,
    super.key,
  });

  final List<OrderLineInput> lines;
  final TextEditingController discount;
  final TextEditingController tax;
  final TextEditingController delivery;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    double v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
    final sub = lines.fold<double>(0, (n, l) => n + l.qtyValue * l.priceValue);
    final total = sub - v(discount) + v(tax) + v(delivery);
    Widget field(TextEditingController c, String label) => Expanded(
      child: TextFormField(
        controller: c,
        keyboardType: OrderLineCard._num,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => onChanged(),
        validator: optionalNumber,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 8,
          children: [
            field(discount, 'Discount'),
            field(tax, 'Tax'),
            field(delivery, 'Delivery'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Subtotal ${sub.toStringAsFixed(2)} · '
          'Total ${total.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

/// Read-only date field that opens a picker and writes `yyyy-MM-dd` into [c].
Widget dateField(
  BuildContext context,
  TextEditingController c,
  String label, {
  DateTime? first,
}) => TextFormField(
  controller: c,
  readOnly: true,
  decoration: InputDecoration(
    labelText: label,
    suffixIcon: const Icon(Icons.event_rounded),
  ),
  validator: requiredText,
  onTap: () async {
    final from = first ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: from,
      lastDate: from.add(const Duration(days: 730)),
      initialDate: from,
    );
    if (d != null) c.text = d.toIso8601String().substring(0, 10);
  },
);

String money(num n) => n.toStringAsFixed(2);
