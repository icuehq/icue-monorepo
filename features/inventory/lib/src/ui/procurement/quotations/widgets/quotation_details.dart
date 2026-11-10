import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';

/// Lines, charges and terms of one quotation, shown on its card.
class QuotationDetails extends StatelessWidget {
  const QuotationDetails({
    required this.quotation,
    required this.itemName,
    super.key,
  });

  final InventoryQuotation quotation;
  final String Function(String itemId) itemName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: muted)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        row('Quotation date', quotation.quotationDate.toDisplayDay()),
        row('Valid until', quotation.validUntil.toDisplayDay()),
        row(
          'Delivery lead time',
          quotation.deliveryDays == null
              ? 'Not specified'
              : '${quotation.deliveryDays} days',
        ),
        const SizedBox(height: 8),
        for (final line in quotation.lineItems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName(line.itemId),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${line.quantity.toQuantityText()} × ${line.unitPrice.toRupees()}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                Text(
                  (line.quantity * line.unitPrice).toRupees(),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        const Divider(height: 20),
        row('Subtotal', quotation.subtotal.toRupees()),
        if (quotation.discount != 0)
          row('Discount', '- ${quotation.discount.toRupees()}'),
        if (quotation.tax != 0) row('Tax', quotation.tax.toRupees()),
        if (quotation.delivery != 0)
          row('Delivery charges', quotation.delivery.toRupees()),
        row('Total', quotation.total.toRupees(), bold: true),
        if (quotation.remarks != null && quotation.remarks!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Remarks: ${quotation.remarks}', style: muted),
        ],
      ],
    );
  }
}
