import 'package:icueadmin/features/inventory/procurement/order_widgets.dart';
import 'package:inventory/inventory.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds the PO PDF in the app and opens the print / share / save sheet (FRS 10.16).
Future<void> sharePoPdf(
  InvPurchaseOrder po, {
  required String vendor,
  required String Function(String itemId) itemName,
}) {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text(
          'Purchase Order ${po.number}',
          style: const pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Vendor: $vendor'),
        pw.Text('Date: ${po.poDate}   Expected delivery: ${po.expectedDate}'),
        pw.Text('Deliver to: Campus ${po.deliveryCampusId}'),
        if (po.revision > 0) pw.Text('Revision ${po.revision}'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Item', 'Qty', 'Unit price', 'Amount'],
          data: [
            for (final l in po.lines)
              [
                itemName(l.itemId),
                fmtQty(l.qty),
                money(l.unitPrice),
                money(l.qty * l.unitPrice),
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
          ('Subtotal', po.subtotal),
          ('Discount', -po.discount),
          ('Tax', po.tax),
          ('Delivery', po.delivery),
          ('Total', po.total),
        ])
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('$label: ${money(v)}'),
          ),
        if (po.terms != null && po.terms!.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Terms and conditions'),
          pw.Text(po.terms!),
        ],
        if (po.remarks != null && po.remarks!.isNotEmpty)
          pw.Text('Remarks: ${po.remarks}'),
      ],
    ),
  );
  return Printing.layoutPdf(
    name: '${po.number.replaceAll('/', '-')}.pdf',
    onLayout: (_) => doc.save(),
  );
}
