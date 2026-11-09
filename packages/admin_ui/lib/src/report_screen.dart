import 'package:admin_ui/src/adaptive.dart';
import 'package:admin_ui/src/empty_state.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// A report as a table: search over the loaded rows, sortable columns, a totals row..
/// The module supplies the rows and its own filters (date range, status, store or library).
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    required this.title,
    required this.header,
    required this.rows,
    required this.sumColumns,
    required this.searchHint,
    required this.filters,
    required this.isLoading,
    this.errorMessage,
    this.footerNote,
    super.key,
  });

  final String title;
  final List<String> header;

  /// Every loaded row; the search box filters them.
  final List<List<String>> rows;

  /// Indexes of the columns whose cells are numbers to add up.
  final Set<int> sumColumns;
  final String searchHint;
  final Widget filters;
  final bool isLoading;
  final String? errorMessage;
  final String? footerNote;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _searchController = TextEditingController();
  var _search = '';
  int? _sortColumn;
  var _ascending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Numbers sort as numbers, everything else as lower-case text.
  int _compare(String a, String b) {
    final numberA = double.tryParse(a);
    final numberB = double.tryParse(b);
    if (numberA != null && numberB != null) return numberA.compareTo(numberB);
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _search = '');
  }

  Widget _toolbar(BuildContext context) {
    final theme = Theme.of(context);
    final search = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: widget.searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              ),
      ),
      onChanged: (value) => setState(() => _search = value.trim()),
    );
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: context.isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 380, child: search),
                  const SizedBox(width: 16),
                  Expanded(child: widget.filters),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 12), widget.filters],
              ),
      ),
    );
  }

  Widget _table(
    BuildContext context,
    List<List<String>> rows, {
    required bool hasTotals,
  }) {
    final theme = Theme.of(context);
    final bold = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Card(
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  sortColumnIndex: _sortColumn,
                  sortAscending: _ascending,
                  columnSpacing: 28,
                  horizontalMargin: 16,
                  dividerThickness: 0.5,
                  headingRowColor: WidgetStatePropertyAll(
                    theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  headingTextStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  columns: [
                    for (
                      var column = 0;
                      column < widget.header.length;
                      column++
                    )
                      DataColumn(
                        label: Text(widget.header[column]),
                        numeric: widget.sumColumns.contains(column),
                        onSort: (index, ascending) => setState(() {
                          _sortColumn = index;
                          _ascending = ascending;
                        }),
                      ),
                  ],
                  rows: [
                    for (var index = 0; index < rows.length; index++)
                      DataRow(
                        color: hasTotals && index == rows.length - 1
                            ? WidgetStatePropertyAll(
                                theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.35,
                                ),
                              )
                            : null,
                        cells: [
                          for (final cell in rows[index])
                            DataCell(
                              Text(
                                cell,
                                style: hasTotals && index == rows.length - 1
                                    ? bold
                                    : null,
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
    );
  }

  Widget _body(BuildContext context, List<List<String>> rows, bool hasTotals) {
    if (rows.isEmpty) {
      if (widget.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.errorMessage != null) {
        return EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load the report',
          message: widget.errorMessage,
          neutral: true,
        );
      }
      if (_search.isNotEmpty) {
        return EmptyState.noResults(
          title: 'No rows match "$_search"',
          onAction: _clearSearch,
        );
      }
      return const EmptyState(
        icon: Icons.table_rows_outlined,
        title: 'No rows to show',
        message: 'Try a different date range or filter.',
        neutral: true,
      );
    }
    return _table(context, rows, hasTotals: hasTotals);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.toLowerCase();
    final matching = widget.rows
        .where(
          (row) =>
              query.isEmpty ||
              row.any((cell) => cell.toLowerCase().contains(query)),
        )
        .toList();
    final sortColumn = _sortColumn;
    if (sortColumn != null) {
      matching.sort(
        (a, b) => _ascending
            ? _compare(a[sortColumn], b[sortColumn])
            : _compare(b[sortColumn], a[sortColumn]),
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
    final gutter = context.isWide ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: widget.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(context),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(
                _search.isEmpty
                    ? '${widget.rows.length} rows'
                    : '${matching.length} of ${widget.rows.length} rows',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: _body(context, tableRows, hasTotals)),
            if (widget.footerNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
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
        ),
      ),
    );
  }
}

/// Date-range and status filters shared by every report; the report page reloads when they change.
/// [leading] filters (a library or store picker) come first.
class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    required this.showDateRange,
    required this.range,
    required this.onRangeChanged,
    required this.statuses,
    required this.status,
    required this.onStatusChanged,
    this.leading = const [],
    super.key,
  });

  final bool showDateRange;
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final List<String> statuses;
  final String? status;
  final ValueChanged<String?> onStatusChanged;
  final List<Widget> leading;

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: range,
    );
    if (picked != null) onRangeChanged(picked);
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ...leading,
      if (showDateRange)
        OutlinedButton.icon(
          // The app theme makes buttons full width; keep this one as wide as its text.
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.event_rounded, size: 18),
          label: Text(
            range == null
                ? 'Any date'
                : '${range!.start.toNumericDate()} → ${range!.end.toNumericDate()}',
          ),
          onPressed: () => _pickRange(context),
        ),
      if (range != null)
        IconButton(
          tooltip: 'Clear dates',
          icon: const Icon(Icons.clear),
          onPressed: () => onRangeChanged(null),
        ),
      if (statuses.isNotEmpty)
        for (final value in [null, ...statuses])
          ChoiceChip(
            label: Text(value == null ? 'All' : humanizeStatus(value)),
            selected: status == value,
            onSelected: (_) => onStatusChanged(value),
          ),
    ],
  );
}
