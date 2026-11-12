import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Report records with status badges and a totals strip for summed columns.
/// Summary reports use an [IcueClientTable] (sort and search their computed rows);
/// with [pagination] (the loans report) it is an [IcueTable] over one Firestore page.
/// [filters] (report, period, library, status) reload server data.
class LibraryReportTable extends StatelessWidget {
  const LibraryReportTable({
    required this.header,
    required this.rows,
    required this.sumColumns,
    required this.filters,
    required this.filtersActive,
    required this.onClearFilters,
    required this.isLoading,
    this.errorMessage,
    this.onExport,
    this.pagination,
    this.count,
    this.onRetry,
    super.key,
  });

  final List<String> header;
  final List<List<String>> rows;
  final Set<int> sumColumns;
  final List<IcueTableFilter> filters;
  final bool filtersActive;
  final VoidCallback onClearFilters;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onExport;
  final IcueTablePagination? pagination;

  /// Rows matching the filters across every page (with [pagination]).
  final int? count;
  final VoidCallback? onRetry;

  static Widget _badge(
    String label,
    Color background,
    Color foreground, {
    IconData? icon,
  }) => IcueStatusPill(
    label: label,
    color: foreground,
    background: background,
    icon: icon,
    bordered: false,
  );

  static Widget _status(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    final lower = status.toLowerCase().trim();
    final label = humanizeStatus(lower);
    return switch (lower) {
      'active' => _badge(
        label,
        scheme.primaryContainer.withValues(alpha: 0.55),
        scheme.primary,
        icon: Icons.sync_rounded,
      ),
      'returned' => _badge(
        label,
        Colors.green.withValues(alpha: 0.15),
        Colors.green.shade800,
        icon: Icons.check_circle_outline_rounded,
      ),
      'lost' => _badge(
        label,
        scheme.errorContainer.withValues(alpha: 0.6),
        scheme.error,
        icon: Icons.cancel_outlined,
      ),
      _ => _badge(
        label,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        icon: Icons.info_outline,
      ),
    };
  }

  Widget _cell(BuildContext context, String cell, String headerName) {
    if (headerName == 'status') return _status(context, cell);
    if (headerName == 'overdue' && (int.tryParse(cell) ?? 0) > 0) {
      final scheme = Theme.of(context).colorScheme;
      return Align(
        alignment: Alignment.centerRight,
        child: _badge(
          cell,
          scheme.errorContainer.withValues(alpha: 0.5),
          scheme.error,
        ),
      );
    }
    final tokens = IcueTableStyle.of(context);
    return IcueTableCellText(
      cell,
      style: headerName == 'member' ? tokens.primary : tokens.secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matching = rows;

    final columns = [
      for (var index = 0; index < header.length; index++)
        () {
          final numeric = sumColumns.contains(index);
          final headerName = header[index].toLowerCase();
          final allNumbers = matching.every(
            (row) => double.tryParse(row[index]) != null,
          );
          return IcueTableColumn<List<String>>(
            id: '$index',
            label: header[index],
            sortable: pagination == null,
            alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
            comparator: (row) => allNumbers
                ? double.parse(row[index])
                : row[index].toLowerCase(),
            cellBuilder: (context, row) =>
                _cell(context, row[index], headerName),
          );
        }(),
    ];

    final totals = sumColumns.isEmpty || matching.isEmpty
        ? null
        : [
            for (final column in sumColumns.toList()..sort())
              '${header[column]}: ${matching.fold<double>(0, (sum, row) => sum + (double.tryParse(row[column]) ?? 0)).toAmountText()}',
          ].join('   •   ');

    final status = IcueTableStatus.of(
      failed: errorMessage != null,
      loading: isLoading,
    );
    const emptyTitle = 'No report records found';
    const emptyMessage = 'Try adjusting the date range or library filter.';
    final export = IcueTableAction(
      label: 'Export CSV',
      icon: Icons.download_rounded,
      onPressed: onExport,
    );
    final paged = pagination;
    final table = paged != null
        ? IcueTable<List<String>>(
            title: 'Report records',
            columns: columns,
            rows: matching,
            count: count,
            rowKey: (row) => row,
            status: status,
            errorMessage: errorMessage,
            onRetry: onRetry,
            filters: filters,
            isFiltered: filtersActive,
            onClearFilters: onClearFilters,
            pagination: paged,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            secondaryAction: export,
          )
        : IcueClientTable<List<String>>(
            title: 'Report records',
            columns: columns,
            items: matching,
            searchText: (row) => row.join(' '),
            searchHint: 'Search records',
            externalFilters: filters,
            externalFiltersActive: filtersActive,
            onClearExternalFilters: onClearFilters,
            rowKey: (row) => row,
            status: status,
            errorMessage: errorMessage,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            secondaryAction: export,
          );

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bounded height: fill it so the pager sits at the bottom.
          if (constraints.hasBoundedHeight) Expanded(child: table) else table,
          if (totals != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Total  •  $totals',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
