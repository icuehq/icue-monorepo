import 'package:core_ui/core_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds the PO PDF in the app and opens the print / share / save sheet (FRS 10.16).
Future<void> sharePurchaseOrderPdf(
  InventoryPurchaseOrder purchaseOrder, {
  required String vendor,
  required String Function(String itemId) itemName,
}) {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text(
          'Purchase Order ${purchaseOrder.number}',
          style: const pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Vendor: $vendor'),
        pw.Text(
          'Date: ${purchaseOrder.purchaseOrderDate.toDisplayDay()}   Expected delivery: ${purchaseOrder.expectedDate.toDisplayDay()}',
        ),
        pw.Text('Deliver to: Campus ${purchaseOrder.deliveryCampusId}'),
        if (purchaseOrder.revision > 0)
          pw.Text('Revision ${purchaseOrder.revision}'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Item', 'Qty', 'Unit price', 'Amount'],
          data: [
            for (final orderLine in purchaseOrder.lineItems)
              [
                itemName(orderLine.itemId),
                orderLine.quantity.toQuantityText(),
                orderLine.unitPrice.toAmountText(),
                (orderLine.quantity * orderLine.unitPrice).toAmountText(),
              ],
          ],
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 8),
        for (final (label, v) in [
          ('Subtotal', purchaseOrder.subtotal),
          ('Discount', -purchaseOrder.discount),
          ('Tax', purchaseOrder.tax),
          ('Delivery', purchaseOrder.delivery),
          ('Total', purchaseOrder.total),
        ])
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('$label: ${v.toAmountText()}'),
          ),
        if (purchaseOrder.terms != null && purchaseOrder.terms!.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Terms and conditions'),
          pw.Text(purchaseOrder.terms!),
        ],
        if (purchaseOrder.remarks != null && purchaseOrder.remarks!.isNotEmpty)
          pw.Text('Remarks: ${purchaseOrder.remarks}'),
      ],
    ),
  );
  return Printing.layoutPdf(
    name: '${purchaseOrder.number.replaceAll('/', '-')}.pdf',
    onLayout: (_) => doc.save(),
  );
}
