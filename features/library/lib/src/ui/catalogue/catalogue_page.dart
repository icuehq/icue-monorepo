import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_card.dart';
import 'package:school_library/src/ui/catalogue/widgets/catalogue_empty_states.dart';
import 'package:school_library/src/ui/catalogue/widgets/catalogue_filter_header.dart';
import 'package:school_library/src/ui/catalogue/widgets/catalogue_table.dart';

class CataloguePage extends StatefulWidget {
  const CataloguePage({super.key, this.categoryId});

  final String? categoryId;

  @override
  State<CataloguePage> createState() => _CataloguePageState();
}

class _CataloguePageState extends State<CataloguePage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final libraryProvider = context.read<LibraryProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (libraryProvider.categories.isEmpty) {
        await libraryProvider.loadMasters();
      }
      unawaited(libraryProvider.loadStandards());
      await libraryProvider.loadBooks(
        search: '',
        categoryId: widget.categoryId,
        clearCategory: widget.categoryId == null,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _open(LibraryBook book) =>
      context.push('${LibraryRoutes.libraryBookDetails}?id=${book.id}');

  void _clearFilters() {
    _searchController.clear();
    final libraryProvider = context.read<LibraryProvider>();
    libraryProvider.loadBooks(
      search: '',
      clearCategory: true,
      clearClass: true,
      clearStatus: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final isWide = context.isWide;
    final books = libraryProvider.books.items;
    final statusFilter = CatalogueStatusFilter.of(libraryProvider.bookStatus);
    void setStatus(CatalogueStatusFilter filter) => libraryProvider.loadBooks(
      status: filter.status,
      clearStatus: filter.status == null,
    );

    final isFiltered =
        libraryProvider.bookSearch.isNotEmpty ||
        libraryProvider.bookCategoryId != null ||
        libraryProvider.bookClassId != null ||
        libraryProvider.bookStatus != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Books Catalogue'),
        actions: [
          if (!isWide)
            IconButton(
              tooltip: 'Import books',
              icon: const Icon(Icons.upload_file_rounded),
              onPressed: () =>
                  context.pushNamed(LibraryRoutes.libraryBookImportName),
            ),
        ],
      ),
      floatingActionButton: !isWide
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.pushNamed(LibraryRoutes.libraryBookFormName),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Book'),
            )
          : null,
      body: isWide
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: CatalogueTable(
                books: books,
                statusFilter: statusFilter,
                onStatusChanged: setStatus,
                onOpen: _open,
                onClearFilters: _clearFilters,
              ),
            )
          : Column(
              children: [
                CatalogueFilterHeader(
                  searchController: _searchController,
                  selectedCategoryId: libraryProvider.bookCategoryId,
                  selectedClassId: libraryProvider.bookClassId,
                  standards: libraryProvider.standards,
                  statusFilter: statusFilter,
                  categories: libraryProvider.categories,
                  isWide: isWide,
                  totalCount: libraryProvider.books.total ?? books.length,
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
                  onClassChanged: (value) => libraryProvider.loadBooks(
                    classId: value,
                    clearClass: value == null,
                  ),
                  onStatusChanged: setStatus,
                  onAddBook: () =>
                      context.pushNamed(LibraryRoutes.libraryBookFormName),
                  onRefresh: () => libraryProvider.loadBooks(
                    search: _searchController.text.trim(),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: libraryProvider.books.loading && books.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : books.isEmpty
                      ? (!isFiltered
                            ? CatalogueInitialEmptyState(
                                onAdd: () => context.pushNamed(
                                  LibraryRoutes.libraryBookFormName,
                                ),
                              )
                            : CatalogueNoResultsState(
                                searchQuery: libraryProvider.bookSearch,
                                onClear: _clearFilters,
                              ))
                      : RefreshIndicator(
                          onRefresh: () => libraryProvider.loadBooks(
                            search: _searchController.text.trim(),
                          ),
                          child: IcueAdaptiveCardList(
                            padding: const EdgeInsets.all(12),
                            spacing: 8,
                            itemCount: books.length,
                            footer: IcueLoadMoreFooter.of(
                              libraryProvider.books,
                            ),
                            itemBuilder: (context, index) {
                              final book = books[index];
                              return BookCard(
                                book: book,
                                categoryName:
                                    libraryProvider
                                        .category(book.categoryId)
                                        ?.name ??
                                    '—',
                                classNames: [
                                  for (final classId in book.classIds)
                                    libraryProvider.className(classId),
                                ],
                                onTap: () => _open(book),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
