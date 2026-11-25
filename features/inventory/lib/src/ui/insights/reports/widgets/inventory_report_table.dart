import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';

/// A report's rows in an [IcueClientTable] (search, sort and pages over the computed rows), with a
/// totals strip for the summed columns. [filters] (period, store, report filter) are owned by the page.
class InventoryReportTable extends StatelessWidget {
  const InventoryReportTable({
    required this.table,
    required this.filters,
    required this.filtersActive,
    required this.onClearFilters,
    required this.isLoading,
    required this.onExport,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final ReportTable table;
  final List<IcueTableFilter> filters;
  final bool filtersActive;
  final VoidCallback onClearFilters;
  final bool isLoading;
  final VoidCallback? onExport;
  final String? errorMessage;
  final VoidCallback? onRetry;

  static bool _isNumber(ReportCell kind) =>
      kind == ReportCell.quantity || kind == ReportCell.money;

  Widget _cell(BuildContext context, ReportColumnSpec column, String cell) {
    if (column.kind == ReportCell.status && cell.isNotEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: InventoryStatusChip(cell),
      );
    }
    final tokens = IcueTableStyle.of(context);
    return IcueTableCellText(
      cell.isEmpty ? '—' : cell,
      style: _isNumber(column.kind) ? tokens.numeric : tokens.secondary,
    );
  }

  /// Row text as the user reads it, for the search box.
  String _searchText(List<String> row) => [
    for (var index = 0; index < row.length; index++)
      table.columns[index].kind == ReportCell.status
          ? inventoryStatusLabel(row[index])
          : row[index],
  ].join(' ');

  @override
  Widget build(BuildContext context) {
    final columns = [
      for (var index = 0; index < table.columns.length; index++)
        () {
          final column = table.columns[index];
          final numeric = _isNumber(column.kind);
          return IcueTableColumn<List<String>>(
            id: '$index',
            label: column.label,
            sortable: true,
            alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
            comparator: (row) => numeric
                ? double.tryParse(row[index]) ?? double.negativeInfinity
                : row[index].toLowerCase(),
            cellBuilder: (context, row) => _cell(context, column, row[index]),
          );
        }(),
    ];
    final sums = table.sumColumns.toList()..sort();
    final totals = sums.isEmpty || table.rows.isEmpty
        ? null
        : [
            for (final index in sums)
              '${table.columns[index].label.replaceAll(' (₹)', '')}: ${table.rows.fold<double>(0, (total, row) => total + (double.tryParse(row[index]) ?? 0)).toRupees()}',
          ].join('   •   ');
    final clientTable = IcueClientTable<List<String>>(
      title: 'Report records',
      columns: columns,
      items: table.rows,
      rowKey: (row) => row,
      searchText: _searchText,
      searchHint: 'Search item, store, batch…',
      externalFilters: filters,
      externalFiltersActive: filtersActive,
      onClearExternalFilters: onClearFilters,
      initialPageSize: 25,
      pageSizeOptions: const [25, 50, 100, 250],
      status: IcueTableStatus.of(
        failed: errorMessage != null,
        loading: isLoading,
      ),
      errorMessage: errorMessage,
      onRetry: onRetry,
      emptyTitle: 'No report records found',
      emptyMessage: 'Try another period, store or filter.',
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
          if (constraints.hasBoundedHeight)
            Expanded(child: clientTable)
          else
            clientTable,
          if (totals != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Total  •  $totals',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
