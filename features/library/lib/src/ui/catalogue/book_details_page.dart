import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_copies_section.dart';
import 'package:school_library/src/ui/reservations/widgets/reservation_sheet.dart';

class BookDetailsPage extends StatefulWidget {
  const BookDetailsPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  LibraryBook? _book;
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
    final libraryProvider = context.watch<LibraryProvider>();
    final book = _book;
    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Book')),
        body: Center(
          child: _loaded
              ? const Text('Book not found')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final canEdit = libraryProvider.access.can('library.catalogue.manage');
    final rows = <(String, String?)>[
      ('Subtitle', book.subtitle),
      ('Authors', book.authorLine),
      ('Category', libraryProvider.category(book.categoryId)?.name),
      ('ISBN-13', book.isbn13),
      ('ISBN-10', book.isbn10),
      ('Publisher', book.publisher),
      ('Edition', book.edition),
      ('Year', book.year?.toString()),
      ('Language', book.language),
      ('Pages', book.pages?.toString()),
      ('Classification no.', book.classificationNumber),
      ('Keywords', book.keywords.join(', ')),
      ('Description', book.description),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          if (libraryProvider.access.can('library.circulation.operate'))
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Reserve book',
              onPressed: () => ReservationSheet.show(context, book: book),
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push(LibraryRoutes.libraryBookForm, extra: book);
                await _load();
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          for (final row in rows)
            if (row.$2 != null && row.$2!.isNotEmpty)
              ListTile(
                dense: true,
                title: Text(row.$1),
                subtitle: Text(row.$2!),
              ),
          if (canEdit)
            SwitchListTile(
              title: const Text('Active'),
              value: book.active,
              onChanged: (value) async {
                if (await libraryProvider.setBookActive(
                  book.id,
                  active: value,
                )) {
                  await _load();
                } else if (context.mounted) {
                  showMessage(
                    context,
                    libraryProvider.errorMessage ?? 'Failed',
                  );
                }
              },
            ),
          BookCopiesSection(book: book),
        ],
      ),
    );
  }
}
