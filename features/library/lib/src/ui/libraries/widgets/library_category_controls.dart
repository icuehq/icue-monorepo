import 'package:flutter/material.dart';

enum LibraryCategoryStatusFilter {
  all('All'),
  active('Active'),
  inactive('Inactive');

  const LibraryCategoryStatusFilter(this.label);
  final String label;
}

class LibraryCategorySearchBar extends StatelessWidget {
  const LibraryCategorySearchBar({
    super.key,
    required this.searchController,
    required this.isWide,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onAddCategory,
  });

  final TextEditingController searchController;
  final bool isWide;
  final LibraryCategoryStatusFilter statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LibraryCategoryStatusFilter> onFilterChanged;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search categories by name, code…',
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
            .withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
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
          for (final filter in LibraryCategoryStatusFilter.values)
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
          ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onAddCategory,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Category'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
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

class LibraryCategoryEmptyState extends StatelessWidget {
  const LibraryCategoryEmptyState({super.key, required this.onAdd});
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
                Icons.auto_stories_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No book categories yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                'Classify titles, organize book collections, and simplify library cataloguing with categories.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
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

class LibraryCategoryNoResultsState extends StatelessWidget {
  const LibraryCategoryNoResultsState({
    super.key,
    required this.query,
    required this.onClear,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              query.isNotEmpty
                  ? 'No categories matching "$query"'
                  : 'No categories match the selected filter',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Clear search & filters'),
            ),
          ],
        ),
      ),
    );
  }
}
