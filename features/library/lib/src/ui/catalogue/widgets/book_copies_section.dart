import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/add_copies_form.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_dialog.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_labels.dart';
import 'package:school_library/src/ui/shared/library_status_chip.dart';

/// Physical copies of a title (FRS 11.1 "view physical copies"), .
class BookCopiesSection extends StatefulWidget {
  const BookCopiesSection({super.key, required this.book});

  final LibraryBook book;

  @override
  State<BookCopiesSection> createState() => _BookCopiesSectionState();
}

class _BookCopiesSectionState extends State<BookCopiesSection> {
  List<LibraryCopy>? _copies;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final copies = await context.read<LibraryProvider>().copiesOf(
        widget.book.id,
      );
      if (mounted) setState(() => _copies = copies);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final copies = _copies ?? const <LibraryCopy>[];
    String libraryName(LibraryCopy copy) =>
        libraryProvider.library(copy.libraryId)?.name ?? copy.libraryId;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      // Bounded height: rows scroll under the header and the footer stays at the bottom.
      child: SizedBox(
        height: 520,
        child: IcueClientTable<LibraryCopy>(
          title: 'Physical copies',
          items: copies,
          rowKey: (copy) => copy.id,
          rowLabel: (copy) => copy.barcode,
          searchText: (copy) =>
              '${copy.barcode} ${libraryName(copy)} ${copy.shelf ?? ''}',
          searchHint: 'Search barcode, library, or shelf...',
          status: IcueTableStatus.of(
            failed: _error != null,
            loading: _copies == null && _error == null,
          ),
          errorMessage: _error,
          onRetry: _load,
          filters: [
            IcueClientFilter<LibraryCopy>(
              id: 'status',
              label: 'Status',
              options: [
                for (final status in CopyStatus.values)
                  IcueTableFilterOption(status, humanizeStatus(status)),
              ],
              matches: (copy, status) => copy.status == status,
            ),
          ],
          columns: [
            IcueTableColumn<LibraryCopy>(
              id: 'barcode',
              label: 'Barcode',
              sortable: true,
              comparator: (copy) => copy.barcode,
              cellBuilder: (context, copy) => Text(copy.barcode),
            ),
            IcueTableColumn<LibraryCopy>(
              id: 'library',
              label: 'Library',
              cellBuilder: (context, copy) => Text(libraryName(copy)),
            ),
            IcueTableColumn<LibraryCopy>(
              id: 'shelf',
              label: 'Shelf',
              cellBuilder: (context, copy) => Text(copy.shelf ?? '—'),
            ),
            IcueTableColumn<LibraryCopy>(
              id: 'condition',
              label: 'Condition',
              cellBuilder: (context, copy) =>
                  Text(humanizeStatus(copy.condition)),
            ),
            IcueTableColumn<LibraryCopy>(
              id: 'status',
              label: 'Status',
              sortable: true,
              comparator: (copy) => copy.status,
              cellBuilder: (context, copy) => LibraryStatusChip(copy.status),
            ),
          ],
          onRowTap: (copy) async {
            await CopyDialog.show(context, copy, widget.book.title);
            await _load();
          },
          primaryAction: IcueTableAction(
            label: 'Copies',
            icon: Icons.add_rounded,
            onPressed: () async {
              await AddCopiesForm.show(context, widget.book);
              await _load();
            },
          ),
          secondaryAction: copies.isEmpty
              ? null
              : IcueTableAction(
                  label: 'Print labels',
                  icon: Icons.print_outlined,
                  onPressed: () => shareCopyLabels(widget.book.title, [
                    for (final copy in copies)
                      (barcode: copy.barcode, shelf: copy.shelf),
                  ]),
                ),
          emptyTitle: 'No physical copies registered yet',
        ),
      ),
    );
  }
}
