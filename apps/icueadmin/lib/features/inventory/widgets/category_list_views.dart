import 'package:flutter/material.dart';
import 'package:icueadmin/features/inventory/widgets/category_card.dart';
import 'package:icueadmin/widgets/form_helpers.dart';
import 'package:inventory/inventory.dart';

enum CategoryStatusFilter {
  all('All'),
  active('Active'),
  inactive('Inactive');

  const CategoryStatusFilter(this.label);
  final String label;
}

class CategoryTwoColumnLayout extends StatelessWidget {
  const CategoryTwoColumnLayout({
    super.key,
    required this.groups,
    required this.canEdit,
    required this.isSearching,
    required this.onViewItems,
    required this.onEdit,
    required this.onAddSubcategory,
    required this.onToggleActive,
  });

  final List<(InventoryCategory, List<InventoryCategory>)> groups;
  final bool canEdit;
  final bool isSearching;
  final ValueChanged<InventoryCategory> onViewItems;
  final ValueChanged<InventoryCategory> onEdit;
  final ValueChanged<InventoryCategory> onAddSubcategory;
  final ValueChanged<InventoryCategory> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final leftCol = <(InventoryCategory, List<InventoryCategory>)>[];
    final rightCol = <(InventoryCategory, List<InventoryCategory>)>[];

    for (var i = 0; i < groups.length; i++) {
      if (i.isEven) {
        leftCol.add(groups[i]);
      } else {
        rightCol.add(groups[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (final (top, subs) in leftCol)
                CategoryCard(
                  key: ValueKey(top.id),
                  category: top,
                  subcategories: subs,
                  canEdit: canEdit,
                  initiallyExpanded: isSearching,
                  onViewItems: onViewItems,
                  onEdit: onEdit,
                  onAddSubcategory: onAddSubcategory,
                  onToggleActive: onToggleActive,
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              for (final (top, subs) in rightCol)
                CategoryCard(
                  key: ValueKey(top.id),
                  category: top,
                  subcategories: subs,
                  canEdit: canEdit,
                  initiallyExpanded: isSearching,
                  onViewItems: onViewItems,
                  onEdit: onEdit,
                  onAddSubcategory: onAddSubcategory,
                  onToggleActive: onToggleActive,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class CategorySearchBar extends StatelessWidget {
  const CategorySearchBar({
    super.key,
    required this.searchController,
    required this.isWide,
    required this.canEdit,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onAddCategory,
  });

  final TextEditingController searchController;
  final bool isWide;
  final bool canEdit;
  final CategoryStatusFilter statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CategoryStatusFilter> onFilterChanged;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search categories…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in CategoryStatusFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(filter.label),
                selected: statusFilter == filter,
                onSelected: (_) => onFilterChanged(filter),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 12),
          filterChips,
          if (canEdit) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onAddCategory,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New Category'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [searchField, const SizedBox(height: 8), filterChips],
    );
  }
}

class CategoryEmptyState extends StatelessWidget {
  const CategoryEmptyState({
    super.key,
    required this.canEdit,
    required this.onAdd,
  });

  final bool canEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No categories yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create categories to classify inventory items, define tracking methods, and organize stock.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                SeedDefaultsButton<InventoryProvider>(
                  label: 'Add default categories & units',
                  canSeed: (provider) =>
                      provider.access.can('inventory.settings'),
                  seed: (provider) => provider.seedDefaults(),
                ),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Category'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryNoResultsState extends StatelessWidget {
  const CategoryNoResultsState({
    super.key,
    required this.query,
    required this.onClear,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No matching categories',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            query.isNotEmpty
                ? 'No categories or subcategories match "$query"'
                : 'No categories match the active filter.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded, size: 18),
            label: const Text('Clear search & filters'),
          ),
        ],
      ),
    );
  }
}
