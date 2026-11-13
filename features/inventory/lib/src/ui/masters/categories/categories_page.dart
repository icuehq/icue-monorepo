import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/masters/categories/widgets/categories_table.dart';
import 'package:inventory/src/ui/masters/categories/widgets/category_card.dart';
import 'package:inventory/src/ui/masters/categories/widgets/category_dialog.dart';
import 'package:inventory/src/ui/masters/categories/widgets/category_list_views.dart';
import 'package:provider/provider.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _searchController = TextEditingController();
  CategoryStatusFilter _statusFilter = CategoryStatusFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inventoryProvider = context.read<InventoryProvider>();
      if (inventoryProvider.categories.isEmpty) inventoryProvider.loadMasters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = CategoryStatusFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();
    final canEdit = inventoryProvider.access.can('inventory.settings');
    final query = _searchController.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    // Hierarchy: Top categories and any orphan categories
    final topCategories = inventoryProvider.topCategories;
    final topCategoryIds = topCategories.map((category) => category.id).toSet();
    final allTopCategories = [
      ...topCategories,
      ...inventoryProvider.categories.where(
        (category) =>
            category.parentId != null &&
            !topCategoryIds.contains(category.parentId),
      ),
    ];

    // Filter categories & their subcategories
    final matchingGroups = <(InventoryCategory, List<InventoryCategory>)>[];
    int totalSubsCount = 0;

    for (final top in allTopCategories) {
      final topSubs = inventoryProvider.categories
          .where((category) => category.parentId == top.id)
          .toList();

      final topMatchesStatus = switch (_statusFilter) {
        CategoryStatusFilter.all => true,
        CategoryStatusFilter.active => top.active,
        CategoryStatusFilter.inactive => !top.active,
      };

      final topMatchesQuery =
          !isSearching ||
          top.name.toLowerCase().contains(query) ||
          top.code.toLowerCase().contains(query) ||
          (top.description?.toLowerCase().contains(query) ?? false);

      final matchingSubs = topSubs.where((category) {
        final subStatusOk = switch (_statusFilter) {
          CategoryStatusFilter.all => true,
          CategoryStatusFilter.active => category.active,
          CategoryStatusFilter.inactive => !category.active,
        };
        if (!subStatusOk) return false;

        if (!isSearching) return true;
        return category.name.toLowerCase().contains(query) ||
            category.code.toLowerCase().contains(query) ||
            (category.description?.toLowerCase().contains(query) ?? false);
      }).toList();

      final includeTop =
          (topMatchesStatus && topMatchesQuery) || matchingSubs.isNotEmpty;

      if (includeTop) {
        final effectiveSubs = isSearching && !topMatchesQuery
            ? matchingSubs
            : topSubs
                  .where(
                    (category) => switch (_statusFilter) {
                      CategoryStatusFilter.all => true,
                      CategoryStatusFilter.active => category.active,
                      CategoryStatusFilter.inactive => !category.active,
                    },
                  )
                  .toList();

        matchingGroups.add((top, effectiveSubs));
        totalSubsCount += effectiveSubs.length;
      }
    }

    final hasAnyCategories = inventoryProvider.categories.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: canEdit && hasAnyCategories && !context.isWide
          ? FloatingActionButton.extended(
              onPressed: () => CategoryDialog.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Category'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const contentPadding = EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          );

          if (inventoryProvider.isLoading && !hasAnyCategories) {
            return const IcueSkeletonCardList();
          }

          if (context.isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: CategoriesTable(
                categories: inventoryProvider.categories,
                canEdit: canEdit,
                onToggleActive: (category) =>
                    _onMenu(context, 'toggle', category),
              ),
            );
          }

          if (!hasAnyCategories) {
            return CategoryEmptyState(
              canEdit: canEdit,
              onAdd: () => CategoryDialog.show(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () => inventoryProvider.loadMasters(),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: ListView(
                  padding: contentPadding,
                  children: [
                    CategorySearchBar(
                      searchController: _searchController,
                      canEdit: canEdit,
                      statusFilter: _statusFilter,
                      onSearchChanged: (_) => setState(() {}),
                      onFilterChanged: (filter) =>
                          setState(() => _statusFilter = filter),
                      onAddCategory: () => CategoryDialog.show(context),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '${matchingGroups.length} ${matchingGroups.length == 1 ? 'category' : 'categories'} · $totalSubsCount ${totalSubsCount == 1 ? 'subcategory' : 'subcategories'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (matchingGroups.isEmpty)
                      CategoryNoResultsState(
                        query: query,
                        onClear: _clearFilters,
                      )
                    else
                      for (final (top, subs) in matchingGroups)
                        CategoryCard(
                          key: ValueKey(top.id),
                          category: top,
                          subcategories: subs,
                          canEdit: canEdit,
                          initiallyExpanded: isSearching,
                          onViewItems: (category) =>
                              _onMenu(context, 'items', category),
                          onEdit: (category) =>
                              _onMenu(context, 'edit', category),
                          onAddSubcategory: (category) =>
                              _onMenu(context, 'sub', category),
                          onToggleActive: (category) =>
                              _onMenu(context, 'toggle', category),
                        ),
                    const SizedBox(height: 72),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    String value,
    InventoryCategory category,
  ) async {
    final inventoryProvider = context.read<InventoryProvider>();
    switch (value) {
      case 'items':
        await context.push(
          '${InventoryRoutes.inventoryItems}?category=${category.id}',
        );
      case 'edit':
        await CategoryDialog.show(context, category: category);
      case 'sub':
        await CategoryDialog.show(context, parentId: category.id);
      case 'toggle':
        if (!await inventoryProvider.setCategoryActive(
              category.id,
              active: !category.active,
            ) &&
            context.mounted) {
          showMessage(context, inventoryProvider.errorMessage ?? 'Failed');
        }
    }
  }
}
