import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/inventory/widgets/scan_field.dart';
import 'package:icueadmin/features/library/widgets/copy_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Find a copy by scanning its label (accession number, barcode or RFID tag) and review acquisitions.
class CopiesPage extends StatefulWidget {
  const CopiesPage({super.key});

  @override
  State<CopiesPage> createState() => _CopiesPageState();
}

class _CopiesPageState extends State<CopiesPage> {
  late final Future<List<LibAcquisition>> _acquisitions = context
      .read<LibraryProvider>()
      .acquisitions();

  Future<void> _find(String code) async {
    final p = context.read<LibraryProvider>();
    final copy = await p.findCopy(code);
    if (!mounted) return;
    if (copy == null) {
      invSnack(context, 'No copy found for "$code"');
      return;
    }
    final book = await p.book(copy.catalogueId);
    if (!mounted) return;
    await CopySheet.show(context, copy, book?.title ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Copies & acquisitions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ScanField(
              hint: 'Scan or type accession no., barcode or RFID tag',
              onScan: _find,
              clearOnScan: true,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LibAcquisition>>(
              future: _acquisitions,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}'));
                }
                final rows = snap.data;
                if (rows == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No acquisitions yet. Add copies from a book.'),
                  );
                }
                return ListView(
                  children: [
                    for (final a in rows)
                      ListTile(
                        title: Text('${a.number} · ${a.qty} copies'),
                        subtitle: Text(
                          [
                            a.type,
                            p.library(a.libraryId)?.name,
                            a.vendorOrDonor,
                            a.date,
                          ].whereType<String>().join(' · '),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
