import 'package:core_ui/core_ui.dart';
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
    required this.selectedCampus,
    required this.statusFilter,
    required this.campuses,
    required this.isWide,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onCampusChanged,
    required this.onStatusChanged,
    required this.onAddLibrary,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final int? selectedCampus;
  final LibraryStatusFilter statusFilter;
  final List<int> campuses;
  final bool isWide;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onCampusChanged;
  final ValueChanged<LibraryStatusFilter> onStatusChanged;
  final VoidCallback onAddLibrary;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final searchField = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search libraries by name, code, location…',
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

    final campusChips = campuses.length > 1
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All campuses'),
                    selected: selectedCampus == null,
                    onSelected: (_) => onCampusChanged(null),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
                ),
                for (final campus in campuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('Campus $campus'),
                      selected: selectedCampus == campus,
                      onSelected: (_) => onCampusChanged(campus),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          )
        : null;

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
          if (isWide)
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                statusChips,
                ...[
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Add Library',
                    onPressed: onAddLibrary,
                    leadingIcon: Icons.add_rounded,
                  ),
                ],
              ],
            )
          else ...[
            searchField,
            const SizedBox(height: 8),
            statusChips,
          ],
          if (campusChips != null) ...[const SizedBox(height: 8), campusChips],
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
