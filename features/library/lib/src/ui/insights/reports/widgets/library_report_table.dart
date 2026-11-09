import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Enterprise data table with interactive column sorting, formatted cells, status badges, and totals.
class LibraryReportTable extends StatefulWidget {
  const LibraryReportTable({
    required this.header,
    required this.rows,
    required this.sumColumns,
    required this.searchQuery,
    required this.isLoading,
    this.errorMessage,
    this.footerNote,
    this.onClearSearch,
    super.key,
  });

  final List<String> header;
  final List<List<String>> rows;
  final Set<int> sumColumns;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;
  final String? footerNote;
  final VoidCallback? onClearSearch;

  @override
  State<LibraryReportTable> createState() => _LibraryReportTableState();
}

class _LibraryReportTableState extends State<LibraryReportTable> {
  int? _sortColumn;
  bool _ascending = true;

  int _compare(String firstValue, String secondValue) {
    final numberFirst = double.tryParse(firstValue);
    final numberSecond = double.tryParse(secondValue);
    if (numberFirst != null && numberSecond != null) {
      return numberFirst.compareTo(numberSecond);
    }
    return firstValue.toLowerCase().compareTo(secondValue.toLowerCase());
  }

  Widget _statusBadge(BuildContext context, String status) {
    final theme = Theme.of(context);
    final lower = status.toLowerCase().trim();

    Color backgroundColor;
    Color foregroundColor;
    IconData icon;

    switch (lower) {
      case 'active':
        backgroundColor = theme.colorScheme.primaryContainer.withValues(
          alpha: 0.55,
        );
        foregroundColor = theme.colorScheme.primary;
        icon = Icons.sync_rounded;
      case 'returned':
        backgroundColor = Colors.green.withValues(alpha: 0.15);
        foregroundColor = Colors.green.shade800;
        icon = Icons.check_circle_outline_rounded;
      case 'lost':
        backgroundColor = theme.colorScheme.errorContainer.withValues(
          alpha: 0.6,
        );
        foregroundColor = theme.colorScheme.error;
        icon = Icons.cancel_outlined;
      default:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        foregroundColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            humanizeStatus(lower),
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellWidget(
    BuildContext context,
    String cell,
    int columnIndex,
    bool isTotal,
  ) {
    final theme = Theme.of(context);
    final headerName = widget.header[columnIndex].toLowerCase();

    if (isTotal) {
      return Text(
        cell,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      );
    }

    if (headerName == 'status') {
      return _statusBadge(context, cell);
    }

    if (headerName == 'overdue') {
      final overdueCount = int.tryParse(cell) ?? 0;
      if (overdueCount > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            cell,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
    }

    if (headerName == 'member') {
      return Text(
        cell,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Text(cell, style: theme.textTheme.bodyMedium);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = widget.searchQuery.toLowerCase().trim();

    final matching = widget.rows
        .where(
          (row) =>
              query.isEmpty ||
              row.any((cell) => cell.toLowerCase().contains(query)),
        )
        .toList();

    final sortColumn = _sortColumn;
    if (sortColumn != null && sortColumn < widget.header.length) {
      matching.sort(
        (firstRow, secondRow) => _ascending
            ? _compare(firstRow[sortColumn], secondRow[sortColumn])
            : _compare(secondRow[sortColumn], firstRow[sortColumn]),
      );
    }

    if (widget.isLoading) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Loading report data…'),
          ],
        ),
      );
    }

    if (widget.errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load the report',
        message: widget.errorMessage,
        neutral: true,
      );
    }

    if (matching.isEmpty) {
      if (query.isNotEmpty) {
        return EmptyState.noResults(
          title: 'No records match "$query"',
          onAction: widget.onClearSearch,
        );
      }
      return const EmptyState(
        icon: Icons.table_rows_outlined,
        title: 'No report records found',
        message: 'Try adjusting the date range or library filter.',
        neutral: true,
      );
    }

    final hasTotals = widget.sumColumns.isNotEmpty && matching.isNotEmpty;
    final totals = [
      for (var column = 0; column < widget.header.length; column++)
        widget.sumColumns.contains(column)
            ? matching
                  .fold<double>(
                    0,
                    (sum, row) => sum + (double.tryParse(row[column]) ?? 0),
                  )
                  .toAmountText()
            : column == 0
            ? 'Total'
            : '',
    ];

    final tableRows = [...matching, if (hasTotals) totals];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          color: theme.colorScheme.surface,
          child: LayoutBuilder(
            builder: (context, constraints) => Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    sortColumnIndex: _sortColumn,
                    sortAscending: _ascending,
                    columnSpacing: 26,
                    horizontalMargin: 18,
                    headingRowHeight: 46,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 52,
                    dividerThickness: 0.5,
                    headingRowColor: WidgetStatePropertyAll(
                      theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    headingTextStyle: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    columns: [
                      for (
                        var columnIndex = 0;
                        columnIndex < widget.header.length;
                        columnIndex++
                      )
                        DataColumn(
                          label: Text(widget.header[columnIndex]),
                          numeric: widget.sumColumns.contains(columnIndex),
                          onSort: (index, ascending) => setState(() {
                            _sortColumn = index;
                            _ascending = ascending;
                          }),
                        ),
                    ],
                    rows: [
                      for (var index = 0; index < tableRows.length; index++)
                        DataRow(
                          color: hasTotals && index == tableRows.length - 1
                              ? WidgetStatePropertyAll(
                                  theme.colorScheme.primaryContainer.withValues(
                                    alpha: 0.25,
                                  ),
                                )
                              : null,
                          cells: [
                            for (
                              var columnIndex = 0;
                              columnIndex < tableRows[index].length;
                              columnIndex++
                            )
                              DataCell(
                                _cellWidget(
                                  context,
                                  tableRows[index][columnIndex],
                                  columnIndex,
                                  hasTotals && index == tableRows.length - 1,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.footerNote != null)
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
                    widget.footerNote!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
