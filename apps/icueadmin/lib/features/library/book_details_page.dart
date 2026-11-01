import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:icueadmin/features/library/widgets/book_copies_section.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class BookDetailsPage extends StatefulWidget {
  const BookDetailsPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  LibBook? _book;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final book = await context.read<LibraryProvider>().book(widget.bookId);
    if (!mounted) return;
    setState(() {
      _book = book;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final b = _book;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book')),
        body: Center(
          child: _loaded
              ? const Text('Book not found')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final canEdit = p.access.can('lib.catalogue.manage');
    final rows = <(String, String?)>[
      ('Subtitle', b.subtitle),
      ('Authors', b.authorLine),
      ('Category', p.category(b.categoryId)?.name),
      ('ISBN-13', b.isbn13),
      ('ISBN-10', b.isbn10),
      ('Publisher', b.publisher),
      ('Edition', b.edition),
      ('Year', b.year?.toString()),
      ('Language', b.language),
      ('Pages', b.pages?.toString()),
      ('Classification no.', b.classNo),
      ('Keywords', b.keywords.join(', ')),
      ('Description', b.description),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(b.title),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(AppRoutes.libraryBookForm, extra: b);
                await _load();
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          for (final r in rows)
            if (r.$2 != null && r.$2!.isNotEmpty)
              ListTile(dense: true, title: Text(r.$1), subtitle: Text(r.$2!)),
          if (canEdit)
            SwitchListTile(
              title: const Text('Active'),
              value: b.active,
              onChanged: (v) async {
                if (await p.setBookActive(b.id, active: v)) {
                  await _load();
                } else if (context.mounted) {
                  invSnack(context, p.errorMessage ?? 'Failed');
                }
              },
            ),
          BookCopiesSection(book: b),
        ],
      ),
    );
  }
}
