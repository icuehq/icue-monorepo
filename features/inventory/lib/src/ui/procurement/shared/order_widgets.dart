import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Digits with at most [places] decimals, for quantities and amounts.
List<TextInputFormatter> decimalOnly([int places = 2]) => [
  FilteringTextInputFormatter.allow(RegExp('^\\d*\\.?\\d{0,$places}\$')),
];

/// One editable quotation / PO line: item label, quantity and unit price.
class OrderLineInput {
  OrderLineInput(
    this.itemId,
    this.variantId,
    this.name, {
    String quantity = '',
    String price = '',
    this.priceLocked = false,
  }) : quantity = TextEditingController(text: quantity),
       price = TextEditingController(text: price);

  final String itemId;
  final String? variantId;
  final String name;
  final bool priceLocked;
  final TextEditingController quantity;
  final TextEditingController price;

  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get priceValue => double.tryParse(price.text.trim()) ?? 0;

  Map<String, Object?> toJson(String quantityKey) => {
    'itemId': itemId,
    'variantId': ?variantId,
    quantityKey: quantityValue,
    'unitPrice': priceValue,
  };

  void dispose() {
    quantity.dispose();
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
                child: AppTextField(
                  controller: line.quantity,
                  keyboardType: _num,
                  inputFormatters: decimalOnly(3),
                  onChanged: (_) => onChanged(),
                  validator: (value) {
                    final quantity = double.tryParse((value ?? '').trim());
                    return quantity == null || quantity <= 0 ? 'Invalid' : null;
                  },
                  label: 'Quantity',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: line.price,
                  readOnly: line.priceLocked,
                  keyboardType: _num,
                  inputFormatters: decimalOnly(),
                  onChanged: (_) => onChanged(),
                  validator: optionalNumber,
                  label: line.priceLocked
                      ? 'Unit price (quoted)'
                      : 'Unit price',
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
    required this.lineItems,
    required this.discount,
    required this.tax,
    required this.delivery,
    required this.onChanged,
    super.key,
  });

  final List<OrderLineInput> lineItems;
  final TextEditingController discount;
  final TextEditingController tax;
  final TextEditingController delivery;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    double v(TextEditingController controller) =>
        double.tryParse(controller.text.trim()) ?? 0;
    final sub = lineItems.fold<double>(
      0,
      (number, orderLineInput) =>
          number + orderLineInput.quantityValue * orderLineInput.priceValue,
    );
    final total = sub - v(discount) + v(tax) + v(delivery);
    Widget field(TextEditingController controller, String label) => Expanded(
      child: AppTextField(
        controller: controller,
        keyboardType: OrderLineCard._num,
        inputFormatters: decimalOnly(),
        onChanged: (_) => onChanged(),
        validator: optionalNumber,
        label: label,
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
          'Subtotal ${sub.toRupees()} · '
          'Total ${total.toRupees()}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

/// Read-only date field that opens a picker and writes `yyyy-MM-dd` into [controller].
Widget dateField(
  BuildContext context,
  TextEditingController controller,
  String label, {
  DateTime? first,
}) {
  final from = first ?? DateTime.now();
  return AppDateField(
    controller: controller,
    label: label,
    firstDate: from,
    lastDate: from.add(const Duration(days: 730)),
    initialDate: from,
    validator: requiredText,
  );
}
