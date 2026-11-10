import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/insights/reports/widgets/library_report_filters.dart';
import 'package:school_library/src/ui/insights/reports/widgets/library_report_kpis.dart';
import 'package:school_library/src/ui/insights/reports/widgets/library_report_table.dart';

/// Enterprise library reports page: executive metrics, interactive report switcher,
/// date presets, branch and status filters, and sortable tabular data with CSV export.
class LibraryReportsPage extends StatefulWidget {
  const LibraryReportsPage({super.key});

  @override
  State<LibraryReportsPage> createState() => _LibraryReportsPageState();
}

class _LibraryReportsPageState extends State<LibraryReportsPage> {
  LibraryReportDef _def = libraryReports.first;
  LibraryDatePreset _datePreset = LibraryDatePreset.currentMonth;
  late DateTimeRange _range = calculateRangeForPreset(_datePreset);
  String? _status;
  String? _libraryId;
  Future<void> _load() async {
    final library = context.read<LibraryProvider>();
    if (library.libraries.isEmpty) await library.loadMasters();
    if (!mounted) return;
    await library.loadReport(
      _def,
      library: library.libraries
          .where((schoolLibrary) => schoolLibrary.id == _libraryId)
          .firstOrNull,
      from: _range.start,
      to: _range.end,
      status: _status,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onReportChanged(LibraryReportDef def) {
    setState(() {
      _def = def;
      _status = null;
    });
    _load();
  }

  void _onDatePresetChanged(LibraryDatePreset preset) {
    setState(() {
      _datePreset = preset;
      if (preset != LibraryDatePreset.custom) {
        _range = calculateRangeForPreset(preset);
      }
    });
    if (preset != LibraryDatePreset.custom) {
      _load();
    }
  }

  void _onRangeChanged(DateTimeRange newRange) {
    setState(() {
      _datePreset = LibraryDatePreset.custom;
      _range = newRange;
    });
    _load();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
    );
    if (picked != null) _onRangeChanged(picked);
  }

  Future<void> _exportCsv(List<String> header, List<List<String>> rows) async {
    final csv = toCsv(header, rows);
    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${rows.length} ${rows.length == 1 ? 'row' : 'rows'} to clipboard as CSV',
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final names = LibraryNames(
      title: library.titleName,
      library: library.libraryName,
    );

    final header = [for (final column in _def.cols) column.label];
    final rows = [
      for (final row in library.reportRows)
        [for (final column in _def.cols) column.cell(row, names)],
    ];
    final sumColumns = {
      for (var index = 0; index < _def.cols.length; index++)
        if (_def.cols[index].sum) index,
    };

    final footerNote =
        _def.kind == LibraryReportKind.loans &&
            library.reportRows.length >= LibraryService.reportLimit
        ? 'Showing the latest ${LibraryService.reportLimit} records. Narrow down the date range to view older loans.'
        : null;

    final horizontalPadding = context.isWide ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            icon: library.insightsLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: library.insightsLoading ? null : _load,
          ),
          const SizedBox(width: 12),
        ],
        bottom: library.insightsLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: IcueCenteredBody(
        maxWidth: double.infinity,
        child: Builder(
          builder: (context) {
            final kpis = LibraryReportKpis(
              kind: _def.kind,
              rows: library.reportRows,
            );
            final table = LibraryReportTable(
              header: header,
              rows: rows,
              sumColumns: sumColumns,
              filtersActive: _libraryId != null || _status != null,
              filters: [
                IcueTableFilter(
                  id: 'report',
                  label: 'Report',
                  options: const [
                    IcueTableFilterOption('dateRange', 'All Issues'),
                    IcueTableFilterOption('student', 'Student'),
                    IcueTableFilterOption('staff', 'Staff'),
                    IcueTableFilterOption('monthly', 'Monthly'),
                  ],
                  value: _def.key,
                  onChanged: (reportKey) {
                    if (reportKey == null || reportKey == _def.key) return;
                    _onReportChanged(
                      libraryReports.firstWhere((def) => def.key == reportKey),
                    );
                  },
                ),
                IcueTableFilter(
                  id: 'period',
                  label: 'Period',
                  options: [
                    for (final preset in LibraryDatePreset.values)
                      IcueTableFilterOption(
                        preset.name,
                        preset == LibraryDatePreset.custom
                            ? '${_range.start.toNumericDate()} → ${_range.end.toNumericDate()}'
                            : preset.label,
                      ),
                  ],
                  value: _datePreset.name,
                  onChanged: (name) {
                    final preset = name == null
                        ? LibraryDatePreset.currentMonth
                        : LibraryDatePreset.values.byName(name);
                    _onDatePresetChanged(preset);
                    if (preset == LibraryDatePreset.custom) _pickCustomRange();
                  },
                ),
                IcueTableFilter(
                  id: 'library',
                  label: 'Library',
                  options: [
                    for (final schoolLibrary in library.libraries)
                      IcueTableFilterOption(
                        schoolLibrary.id,
                        schoolLibrary.name,
                      ),
                  ],
                  value: _libraryId,
                  onChanged: (libraryId) {
                    setState(() => _libraryId = libraryId);
                    _load();
                  },
                ),
                if (_def.statuses.isNotEmpty)
                  IcueTableFilter(
                    id: 'status',
                    label: 'Status',
                    options: [
                      for (final status in _def.statuses)
                        IcueTableFilterOption(status, humanizeStatus(status)),
                    ],
                    value: _status,
                    onChanged: (status) {
                      setState(() => _status = status);
                      _load();
                    },
                  ),
              ],
              onClearFilters: () {
                setState(() {
                  _libraryId = null;
                  _status = null;
                });
                _load();
              },
              isLoading: library.insightsLoading,
              errorMessage: library.errorMessage,
              footerNote: footerNote,
              onExport: rows.isEmpty ? null : () => _exportCsv(header, rows),
            );
            final padding = EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            );
            // Wide: the table fills the screen and scrolls under its header.
            return context.isWide
                ? Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        kpis,
                        const SizedBox(height: 18),
                        Expanded(child: table),
                      ],
                    ),
                  )
                : ListView(
                    padding: padding,
                    children: [kpis, const SizedBox(height: 18), table],
                  );
          },
        ),
      ),
    );
  }
}
