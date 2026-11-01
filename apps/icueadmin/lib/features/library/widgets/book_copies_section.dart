import 'package:flutter/material.dart';
import 'package:icueadmin/features/library/widgets/acquisition_sheet.dart';
import 'package:icueadmin/features/library/widgets/copy_labels.dart';
import 'package:icueadmin/features/library/widgets/copy_sheet.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// Physical copies of a title (FRS 11.1 "view physical copies"), with add-copies for librarians.
class BookCopiesSection extends StatefulWidget {
  const BookCopiesSection({super.key, required this.book});

  final LibBook book;

  @override
  State<BookCopiesSection> createState() => _BookCopiesSectionState();
}

class _BookCopiesSectionState extends State<BookCopiesSection> {
  List<LibCopy>? _copies;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await context.read<LibraryProvider>().copiesOf(widget.book.id);
      if (mounted) setState(() => _copies = c);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _add() async {
    final ids = await AcquisitionSheet.show(context, widget.book);
    if (ids == null || !mounted) return;
    await _load();
    if (!mounted) return;
    final added = [
      for (final c in _copies ?? <LibCopy>[])
        if (ids.contains(c.accessionNo)) c,
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
    final p = context.watch<LibraryProvider>();
    final copies = _copies;
    final available = copies?.where((c) => c.status == 'available').length;
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
          trailing: p.access.can('lib.catalogue.manage') && widget.book.active
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
          for (final c in copies)
            ListTile(
              dense: true,
              title: Text(c.accessionNo),
              subtitle: Text(
                [
                  p.library(c.libraryId)?.name,
                  c.shelf,
                ].whereType<String>().join(' · '),
              ),
              trailing: Text(copyStatusLabel(c.status)),
              onTap: () async {
                await CopySheet.show(context, c, widget.book.title);
                await _load();
              },
            ),
      ],
    );
  }
}
