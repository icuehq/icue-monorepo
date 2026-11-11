import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Inspection history of a purchase order: every delivery with its accepted / rejected quantities.
class PurchaseOrderReceiptsSection extends StatefulWidget {
  const PurchaseOrderReceiptsSection({required this.orderId, super.key});

  final String orderId;

  @override
  State<PurchaseOrderReceiptsSection> createState() =>
      _PurchaseOrderReceiptsSectionState();
}

class _PurchaseOrderReceiptsSectionState
    extends State<PurchaseOrderReceiptsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProcurementProvider>().loadReceipts(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final procurementProvider = context.watch<ProcurementProvider>();
    if (procurementProvider.receipts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Deliveries', style: Theme.of(context).textTheme.titleSmall),
        for (final goodsReceipt in procurementProvider.receipts)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${goodsReceipt.number} · ${goodsReceipt.date.toDisplayDay()}'
              '${goodsReceipt.reference == null ? '' : ' · ${goodsReceipt.reference}'}',
            ),
            subtitle: Text(
              [
                for (final goodsReceiptLine in goodsReceipt.lineItems)
                  '${procurementProvider.itemName(goodsReceiptLine.itemId)}: ${goodsReceiptLine.accepted.toQuantityText()} accepted'
                      '${goodsReceiptLine.rejected > 0 ? ', ${goodsReceiptLine.rejected.toQuantityText()} rejected' : ''}'
                      '${goodsReceiptLine.condition == null ? '' : ' (${goodsReceiptLine.condition})'}',
              ].join('\n'),
            ),
            trailing: Text(goodsReceipt.result),
          ),
      ],
    );
  }
}
