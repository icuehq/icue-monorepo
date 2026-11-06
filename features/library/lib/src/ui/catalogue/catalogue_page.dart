import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

class CataloguePage extends StatefulWidget {
  const CataloguePage({super.key, this.categoryId});

  final String? categoryId;

  @override
  State<CataloguePage> createState() => _CataloguePageState();
}

class _CataloguePageState extends State<CataloguePage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

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
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        libraryProvider.loadBooks(more: true);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final searching = libraryProvider.bookSearch.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue')),
      floatingActionButton:
          libraryProvider.access.can('library.catalogue')
          ? FloatingActionButton.extended(
              onPressed: () => context.push(LibraryRoutes.libraryBookForm),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Book'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => libraryProvider.loadBooks(search: value),
              decoration: InputDecoration(
                hintText: 'Search title, author, publisher or ISBN',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          libraryProvider.loadBooks(search: '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              isExpanded: true,
              value: libraryProvider.bookCategoryId,
              items: [
                const DropdownMenuItem(child: Text('All categories')),
                for (final category in libraryProvider.topCategories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) => libraryProvider.loadBooks(
                categoryId: value,
                clearCategory: value == null,
              ),
            ),
          ),
          Expanded(
            child: libraryProvider.books.isEmpty
                ? Center(
                    child: libraryProvider.booksLoading
                        ? const CircularProgressIndicator()
                        : Text(libraryProvider.errorMessage ?? 'No books'),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount:
                        libraryProvider.books.length +
                        (libraryProvider.hasMoreBooks ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == libraryProvider.books.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final book = libraryProvider.books[i];
                      return ListTile(
                        title: Text(book.title),
                        subtitle: Text(
                          '${book.authorLine} · '
                          '${libraryProvider.category(book.categoryId)?.name ?? '—'}',
                        ),
                        trailing: book.active
                            ? null
                            : const Text(
                                'Inactive',
                                style: TextStyle(color: Colors.grey),
                              ),
                        onTap: () => context.push(
                          '${LibraryRoutes.libraryBookDetails}?id=${book.id}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
