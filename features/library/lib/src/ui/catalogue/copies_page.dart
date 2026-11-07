import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/acquisition_card.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_dialog.dart';
import 'package:school_library/src/ui/routing/library_destinations.dart';
import 'package:school_library/src/ui/routing/library_tab_bar.dart';

/// Find a copy by scanning its label (accession number, barcode or RFID tag) and review acquisitions.
class CopiesPage extends StatefulWidget {
  const CopiesPage({super.key});

  @override
  State<CopiesPage> createState() => _CopiesPageState();
}

class _CopiesPageState extends State<CopiesPage> {
  late Future<List<LibraryAcquisition>> _acquisitions;

  @override
  void initState() {
    super.initState();
    _loadAcquisitions();
  }

  void _loadAcquisitions() {
    setState(() {
      _acquisitions = context.read<LibraryProvider>().acquisitions();
    });
  }

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
    await CopyDialog.show(context, copy, book?.title ?? '');
  }

  Widget _scannerCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Copy Lookup & Barcode Scanner',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Scan or type any accession number, barcode, or RFID tag to view copy details, status, and shelf location.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ScanField(
              hint: 'Scan or type accession no., barcode, or RFID tag…',
              onScan: _find,
              clearOnScan: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copies & Acquisitions'),
        actions: [
          IconButton(
            tooltip: 'Refresh acquisitions',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAcquisitions,
          ),
        ],
        bottom: const LibraryTabBar(
          tabs: libraryCatalogueTabs,
          activePath: LibraryRoutes.libraryCopies,
        ),
      ),
      body: CenteredBody(
        child: Column(
          children: [
            _scannerCard(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Acquisitions Log',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LibraryAcquisition>>(
                future: _acquisitions,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error loading acquisitions: ${snapshot.error}',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    );
                  }
                  final rows = snapshot.data;
                  if (rows == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 36,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No acquisitions recorded yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add physical copies to any book in the Catalogue to record a new acquisition.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return AdaptiveList<LibraryAcquisition>(
                    items: rows,
                    columns: [
                      AdaptiveColumn(
                        label: 'Acquisition #',
                        flex: 2,
                        cell: (context, acquisition) => Text(
                          acquisition.number,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AdaptiveColumn.text(
                        'Library',
                        (acquisition) =>
                            libraryProvider
                                .library(acquisition.libraryId)
                                ?.name ??
                            acquisition.libraryId,
                        flex: 2,
                      ),
                      AdaptiveColumn(
                        label: 'Copies',
                        cell: (context, acquisition) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${acquisition.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      AdaptiveColumn.text(
                        'Vendor / Donor',
                        (acquisition) => acquisition.vendorOrDonor ?? '—',
                        flex: 2,
                      ),
                      AdaptiveColumn.text(
                        'Date',
                        (acquisition) =>
                            acquisition.date?.toDisplayDay() ?? '—',
                      ),
                      AdaptiveColumn(
                        label: 'Total Cost',
                        cell: (context, acquisition) => Text(
                          acquisition.price > 0
                              ? acquisition.price.toRupees()
                              : '—',
                          style: TextStyle(
                            fontWeight: acquisition.price > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                    cardBuilder: (context, acquisition) => AcquisitionCard(
                      acquisition: acquisition,
                      libraryName:
                          libraryProvider
                              .library(acquisition.libraryId)
                              ?.name ??
                          acquisition.libraryId,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
