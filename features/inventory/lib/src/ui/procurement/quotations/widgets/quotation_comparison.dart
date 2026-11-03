import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';

/// Unit prices, totals and lead time of every quotation side by side.
class QuotationComparison extends StatelessWidget {
  const QuotationComparison({
    required this.quotations,
    required this.itemIds,
    required this.vendorName,
    required this.itemName,
    super.key,
  });

  final List<InventoryQuotation> quotations;
  final List<String> itemIds;
  final String Function(String vendorId) vendorName;
  final String Function(String itemId) itemName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = itemIds;
    final lowestTotal = quotations
        .map((quotation) => quotation.total)
        .reduce((a, b) => a < b ? a : b);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Price Comparison Table',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                horizontalMargin: 8,
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                ),
                columns: [
                  const DataColumn(
                    label: Text(
                      'Item / Metric',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final quotation in quotations)
                    DataColumn(
                      label: Text(
                        vendorName(quotation.vendorId),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: quotation.selected
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                ],
                rows: [
                  for (final id in items)
                    DataRow(
                      cells: [
                        DataCell(Text(itemName(id))),
                        for (final quotation in quotations)
                          DataCell(
                            Text(
                              quotation.lineItems
                                  .where((line) => line.itemId == id)
                                  .map((line) => line.unitPrice.toRupees())
                                  .join(),
                            ),
                          ),
                      ],
                    ),
                  DataRow(
                    cells: [
                      const DataCell(
                        Text(
                          'Total Amount',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      for (final quotation in quotations)
                        DataCell(
                          Text(
                            quotation.total.toRupees(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: quotation.total == lowestTotal
                                  ? Colors.green[800]
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  DataRow(
                    cells: [
                      const DataCell(Text('Delivery Lead Time')),
                      for (final quotation in quotations)
                        DataCell(
                          Text(
                            quotation.deliveryDays != null
                                ? '${quotation.deliveryDays} days'
                                : 'Not specified',
                          ),
                        ),
                    ],
                  ),
                  DataRow(
                    cells: [
                      const DataCell(Text('Validity')),
                      for (final quotation in quotations)
                        DataCell(Text(quotation.validUntil)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
