import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icueadmin/features/inventory/insights/report_pdf.dart';
import 'package:icueadmin/features/inventory/stock/stock_ui.dart';
import 'package:icueadmin/features/inventory/widgets/inv_ui.dart';
import 'package:inventory/inventory.dart' show toCsv;
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// One report: server filters (library, date range, status), search over the loaded rows, totals, CSV and PDF export.
class LibReportPage extends StatefulWidget {
  const LibReportPage({required this.def, super.key});

  final LibReportDef def;

  @override
  State<LibReportPage> createState() => _LibReportPageState();
}

class _LibReportPageState extends State<LibReportPage> {
  DateTimeRange? _range;
  String? _status;
  String? _libraryId;
  var _search = '';

  LibReportDef get _def => widget.def;

  Future<void> _load() async {
    final p = context.read<LibraryProvider>();
    if (p.libraries.isEmpty) await p.loadMasters();
    if (!mounted) return;
    await p.loadReport(
      _def,
      library: p.libraries.where((l) => l.id == _libraryId).firstOrNull,
      from: _range?.start,
      to: _range?.end,
      status: _status,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
    );
    if (r != null) {
      _range = r;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LibraryProvider>();
    final names = LibNames(
      title: p.titleName,
      library: p.libraryName,
      category: p.categoryName,
    );
    final q = _search.toLowerCase();
    final table =
        [
              for (final r in p.reportRows)
                [for (final c in _def.cols) c.cell(r, names)],
            ]
            .where(
              (row) => q.isEmpty || row.any((c) => c.toLowerCase().contains(q)),
            )
            .toList();
    final header = [for (final c in _def.cols) c.label];
    final totals = [
      for (var i = 0; i < _def.cols.length; i++)
        _def.cols[i].sum
            ? table
                  .fold<double>(0, (n, r) => n + (double.tryParse(r[i]) ?? 0))
                  .toStringAsFixed(2)
            : i == 0
            ? 'Total'
            : '',
    ];
    final hasTotals = _def.cols.any((c) => c.sum) && table.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(_def.title),
        actions: [
          IconButton(
            tooltip: 'Copy CSV',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: table.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: toCsv(header, [...table, if (hasTotals) totals]),
                      ),
                    );
                    if (context.mounted) invSnack(context, 'CSV copied');
                  },
          ),
          IconButton(
            tooltip: 'PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: table.isEmpty
                ? null
                : () => shareReportPdf(_def.title, header, [
                    ...table,
                    if (hasTotals) totals,
                  ]),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search these rows (member, author, category…)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
                if (_def.hasLibrary)
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: _libraryId,
                    items: [
                      const DropdownMenuItem(child: Text('All libraries')),
                      for (final l in p.libraries)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) {
                      _libraryId = v;
                      _load();
                    },
                  ),
                Row(
                  children: [
                    if (_def.hasDates && !_def.overdue)
                      TextButton.icon(
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          _range == null
                              ? 'Any date'
                              : '${libDay(_range!.start)} → ${libDay(_range!.end)}',
                        ),
                        onPressed: _pickRange,
                      ),
                    if (_range != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _range = null;
                          _load();
                        },
                      ),
                    if (_def.statuses.isNotEmpty)
                      Expanded(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _status,
                          items: [
                            const DropdownMenuItem(child: Text('All')),
                            for (final s in _def.statuses)
                              DropdownMenuItem(
                                value: s,
                                child: Text(statusLabel(s)),
                              ),
                          ],
                          onChanged: (v) {
                            _status = v;
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: table.isEmpty
                ? Center(
                    child: p.insightsLoading
                        ? const CircularProgressIndicator()
                        : Text(p.errorMessage ?? 'No rows'),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          for (final h in header) DataColumn(label: Text(h)),
                        ],
                        rows: [
                          for (final r in [...table, if (hasTotals) totals])
                            DataRow(
                              cells: [for (final c in r) DataCell(Text(c))],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_def.kind == LibReportKind.query &&
              p.reportRows.length >= LibraryService.reportLimit)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Showing the latest ${LibraryService.reportLimit} rows; narrow the date range.',
              ),
            ),
        ],
      ),
    );
  }
}
