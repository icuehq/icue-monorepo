import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:routes/routes.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/class_filter_dropdown.dart';

enum CatalogueStatusFilter {
  all('All'),
  active('Active'),
  inactive('Inactive');

  const CatalogueStatusFilter(this.label);
  final String label;
}

class CatalogueFilterHeader extends StatelessWidget {
  const CatalogueFilterHeader({
    super.key,
    required this.searchController,
    required this.selectedCategoryId,
    required this.selectedClassId,
    required this.standards,
    required this.statusFilter,
    required this.categories,
    required this.isWide,
    required this.totalCount,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onCategoryChanged,
    required this.onClassChanged,
    required this.onStatusChanged,
    required this.onAddBook,
    this.onRefresh,
  });

  final TextEditingController searchController;
  final String? selectedCategoryId;
  final int? selectedClassId;
  final List<Standards> standards;
  final CatalogueStatusFilter statusFilter;
  final List<LibraryCategory> categories;
  final bool isWide;
  final int totalCount;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<int?> onClassChanged;
  final ValueChanged<CatalogueStatusFilter> onStatusChanged;
  final VoidCallback onAddBook;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSearchText = searchController.text.trim().isNotEmpty;

    final topCategories =
        categories.where((category) => category.parentId == null).toList()
          ..sort((first, second) => first.name.compareTo(second.name));
    final subcategories =
        categories.where((category) => category.parentId != null).toList()
          ..sort((first, second) => first.name.compareTo(second.name));

    final hasSelected =
        selectedCategoryId == null ||
        categories.any((category) => category.id == selectedCategoryId);
    final effectiveCategoryId = hasSelected ? selectedCategoryId : null;

    final searchField = TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: onSearchSubmitted,
      decoration: InputDecoration(
        hintText: 'Search title, author, or publisher...',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: hasSearchText
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear search',
                onPressed: onClearSearch,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                tooltip: 'Search',
                onPressed: () => onSearchSubmitted(searchController.text),
              ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );

    final categoryDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: effectiveCategoryId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          hint: const Row(
            children: [
              Icon(Icons.category_outlined, size: 18),
              SizedBox(width: 8),
              Text('All categories'),
            ],
          ),
          items: [
            const DropdownMenuItem<String?>(
              child: Row(
                children: [
                  Icon(Icons.category_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('All categories'),
                ],
              ),
            ),
            for (final top in topCategories) ...[
              DropdownMenuItem<String?>(
                value: top.id,
                child: Text(
                  top.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final sub in subcategories.where(
                (subcategory) => subcategory.parentId == top.id,
              ))
                DropdownMenuItem<String?>(
                  value: sub.id,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      '↳ ${sub.name}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ],
          onChanged: onCategoryChanged,
        ),
      ),
    );

    final classDropdown = ClassFilterDropdown(
      standards: standards,
      selectedClassId: selectedClassId,
      onChanged: onClassChanged,
    );

    final statusFilters = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final filter in CatalogueStatusFilter.values) ...[
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(
                filter.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: statusFilter == filter
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              selected: statusFilter == filter,
              onSelected: (_) => onStatusChanged(filter),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ),
        ],
      ],
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: categoryDropdown),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: classDropdown),
                const SizedBox(width: 12),
                statusFilters,
                const SizedBox(width: 12),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh catalogue',
                    onPressed: onRefresh,
                  ),
                ...[
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Add Book',
                    onPressed: onAddBook,
                    leadingIcon: Icons.add_rounded,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$totalCount ${totalCount == 1 ? 'title' : 'titles'} listed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (effectiveCategoryId != null ||
                    selectedClassId != null ||
                    hasSearchText ||
                    statusFilter != CatalogueStatusFilter.all) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      onClearSearch();
                      onCategoryChanged(null);
                      onClassChanged(null);
                      onStatusChanged(CatalogueStatusFilter.all);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'Reset all filters',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: categoryDropdown),
              const SizedBox(width: 8),
              Expanded(child: classDropdown),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                statusFilters,
                const SizedBox(width: 8),
                Text(
                  '($totalCount titles)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
