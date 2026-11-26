import 'package:flutter/material.dart';

enum LibraryStatusFilter {
  all('All'),
  active('Active'),
  inactive('Inactive');

  const LibraryStatusFilter(this.label);
  final String label;
}

class LibraryFilterHeader extends StatelessWidget {
  const LibraryFilterHeader({
    super.key,
    required this.searchController,
    required this.statusFilter,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final LibraryStatusFilter statusFilter;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LibraryStatusFilter> onStatusChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final searchField = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search libraries by name or location…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: onClearSearch,
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
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

    final statusChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in LibraryStatusFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(filter.label),
                selected: statusFilter == filter,
                onSelected: (_) => onStatusChanged(filter),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...[searchField, const SizedBox(height: 8), statusChips],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$totalCount ${totalCount == 1 ? 'library' : 'libraries'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
