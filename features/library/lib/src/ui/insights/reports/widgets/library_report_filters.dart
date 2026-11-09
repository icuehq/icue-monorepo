import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:school_library/school_library.dart';

/// Available date range presets for library reports.
enum LibraryDatePreset {
  currentMonth('Current Month'),
  lastMonth('Last Month'),
  last6Months('Last 6 Months'),
  last12Months('Last 12 Months'),
  custom('Custom Date Range');

  const LibraryDatePreset(this.label);
  final String label;
}

/// Computes the [DateTimeRange] for a given [LibraryDatePreset].
DateTimeRange calculateRangeForPreset(
  LibraryDatePreset preset, {
  DateTimeRange? customRange,
}) {
  final today = DateTime.now().dateOnly;
  switch (preset) {
    case LibraryDatePreset.currentMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      );
    case LibraryDatePreset.lastMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month, 0),
      );
    case LibraryDatePreset.last6Months:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 5),
        end: today,
      );
    case LibraryDatePreset.last12Months:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 11),
        end: today,
      );
    case LibraryDatePreset.custom:
      return customRange ??
          DateTimeRange(start: DateTime(today.year, today.month), end: today);
  }
}

/// Filter toolbar with date presets, custom date range, report switcher,
/// library picker, status filter, record search, and count indicator.
class LibraryReportFilters extends StatelessWidget {
  const LibraryReportFilters({
    required this.reports,
    required this.selectedReport,
    required this.onReportChanged,
    required this.datePreset,
    required this.onDatePresetChanged,
    required this.range,
    required this.onRangeChanged,
    required this.libraries,
    required this.selectedLibraryId,
    required this.onLibraryChanged,
    required this.statuses,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.rowCount,
    required this.filteredRowCount,
    super.key,
  });

  final List<LibraryReportDef> reports;
  final LibraryReportDef selectedReport;
  final ValueChanged<LibraryReportDef> onReportChanged;
  final LibraryDatePreset datePreset;
  final ValueChanged<LibraryDatePreset> onDatePresetChanged;
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final List<SchoolLibrary> libraries;
  final String? selectedLibraryId;
  final ValueChanged<String?> onLibraryChanged;
  final List<String> statuses;
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final int rowCount;
  final int filteredRowCount;

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

  Widget _datePresetDropdown(BuildContext context) {
    final width = context.isWide ? 190.0 : null;
    return SizedBox(
      width: width,
      child: AppDropdown<LibraryDatePreset>(
        key: ValueKey(datePreset),
        value: datePreset,
        icon: Icons.calendar_today_outlined,
        label: 'Period',
        items: [
          for (final preset in LibraryDatePreset.values)
            DropdownMenuItem(value: preset, child: Text(preset.label)),
        ],
        onChanged: (preset) {
          if (preset == null) return;
          onDatePresetChanged(preset);
          if (preset == LibraryDatePreset.custom) {
            _pickCustomRange(context);
          }
        },
      ),
    );
  }

  Widget _customRangeField(BuildContext context) {
    final theme = Theme.of(context);
    final rangeText =
        '${range.start.toNumericDate()} → ${range.end.toNumericDate()}';
    final width = context.isWide ? 230.0 : null;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _pickCustomRange(context),
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Custom Range',
            prefixIcon: const Icon(Icons.date_range_outlined, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Text(
            rangeText,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _reportTypeDropdown(BuildContext context) {
    final width = context.isWide ? 180.0 : null;
    return SizedBox(
      width: width,
      child: AppDropdown<String>(
        key: ValueKey(selectedReport.key),
        value: selectedReport.key,
        icon: Icons.assignment_outlined,
        label: 'Report',
        items: const [
          DropdownMenuItem(value: 'dateRange', child: Text('All Issues')),
          DropdownMenuItem(value: 'student', child: Text('Student')),
          DropdownMenuItem(value: 'staff', child: Text('Staff')),
          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
        ],
        onChanged: (reportKey) {
          if (reportKey == null) return;
          final matchedReport = reports.firstWhere(
            (reportDef) => reportDef.key == reportKey,
          );
          onReportChanged(matchedReport);
        },
      ),
    );
  }

  Widget _libraryDropdown(BuildContext context) {
    final width = context.isWide ? 190.0 : null;
    return SizedBox(
      width: width,
      child: AppDropdown<String>(
        key: ValueKey(selectedLibraryId),
        value: selectedLibraryId,
        icon: Icons.local_library_outlined,
        label: 'Library',
        items: [
          const DropdownMenuItem(child: Text('All libraries')),
          for (final schoolLibrary in libraries)
            DropdownMenuItem(
              value: schoolLibrary.id,
              child: Text(schoolLibrary.name),
            ),
        ],
        onChanged: onLibraryChanged,
      ),
    );
  }

  Widget _statusDropdown(BuildContext context) {
    final width = context.isWide ? 170.0 : null;
    return SizedBox(
      width: width,
      child: AppDropdown<String>(
        key: ValueKey(selectedStatus),
        value: selectedStatus,
        icon: Icons.filter_alt_outlined,
        label: 'Status',
        items: [
          const DropdownMenuItem(child: Text('All statuses')),
          for (final status in statuses)
            DropdownMenuItem(
              value: status,
              child: Text(humanizeStatus(status)),
            ),
        ],
        onChanged: onStatusChanged,
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final width = context.isWide ? 220.0 : null;
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search records…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClearSearch,
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        onChanged: onSearchChanged,
      ),
    );
  }

  Widget _recordCountChip(BuildContext context) {
    final theme = Theme.of(context);
    final countText = filteredRowCount == rowCount
        ? '$rowCount ${rowCount == 1 ? 'record' : 'records'}'
        : '$filteredRowCount of $rowCount records';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            countText,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filterControls = [
      _datePresetDropdown(context),
      if (datePreset == LibraryDatePreset.custom) _customRangeField(context),
      _reportTypeDropdown(context),
      _libraryDropdown(context),
      if (statuses.isNotEmpty) _statusDropdown(context),
      _searchField(context),
      _recordCountChip(context),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: context.isWide
          ? Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: filterControls,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < filterControls.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  filterControls[index],
                ],
              ],
            ),
    );
  }
}
