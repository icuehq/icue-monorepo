import 'package:inventory/inventory.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Thermal roll label, one per page; the same size as the Library book labels.
const _labelFormat = PdfPageFormat(
  50 * PdfPageFormat.mm,
  25 * PdfPageFormat.mm,
  marginAll: 2 * PdfPageFormat.mm,
);

/// One Code 128 label of the asset ID (FRS 10.19 barcode); opens the print / share sheet.
Future<void> shareAssetLabel(InventoryAsset asset) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: _labelFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            asset.name,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: const pw.TextStyle(fontSize: 6),
          ),
          pw.SizedBox(height: 1),
          pw.Expanded(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: asset.id,
              textStyle: const pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          if (asset.serialNumber != null)
            pw.Text(
              'S/N ${asset.serialNumber}',
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 5),
            ),
        ],
      ),
    ),
  );
  return Printing.layoutPdf(
    name: 'asset-label',
    format: _labelFormat,
    onLayout: (_) => doc.save(),
  );
}
