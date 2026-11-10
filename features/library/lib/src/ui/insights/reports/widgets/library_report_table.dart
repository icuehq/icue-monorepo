import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';

/// Report records in an [IcueClientTable]: sortable, paginated, with status
/// badges and a totals strip for summed columns. Search is the table's own;
/// [filters] (library, status) reload server data and sit in the same toolbar.
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
    this.footerNote,
    this.onExport,
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
  final String? footerNote;
  final VoidCallback? onExport;

  static Widget _badge(
    BuildContext context,
    String label,
    Color background,
    Color foreground, {
    IconData? icon,
  }) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: foreground, fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }

  static Widget _status(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    final lower = status.toLowerCase().trim();
    final label = humanizeStatus(lower);
    return switch (lower) {
      'active' => _badge(
        context,
        label,
        scheme.primaryContainer.withValues(alpha: 0.55),
        scheme.primary,
        icon: Icons.sync_rounded,
      ),
      'returned' => _badge(
        context,
        label,
        Colors.green.withValues(alpha: 0.15),
        Colors.green.shade800,
        icon: Icons.check_circle_outline_rounded,
      ),
      'lost' => _badge(
        context,
        label,
        scheme.errorContainer.withValues(alpha: 0.6),
        scheme.error,
        icon: Icons.cancel_outlined,
      ),
      _ => _badge(
        context,
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
          context,
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
            sortable: true,
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

    final table = IcueClientTable<List<String>>(
      title: 'Report records',
      columns: columns,
      items: matching,
      searchText: (row) => row.join(' '),
      searchHint: 'Search records',
      externalFilters: filters,
      externalFiltersActive: filtersActive,
      onClearExternalFilters: onClearFilters,
      rowKey: (row) => row,
      status: IcueTableStatus.of(
        failed: errorMessage != null,
        loading: isLoading,
      ),
      errorMessage: errorMessage,
      emptyTitle: 'No report records found',
      emptyMessage: 'Try adjusting the date range or library filter.',
      secondaryAction: IcueTableAction(
        label: 'Export CSV',
        icon: Icons.download_rounded,
        onPressed: onExport,
      ),
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
          if (footerNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      footerNote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
