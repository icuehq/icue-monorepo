import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/libraries/widgets/library_category_dialog.dart';

/// Wide-screen categories list: an [IcueClientTable] with each top-level
/// category followed by its subcategories.
class LibraryCategoriesTable extends StatelessWidget {
  const LibraryCategoriesTable({
    required this.categories,
    required this.onToggleActive,
    super.key,
  });

  final List<LibraryCategory> categories;
  final void Function(LibraryCategory category) onToggleActive;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final category in categories) category.id: category};
    final topLevel = categories
        .where(
          (category) =>
              category.parentId == null || !byId.containsKey(category.parentId),
        )
        .toList();
    final rows = [
      for (final top in topLevel) ...[
        top,
        ...categories.where((category) => category.parentId == top.id),
      ],
    ];

    return IcueClientTable<LibraryCategory>(
      title: 'Book categories',
      items: rows,
      rowKey: (category) => category.id,
      rowLabel: (category) => category.name,
      searchHint: 'Search categories...',
      searchText: (category) =>
          '${category.name} ${category.description ?? ''}',
      initialPageSize: 25,
      onRowTap: (category) =>
          LibraryCategoryDialog.show(context, category: category),
      primaryAction: IcueTableAction(
        label: 'Category',
        icon: Icons.add_rounded,
        onPressed: () => LibraryCategoryDialog.show(context),
      ),
      filters: [
        IcueClientFilter<LibraryCategory>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('active', 'Active'),
            IcueTableFilterOption('inactive', 'Inactive'),
          ],
          matches: (category, optionId) =>
              (optionId == 'active') == category.active,
        ),
        IcueClientFilter<LibraryCategory>(
          id: 'level',
          label: 'Level',
          options: const [
            IcueTableFilterOption('top', 'Categories'),
            IcueTableFilterOption('sub', 'Subcategories'),
          ],
          matches: (category, optionId) =>
              (optionId == 'sub') == byId.containsKey(category.parentId),
        ),
      ],
      rowActions: (category) => [
        IcueTableRowAction(
          label: 'View books',
          icon: Icons.menu_book_outlined,
          inline: true,
          onPressed: (row) => context.push(
            '${LibraryRoutes.libraryCatalogue}?category=${row.id}',
          ),
        ),
        IcueTableRowAction(
          label: 'Edit',
          icon: Icons.edit_outlined,
          inline: true,
          onPressed: (row) =>
              LibraryCategoryDialog.show(context, category: row),
        ),
        if (!byId.containsKey(category.parentId))
          IcueTableRowAction(
            label: 'Add subcategory',
            icon: Icons.subdirectory_arrow_right_rounded,
            onPressed: (row) =>
                LibraryCategoryDialog.show(context, parentId: row.id),
          ),
        IcueTableRowAction(
          label: category.active ? 'Deactivate' : 'Activate',
          icon: category.active
              ? Icons.block_outlined
              : Icons.check_circle_outline_rounded,
          destructive: category.active,
          onPressed: onToggleActive,
        ),
      ],
      columns: [
        IcueTableColumn(
          id: 'name',
          label: 'Category',
          flex: 3,
          minWidth: 220,
          hideable: false,
          cellBuilder: (context, category) {
            final isSub = byId.containsKey(category.parentId);
            return IcueTableCellText(
              category.name,
              style: isSub ? IcueTableStyle.of(context).secondary : null,
              leading: isSub
                  ? Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 16,
                      color: IcueTableStyle.of(context).inkMuted,
                    )
                  : null,
            );
          },
        ),
        IcueTableColumn(
          id: 'parent',
          label: 'Parent',
          flex: 2,
          cellBuilder: (context, category) => IcueTableCellText(
            byId[category.parentId]?.name ?? '—',
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'description',
          label: 'Description',
          flex: 3,
          hideBelowWidth: 900,
          cellBuilder: (context, category) => IcueTableCellText(
            (category.description ?? '').isEmpty ? '—' : category.description!,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'status',
          label: 'Status',
          width: 110,
          cellBuilder: (context, category) => category.active
              ? Text('Active', style: IcueTableStyle.of(context).secondary)
              : const IcueInactiveBadge(),
        ),
      ],
    );
  }
}
