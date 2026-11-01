import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/routing/app_routes.dart';
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
    final p = context.read<LibraryProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (p.categories.isEmpty) await p.loadMasters();
      await p.loadBooks(
        search: '',
        categoryId: widget.categoryId,
        clearCategory: widget.categoryId == null,
      );
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) p.loadBooks(more: true);
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
    final p = context.watch<LibraryProvider>();
    final searching = p.bookSearch.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue')),
      floatingActionButton: p.access.can('lib.catalogue.manage')
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.libraryBookForm),
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
              onSubmitted: (v) => p.loadBooks(search: v),
              decoration: InputDecoration(
                hintText: 'Search title, author, publisher or ISBN',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          p.loadBooks(search: '');
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
              value: p.bookCategoryId,
              items: [
                const DropdownMenuItem(child: Text('All categories')),
                for (final c in p.topCategories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) =>
                  p.loadBooks(categoryId: v, clearCategory: v == null),
            ),
          ),
          Expanded(
            child: p.books.isEmpty
                ? Center(
                    child: p.booksLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No books'),
                  )
                : ListView.builder(
                    controller: _scroll,
                    itemCount: p.books.length + (p.hasMoreBooks ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == p.books.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final b = p.books[i];
                      return ListTile(
                        title: Text(b.title),
                        subtitle: Text(
                          '${b.authorLine} · '
                          '${p.category(b.categoryId)?.name ?? '—'}',
                        ),
                        trailing: b.active
                            ? null
                            : const Text(
                                'Inactive',
                                style: TextStyle(color: Colors.grey),
                              ),
                        onTap: () => context.push(
                          '${AppRoutes.libraryBookDetails}?id=${b.id}',
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
