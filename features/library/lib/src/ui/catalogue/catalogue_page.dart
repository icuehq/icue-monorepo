import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_card.dart';
import 'package:school_library/src/ui/catalogue/widgets/catalogue_empty_states.dart';
import 'package:school_library/src/ui/catalogue/widgets/catalogue_filter_header.dart';
import 'package:school_library/src/ui/reservations/widgets/reservation_sheet.dart';

class CataloguePage extends StatefulWidget {
  const CataloguePage({super.key, this.categoryId});

  final String? categoryId;

  @override
  State<CataloguePage> createState() => _CataloguePageState();
}

class _CataloguePageState extends State<CataloguePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  var _statusFilter = CatalogueStatusFilter.all;

  @override
  void initState() {
    super.initState();
    final libraryProvider = context.read<LibraryProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (libraryProvider.categories.isEmpty) {
        await libraryProvider.loadMasters();
      }
      await libraryProvider.loadBooks(
        search: '',
        categoryId: widget.categoryId,
        clearCategory: widget.categoryId == null,
      );
    });
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 300) {
        libraryProvider.loadBooks(more: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _open(LibraryBook book) =>
      context.push('${LibraryRoutes.libraryBookDetails}?id=${book.id}');

  void _clearFilters() {
    _searchController.clear();
    final libraryProvider = context.read<LibraryProvider>();
    setState(() => _statusFilter = CatalogueStatusFilter.all);
    libraryProvider.loadBooks(search: '', clearCategory: true);
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final canEdit = libraryProvider.access.can('library.catalogue');
    final canCirculate = libraryProvider.access.can(
      'library.circulation.operate',
    );
    final theme = Theme.of(context);
    final isWide = context.isWide;
    final allBooks = libraryProvider.books;

    final filteredBooks = allBooks.where((book) {
      return switch (_statusFilter) {
        CatalogueStatusFilter.all => true,
        CatalogueStatusFilter.active => book.active,
        CatalogueStatusFilter.inactive => !book.active,
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload catalogue',
            onPressed: () => libraryProvider.loadBooks(
              search: _searchController.text.trim(),
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit && !isWide
          ? FloatingActionButton.extended(
              onPressed: () => context.push(LibraryRoutes.libraryBookForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Book'),
            )
          : null,
      body: Column(
        children: [
          CatalogueFilterHeader(
            searchController: _searchController,
            selectedCategoryId: libraryProvider.bookCategoryId,
            statusFilter: _statusFilter,
            categories: libraryProvider.categories,
            isWide: isWide,
            canEdit: canEdit,
            totalCount: filteredBooks.length,
            onSearchSubmitted: (value) =>
                libraryProvider.loadBooks(search: value.trim()),
            onClearSearch: () {
              _searchController.clear();
              libraryProvider.loadBooks(search: '');
            },
            onCategoryChanged: (value) => libraryProvider.loadBooks(
              categoryId: value,
              clearCategory: value == null,
            ),
            onStatusChanged: (filter) => setState(() => _statusFilter = filter),
            onAddBook: () => context.push(LibraryRoutes.libraryBookForm),
            onRefresh: () => libraryProvider.loadBooks(
              search: _searchController.text.trim(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: libraryProvider.booksLoading && allBooks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Loading catalogue...'),
                      ],
                    ),
                  )
                : filteredBooks.isEmpty
                ? (allBooks.isEmpty &&
                          libraryProvider.bookSearch.isEmpty &&
                          libraryProvider.bookCategoryId == null
                      ? CatalogueInitialEmptyState(
                          canEdit: canEdit,
                          onAdd: () =>
                              context.push(LibraryRoutes.libraryBookForm),
                        )
                      : CatalogueNoResultsState(
                          searchQuery: libraryProvider.bookSearch,
                          onClear: _clearFilters,
                        ))
                : RefreshIndicator(
                    onRefresh: () => libraryProvider.loadBooks(
                      search: _searchController.text.trim(),
                    ),
                    child: AdaptiveList<LibraryBook>(
                      fillWidth: true,
                      controller: _scrollController,
                      items: filteredBooks,
                      onTap: _open,
                      columns: [
                        AdaptiveColumn(
                          label: 'Title',
                          flex: 4,
                          cell: (context, book) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.16,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      book.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (book.subtitle != null &&
                                        book.subtitle!.isNotEmpty)
                                      Text(
                                        book.subtitle!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else if (book.isbn13 != null &&
                                        book.isbn13!.isNotEmpty)
                                      Text(
                                        'ISBN: ${book.isbn13}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AdaptiveColumn(
                          label: 'Author',
                          flex: 2,
                          cell: (context, book) => Text(
                            book.authorLine.isNotEmpty ? book.authorLine : '—',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        AdaptiveColumn(
                          label: 'Category',
                          flex: 2,
                          cell: (context, book) {
                            final catName =
                                libraryProvider
                                    .category(book.categoryId)
                                    ?.name ??
                                '—';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    catName,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (book.classificationNumber != null &&
                                    book.classificationNumber!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Class: ${book.classificationNumber}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        AdaptiveColumn(
                          label: 'Publisher',
                          flex: 2,
                          cell: (context, book) {
                            final hasPub =
                                book.publisher != null &&
                                book.publisher!.isNotEmpty;
                            final yearStr = book.year != null
                                ? ' (${book.year})'
                                : '';
                            return Text(
                              hasPub
                                  ? '${book.publisher}$yearStr'
                                  : (yearStr.isNotEmpty ? yearStr.trim() : '—'),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        AdaptiveColumn(
                          label: 'Status',
                          cell: (context, book) {
                            final active = book.active;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: (active ? Colors.green : Colors.grey)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (active ? Colors.green : Colors.grey)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    active
                                        ? Icons.check_circle_rounded
                                        : Icons.block_rounded,
                                    size: 11,
                                    color: active
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    active ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: active
                                          ? Colors.green.shade800
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        AdaptiveColumn(
                          label: '',
                          alignment: Alignment.centerRight,
                          cell: (context, book) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canCirculate)
                                IconButton(
                                  icon: const Icon(
                                    Icons.bookmark_add_outlined,
                                    size: 18,
                                  ),
                                  tooltip: 'Reserve book',
                                  onPressed: () => ReservationSheet.show(
                                    context,
                                    book: book,
                                  ),
                                ),
                              if (canEdit)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  tooltip: 'Edit book',
                                  onPressed: () => context.push(
                                    LibraryRoutes.libraryBookForm,
                                    extra: book,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                ),
                                tooltip: 'View details',
                                onPressed: () => _open(book),
                              ),
                            ],
                          ),
                        ),
                      ],
                      cardBuilder: (context, book) => BookCard(
                        book: book,
                        categoryName:
                            libraryProvider.category(book.categoryId)?.name ??
                            '—',
                        canEdit: canEdit,
                        canCirculate: canCirculate,
                        onTap: () => _open(book),
                      ),
                      footer: libraryProvider.hasMoreBooks
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
