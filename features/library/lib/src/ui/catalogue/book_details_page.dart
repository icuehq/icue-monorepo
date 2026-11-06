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

  Widget _infoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(
    BuildContext context,
    LibraryBook book,
    String? categoryName,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final libraryProvider = context.read<LibraryProvider>();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (book.subtitle != null &&
                          book.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          book.subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (book.authorLine.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 15,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                book.authorLine,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (categoryName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (book.isbn13 != null && book.isbn13!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ISBN: ${book.isbn13}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Active in catalogue',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Switch(
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
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
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

    final metadata = <(IconData, String, String?)>[
      (Icons.tag_rounded, 'ISBN-13', book.isbn13),
      (Icons.tag_rounded, 'ISBN-10', book.isbn10),
      (Icons.business_outlined, 'Publisher', book.publisher),
      (Icons.event_outlined, 'Publication Year', book.year?.toString()),
      (Icons.auto_stories_outlined, 'Edition', book.edition),
      (Icons.translate_outlined, 'Language', book.language),
      (Icons.library_books_outlined, 'Pages', book.pages?.toString()),
      (
        Icons.format_list_numbered_rounded,
        'Classification No.',
        book.classificationNumber,
      ),
    ];

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
      body: CenteredBody(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _heroCard(context, book, categoryName, canEdit),

            // Metadata Card
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
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
                          Icons.info_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bibliographic Information',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isTwoColumn = constraints.maxWidth >= 500;
                        final activeRows = [
                          for (final item in metadata)
                            if (item.$3 != null && item.$3!.isNotEmpty) item,
                        ];

                        if (isTwoColumn) {
                          return Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              for (final item in activeRows)
                                SizedBox(
                                  width: (constraints.maxWidth - 20) / 2,
                                  child: _infoItem(
                                    context,
                                    icon: item.$1,
                                    label: item.$2,
                                    value: item.$3!,
                                  ),
                                ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            for (final item in activeRows)
                              _infoItem(
                                context,
                                icon: item.$1,
                                label: item.$2,
                                value: item.$3!,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Description and Keywords Card
            if ((book.description != null && book.description!.isNotEmpty) ||
                book.keywords.isNotEmpty)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
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
                            Icons.description_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Description & Keywords',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (book.description != null &&
                          book.description!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          book.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (book.keywords.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final keyword in book.keywords)
                              Chip(
                                label: Text(keyword),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Copies Section
            BookCopiesSection(book: book),
          ],
        ),
      ),
    );
  }
}
