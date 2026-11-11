import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/catalogue_filter_header.dart';

/// Wide-screen catalogue: books as an [IcueTable]. Search, category and class
/// are server-side (the provider reloads); status filters the loaded books.
class CatalogueTable extends StatelessWidget {
  const CatalogueTable({
    required this.books,
    required this.scrollController,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onOpen,
    required this.onClearFilters,
    super.key,
  });

  final List<LibraryBook> books;
  final ScrollController scrollController;
  final CatalogueStatusFilter statusFilter;
  final ValueChanged<CatalogueStatusFilter> onStatusChanged;
  final void Function(LibraryBook book) onOpen;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final categories = [
      ...provider.topCategories,
      ...provider.categories.where((category) => category.parentId != null),
    ];
    void addBook() => context.pushNamed(LibraryRoutes.libraryBookFormName);

    return IcueTable<LibraryBook>(
      title: 'Books Catalogue',
      rows: books,
      rowKey: (book) => book.id,
      rowLabel: (book) => book.title,
      scrollController: scrollController,
      countLabel: provider.hasMoreBooks ? '${books.length}+' : null,
      count: books.length,
      status: IcueTableStatus.of(
        failed: false,
        loading: provider.booksLoading && provider.books.isEmpty,
      ),
      onRowTap: onOpen,
      searchHint: 'Search title, author, or publisher...',
      initialSearch: provider.bookSearch,
      searchDebounce: const Duration(milliseconds: 400),
      onSearchChanged: (query) => provider.loadBooks(search: query.trim()),
      filters: [
        IcueTableFilter(
          id: 'category',
          label: 'Category',
          options: [
            for (final category in categories)
              IcueTableFilterOption(category.id, category.name),
          ],
          value:
              categories.any(
                (category) => category.id == provider.bookCategoryId,
              )
              ? provider.bookCategoryId
              : null,
          onChanged: (value) => provider.loadBooks(
            categoryId: value,
            clearCategory: value == null,
          ),
        ),
        IcueTableFilter(
          id: 'class',
          label: 'Class',
          options: [
            for (final standard in provider.standards)
              IcueTableFilterOption('${standard.id}', standard.name),
          ],
          value:
              provider.standards.any(
                (standard) => standard.id == provider.bookClassId,
              )
              ? '${provider.bookClassId}'
              : null,
          onChanged: (value) => provider.loadBooks(
            classId: value == null ? null : int.parse(value),
            clearClass: value == null,
          ),
        ),
        IcueTableFilter(
          id: 'status',
          label: 'Status',
          options: [
            for (final filter in CatalogueStatusFilter.values)
              if (filter != CatalogueStatusFilter.all)
                IcueTableFilterOption(filter.name, filter.label),
          ],
          value: statusFilter == CatalogueStatusFilter.all
              ? null
              : statusFilter.name,
          onChanged: (value) => onStatusChanged(
            value == null
                ? CatalogueStatusFilter.all
                : CatalogueStatusFilter.values.byName(value),
          ),
        ),
      ],
      isFiltered:
          provider.bookSearch.isNotEmpty ||
          provider.bookCategoryId != null ||
          provider.bookClassId != null ||
          statusFilter != CatalogueStatusFilter.all,
      onClearFilters: onClearFilters,
      secondaryAction: IcueTableAction(
        label: 'Import',
        icon: Icons.upload_file_rounded,
        onPressed: () => context.pushNamed(LibraryRoutes.libraryBookImportName),
      ),
      primaryAction: IcueTableAction(
        label: 'Book',
        icon: Icons.add_rounded,
        onPressed: addBook,
      ),
      emptyTitle: 'No books yet',
      emptyMessage: 'Add your first book to start the catalogue.',
      emptyAction: IcueTableAction(
        label: 'Add book',
        icon: Icons.add_rounded,
        onPressed: addBook,
      ),
      rowActions: (book) => [
        IcueTableRowAction(
          label: 'Edit',
          icon: Icons.edit_outlined,
          inline: true,
          onPressed: (book) =>
              context.pushNamed(LibraryRoutes.libraryBookFormName, extra: book),
        ),
      ],
      columns: [
        IcueTableColumn(
          id: 'title',
          label: 'Title',
          flex: 4,
          minWidth: 220,
          cellBuilder: (context, book) => IcueTableCellText(
            book.title,
            subtitle: (book.subtitle ?? '').isEmpty ? null : book.subtitle,
          ),
        ),
        IcueTableColumn(
          id: 'author',
          label: 'Author',
          flex: 2,
          cellBuilder: (context, book) => IcueTableCellText(
            book.authorLine.isEmpty ? '—' : book.authorLine,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'classes',
          label: 'Classes',
          hideBelowWidth: 1000,
          cellBuilder: (context, book) => IcueTableCellText(
            book.classIds.isEmpty
                ? 'All'
                : book.classIds.map(provider.className).join(', '),
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'category',
          label: 'Category',
          flex: 2,
          cellBuilder: (context, book) => IcueTableCellText(
            provider.category(book.categoryId)?.name ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'publisher',
          label: 'Publisher',
          flex: 2,
          hideBelowWidth: 1100,
          cellBuilder: (context, book) {
            final publisher = book.publisher ?? '';
            final year = book.year == null ? '' : '${book.year}';
            return IcueTableCellText(
              [
                publisher,
                year,
              ].where((part) => part.isNotEmpty).join(' · ').ifEmpty('—'),
              style: IcueTableStyle.of(context).secondary,
            );
          },
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          width: 110,
          cellBuilder: (context, book) => _StatusPill(active: book.active),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green.shade700 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
