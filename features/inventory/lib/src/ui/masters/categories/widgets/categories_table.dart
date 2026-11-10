import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/categories/widgets/category_dialog.dart';

/// Wide-screen categories list: an [IcueClientTable] with each top-level
/// category followed by its subcategories.
class CategoriesTable extends StatelessWidget {
  const CategoriesTable({
    required this.categories,
    required this.canEdit,
    required this.onToggleActive,
    super.key,
  });

  final List<InventoryCategory> categories;
  final bool canEdit;
  final void Function(InventoryCategory category) onToggleActive;

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

    return IcueClientTable<InventoryCategory>(
      title: 'Categories',
      items: rows,
      rowKey: (category) => category.id,
      rowLabel: (category) => category.name,
      searchHint: 'Search name, code or description...',
      searchText: (category) =>
          '${category.name} ${category.code} ${category.description ?? ''}',
      initialPageSize: 25,
      onRowTap: canEdit
          ? (category) => CategoryDialog.show(context, category: category)
          : null,
      primaryAction: canEdit
          ? IcueTableAction(
              label: 'Category',
              icon: Icons.add_rounded,
              onPressed: () => CategoryDialog.show(context),
            )
          : null,
      emptyTitle: 'No categories yet',
      emptyMessage: 'Add a category to start organising items.',
      emptyAction: canEdit
          ? IcueTableAction(
              label: 'Add category',
              icon: Icons.add_rounded,
              onPressed: () => CategoryDialog.show(context),
            )
          : null,
      filters: [
        IcueClientFilter<InventoryCategory>(
          id: 'status',
          label: 'Status',
          options: const [
            IcueTableFilterOption('active', 'Active'),
            IcueTableFilterOption('inactive', 'Inactive'),
          ],
          matches: (category, optionId) =>
              (optionId == 'active') == category.active,
        ),
        IcueClientFilter<InventoryCategory>(
          id: 'tracking',
          label: 'Tracking',
          options: [
            for (final tracking in Tracking.values)
              IcueTableFilterOption(tracking.name, tracking.label),
          ],
          matches: (category, optionId) =>
              category.suggestedTracking.name == optionId,
        ),
      ],
      rowActions: (category) => [
        IcueTableRowAction(
          label: 'View items',
          icon: Icons.category_outlined,
          inline: true,
          onPressed: (row) => context.push(
            '${InventoryRoutes.inventoryItems}?category=${row.id}',
          ),
        ),
        if (canEdit) ...[
          IcueTableRowAction(
            label: 'Edit',
            icon: Icons.edit_outlined,
            inline: true,
            onPressed: (row) => CategoryDialog.show(context, category: row),
          ),
          if (!byId.containsKey(category.parentId))
            IcueTableRowAction(
              label: 'Add subcategory',
              icon: Icons.subdirectory_arrow_right_rounded,
              onPressed: (row) =>
                  CategoryDialog.show(context, parentId: row.id),
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
          id: 'code',
          label: 'Code',
          cellBuilder: (context, category) => IcueTableCellText(
            category.code,
            style: IcueTableStyle.of(context).secondary,
          ),
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
          id: 'tracking',
          label: 'Tracking',
          cellBuilder: (context, category) => IcueTableCellText(
            category.suggestedTracking.label,
            style: IcueTableStyle.of(context).secondary,
          ),
        ),
        IcueTableColumn(
          id: 'description',
          label: 'Description',
          flex: 3,
          hideBelowWidth: 1000,
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
