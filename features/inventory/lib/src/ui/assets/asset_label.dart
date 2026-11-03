import 'package:inventory/inventory.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Asset label with a QR code of the asset ID (FRS 10.19 barcode/QR); opens the print / share sheet.
Future<void> shareAssetLabel(InventoryAsset asset) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (_) => pw.Row(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: asset.assetId,
            width: 110,
            height: 110,
          ),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                asset.name,
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(asset.assetId),
              if (asset.serialNumber != null)
                pw.Text('S/N ${asset.serialNumber}'),
            ],
          ),
        ],
      ),
    ),
  );
  return Printing.layoutPdf(name: 'asset-label', onLayout: (_) => doc.save());
}
