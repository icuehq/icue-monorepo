import 'package:admin_ui/src/adaptive.dart';
import 'package:admin_ui/src/form_helpers.dart';
import 'package:admin_ui/src/report_pdf.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A report as a table: search over the loaded rows, a totals row, CSV copy and PDF export.
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
  var _search = '';

  @override
  Widget build(BuildContext context) {
    final query = _search.toLowerCase();
    final matching = widget.rows
        .where(
          (row) =>
              query.isEmpty ||
              row.any((cell) => cell.toLowerCase().contains(query)),
        )
        .toList();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Copy CSV',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: tableRows.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: toCsv(widget.header, tableRows)),
                    );
                    if (context.mounted) showMessage(context, 'CSV copied');
                  },
          ),
          IconButton(
            tooltip: 'PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: tableRows.isEmpty
                ? null
                : () => shareReportPdf(widget.title, widget.header, tableRows),
          ),
        ],
      ),
      body: CenteredBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _search = value.trim()),
                  ),
                  widget.filters,
                ],
              ),
            ),
            Expanded(
              child: tableRows.isEmpty
                  ? Center(
                      child: widget.isLoading
                          ? const CircularProgressIndicator()
                          : Text(widget.errorMessage ?? 'No rows'),
                    )
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            for (final heading in widget.header)
                              DataColumn(label: Text(heading)),
                          ],
                          rows: [
                            for (final row in tableRows)
                              DataRow(
                                cells: [
                                  for (final cell in row) DataCell(Text(cell)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (widget.footerNote != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(widget.footerNote!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Date-range and status filters shared by every report; the report page reloads when they change.
class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    required this.showDateRange,
    required this.range,
    required this.onRangeChanged,
    required this.statuses,
    required this.status,
    required this.onStatusChanged,
    super.key,
  });

  final bool showDateRange;
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final List<String> statuses;
  final String? status;
  final ValueChanged<String?> onStatusChanged;

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
  Widget build(BuildContext context) => Row(
    children: [
      if (showDateRange)
        TextButton.icon(
          icon: const Icon(Icons.event_rounded),
          label: Text(
            range == null
                ? 'Any date'
                : '${range!.start.toNumericDate()} → ${range!.end.toNumericDate()}',
          ),
          onPressed: () => _pickRange(context),
        ),
      if (range != null)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => onRangeChanged(null),
        ),
      if (statuses.isNotEmpty)
        Expanded(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: status,
            items: [
              const DropdownMenuItem(child: Text('All')),
              for (final value in statuses)
                DropdownMenuItem(
                  value: value,
                  child: Text(humanizeStatus(value)),
                ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
    ],
  );
}
