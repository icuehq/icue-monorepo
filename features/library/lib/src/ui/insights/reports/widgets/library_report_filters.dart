import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

/// Filter toolbar with instant search, library picker, date presets, and status chips.
class LibraryReportFilters extends StatelessWidget {
  const LibraryReportFilters({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.libraries,
    required this.selectedLibraryId,
    required this.onLibraryChanged,
    required this.range,
    required this.onRangeChanged,
    required this.statuses,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.isMonthly,
    super.key,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final List<SchoolLibrary> libraries;
  final String? selectedLibraryId;
  final ValueChanged<String?> onLibraryChanged;
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final List<String> statuses;
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final bool isMonthly;

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: range,
    );
    if (picked != null) onRangeChanged(picked);
  }

  void _applyPreset(int monthsBack) {
    final today = DateTime.now().dateOnly;
    final start = DateTime(today.year, today.month - monthsBack);
    onRangeChanged(DateTimeRange(start: start, end: today));
  }

  void _applyDaysPreset(int daysBack) {
    final today = DateTime.now().dateOnly;
    final start = today.subtract(Duration(days: daysBack));
    onRangeChanged(DateTimeRange(start: start, end: today));
  }

  Widget _searchField(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Search these records…',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClearSearch,
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      onChanged: onSearchChanged,
    );
  }

  Widget _libraryDropdown(BuildContext context) => SizedBox(
        width: 220,
        child: AppDropdown<String>(
          value: selectedLibraryId,
          items: [
            const DropdownMenuItem(child: Text('All libraries')),
            for (final library in libraries)
              DropdownMenuItem(
                value: library.id,
                child: Text(library.name),
              ),
          ],
          onChanged: onLibraryChanged,
          icon: Icons.local_library_outlined,
          label: 'Library',
        ),
      );

  Widget _dateControls(BuildContext context) {
    final theme = Theme.of(context);
    final rangeText =
        '${range.start.toNumericDate()} → ${range.end.toNumericDate()}';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (isMonthly) ...[
          ActionChip(
            label: const Text('Last 6 Months'),
            onPressed: () => _applyPreset(5),
          ),
          ActionChip(
            label: const Text('Last 12 Months'),
            onPressed: () => _applyPreset(11),
          ),
          ActionChip(
            label: const Text('Last 24 Months'),
            onPressed: () => _applyPreset(23),
          ),
        ] else ...[
          ActionChip(
            label: const Text('This Month'),
            onPressed: () => _applyPreset(0),
          ),
          ActionChip(
            label: const Text('Last 30 Days'),
            onPressed: () => _applyDaysPreset(30),
          ),
          ActionChip(
            label: const Text('Last 90 Days'),
            onPressed: () => _applyDaysPreset(90),
          ),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(
            Icons.date_range_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            rangeText,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => _pickCustomRange(context),
        ),
      ],
    );
  }

  Widget _statusChips(BuildContext context) {
    if (statuses.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final value in [null, ...statuses])
          ChoiceChip(
            label: Text(value == null ? 'All Statuses' : humanizeStatus(value)),
            selected: selectedStatus == value,
            onSelected: (_) => onStatusChanged(value),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.isWide)
            Row(
              children: [
                Expanded(flex: 3, child: _searchField(context)),
                const SizedBox(width: 14),
                _libraryDropdown(context),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchField(context),
                const SizedBox(height: 12),
                _libraryDropdown(context),
              ],
            ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 12),
          if (context.isWide)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _dateControls(context)),
                if (statuses.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  _statusChips(context),
                ],
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dateControls(context),
                if (statuses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _statusChips(context),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
