import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Thermal roll label, one per page. Change here if the school's roll differs.
const labelFormat = PdfPageFormat(
  50 * PdfPageFormat.mm,
  25 * PdfPageFormat.mm,
  marginAll: 2 * PdfPageFormat.mm,
);

/// A copy's barcode and shelf, as printed on its label.
typedef CopyLabel = ({String barcode, String? shelf});

/// One Code 128 label per copy (FRS 11.5); opens the print / share sheet.
Future<void> shareCopyLabels(String title, List<CopyLabel> labels) {
  final doc = pw.Document();
  for (final label in labels) {
    doc.addPage(
      pw.Page(
        pageFormat: labelFormat,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              title,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: const pw.TextStyle(fontSize: 6),
            ),
            pw.SizedBox(height: 1),
            pw.Expanded(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: label.barcode,
                textStyle: const pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (label.shelf != null)
              pw.Text(
                label.shelf!,
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 5),
              ),
          ],
        ),
      ),
    );
  }
  return Printing.layoutPdf(
    name: 'book-labels',
    format: labelFormat,
    onLayout: (_) => doc.save(),
  );
}
