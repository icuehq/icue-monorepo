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
      unawaited(libraryProvider.loadStandards());
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
    libraryProvider.loadBooks(
      search: '',
      clearCategory: true,
      clearClass: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final isWide = context.isWide;
    final allBooks = libraryProvider.books;

    final filteredBooks = allBooks.where((book) {
      return switch (_statusFilter) {
        CatalogueStatusFilter.all => true,
        CatalogueStatusFilter.active => book.active,
        CatalogueStatusFilter.inactive => !book.active,
      };
    }).toList();

    final isFiltered =
        libraryProvider.bookSearch.isNotEmpty ||
        libraryProvider.bookCategoryId != null ||
        libraryProvider.bookClassId != null;

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
                books: filteredBooks,
                scrollController: _scrollController,
                statusFilter: _statusFilter,
                onStatusChanged: (filter) =>
                    setState(() => _statusFilter = filter),
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
                  statusFilter: _statusFilter,
                  categories: libraryProvider.categories,
                  isWide: isWide,
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
                  onClassChanged: (value) => libraryProvider.loadBooks(
                    classId: value,
                    clearClass: value == null,
                  ),
                  onStatusChanged: (filter) =>
                      setState(() => _statusFilter = filter),
                  onAddBook: () =>
                      context.pushNamed(LibraryRoutes.libraryBookFormName),
                  onRefresh: () => libraryProvider.loadBooks(
                    search: _searchController.text.trim(),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: libraryProvider.booksLoading && allBooks.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filteredBooks.isEmpty
                      ? (allBooks.isEmpty && !isFiltered
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
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            spacing: 8,
                            itemCount:
                                filteredBooks.length +
                                (libraryProvider.hasMoreBooks ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredBooks.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final book = filteredBooks[index];
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
