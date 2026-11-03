import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/widgets/copy_sheet.dart';

/// Find a copy by scanning its label (accession number, barcode or RFID tag) and review acquisitions.
class CopiesPage extends StatefulWidget {
  const CopiesPage({super.key});

  @override
  State<CopiesPage> createState() => _CopiesPageState();
}

class _CopiesPageState extends State<CopiesPage> {
  late final Future<List<LibraryAcquisition>> _acquisitions = context
      .read<LibraryProvider>()
      .acquisitions();

  Future<void> _find(String code) async {
    final libraryProvider = context.read<LibraryProvider>();
    final copy = await libraryProvider.findCopy(code);
    if (!mounted) return;
    if (copy == null) {
      showMessage(context, 'No copy found for "$code"');
      return;
    }
    final book = await libraryProvider.book(copy.catalogueId);
    if (!mounted) return;
    await CopySheet.show(context, copy, book?.title ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.read<LibraryProvider>();
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
            child: FutureBuilder<List<LibraryAcquisition>>(
              future: _acquisitions,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                final rows = snapshot.data;
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
                    for (final acquisition in rows)
                      ListTile(
                        title: Text(
                          '${acquisition.number} · ${acquisition.quantity} copies',
                        ),
                        subtitle: Text(
                          [
                            acquisition.type,
                            libraryProvider
                                .library(acquisition.libraryId)
                                ?.name,
                            acquisition.vendorOrDonor,
                            acquisition.date,
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
