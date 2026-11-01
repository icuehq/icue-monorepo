import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:school_library/school_library.dart';

/// One label per copy: QR code of the accession number (FRS 11.5); opens the print / share sheet.
Future<void> shareCopyLabels(String title, List<LibCopy> copies) {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in copies)
              pw.Container(
                width: 170,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: c.barcode ?? c.accessionNo,
                      width: 56,
                      height: 56,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            title,
                            maxLines: 2,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            c.accessionNo,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (c.shelf != null)
                            pw.Text(
                              c.shelf!,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  return Printing.layoutPdf(name: 'book-labels', onLayout: (_) => doc.save());
}
