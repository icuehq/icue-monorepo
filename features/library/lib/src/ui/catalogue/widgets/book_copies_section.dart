import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/acquisition_sheet.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_labels.dart';
import 'package:school_library/src/ui/catalogue/widgets/copy_sheet.dart';

/// Physical copies of a title (FRS 11.1 "view physical copies"), with add-copies for librarians.
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

  Future<void> _add() async {
    final ids = await AcquisitionSheet.show(context, widget.book);
    if (ids == null || !mounted) return;
    await _load();
    if (!mounted) return;
    final added = [
      for (final copy in _copies ?? <LibraryCopy>[])
        if (ids.contains(copy.accessionNumber)) copy,
    ];
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Added ${ids.first} – ${ids.last}'),
          action: SnackBarAction(
            label: 'Print labels',
            onPressed: () => shareCopyLabels(widget.book.title, added),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final copies = _copies;
    final available = copies
        ?.where((copy) => copy.status == 'available')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        ListTile(
          title: Text(
            copies == null
                ? 'Copies'
                : 'Copies (${copies.length}, $available available)',
          ),
          trailing:
              libraryProvider.access.can('library.catalogue') &&
                  widget.book.active
              ? FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add copies'),
                  onPressed: _add,
                )
              : null,
        ),
        if (_error != null)
          ListTile(title: Text(_error!))
        else if (copies == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (copies.isEmpty)
          const ListTile(dense: true, title: Text('No copies yet'))
        else
          for (final copy in copies)
            ListTile(
              dense: true,
              title: Text(copy.accessionNumber),
              subtitle: Text(
                [
                  libraryProvider.library(copy.libraryId)?.name,
                  copy.shelf,
                ].whereType<String>().join(' · '),
              ),
              trailing: Text(humanizeStatus(copy.status)),
              onTap: () async {
                await CopySheet.show(context, copy, widget.book.title);
                await _load();
              },
            ),
      ],
    );
  }
}
