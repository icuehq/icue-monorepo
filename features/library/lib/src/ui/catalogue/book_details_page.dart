import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_copies_section.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_details_cards.dart';
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
        appBar: AppBar(title: const Text('Book Details')),
        body: Center(
          child: _loaded
              ? const Text('Book not found')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final canEdit = libraryProvider.access.can('library.catalogue');
    final canCirculate = libraryProvider.access.can(
      'library.circulation.operate',
    );
    final categoryName = libraryProvider.category(book.categoryId)?.name;

    final isWide = context.isWide;
    final info = BookInfoCard(book: book);
    final description = BookDescriptionCard(book: book);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        actions: [
          if (canCirculate)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: 'Reserve book',
              onPressed: () => ReservationSheet.show(context, book: book),
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit book',
              onPressed: () async {
                await context.push(LibraryRoutes.libraryBookForm, extra: book);
                await _load();
              },
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 24 : 16,
          vertical: 16,
        ),
        children: [
          BookHeroCard(
            book: book,
            categoryName: categoryName,
            canEdit: canEdit,
            onActiveChanged: (value) async {
              if (await libraryProvider.setBookActive(book.id, active: value)) {
                await _load();
              } else if (context.mounted) {
                showMessage(context, libraryProvider.errorMessage ?? 'Failed');
              }
            },
          ),
          const SizedBox(height: 16),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: info),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: description),
              ],
            )
          else ...[
            info,
            const SizedBox(height: 16),
            description,
          ],
          BookCopiesSection(book: book),
        ],
      ),
    );
  }
}
