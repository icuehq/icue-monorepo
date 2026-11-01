import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Report as a PDF table (preview, print, share, save through the system dialog).
Future<void> shareReportPdf(
  String title,
  List<String> header,
  List<List<String>> rows,
) => Printing.layoutPdf(
  name: title,
  onLayout: (format) async {
    final doc = pw.Document()
      ..addPage(
        pw.MultiPage(
          pageFormat: format,
          build: (_) => [
            pw.Header(level: 0, child: pw.Text(title)),
            pw.TableHelper.fromTextArray(
              headers: header,
              data: rows,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: const pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    return doc.save();
  },
);
