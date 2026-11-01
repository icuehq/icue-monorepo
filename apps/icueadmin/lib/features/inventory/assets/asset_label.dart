import 'package:inventory/inventory.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Asset label with a QR code of the asset ID (FRS 10.19 barcode/QR); opens the print / share sheet.
Future<void> shareAssetLabel(InvAsset a) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (_) => pw.Row(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: a.assetId,
            width: 110,
            height: 110,
          ),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                a.name,
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(a.assetId),
              if (a.serialNo != null) pw.Text('S/N ${a.serialNo}'),
            ],
          ),
        ],
      ),
    ),
  );
  return Printing.layoutPdf(name: 'asset-label', onLayout: (_) => doc.save());
}
