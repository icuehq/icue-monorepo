import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart' show callableErrorMessage;
import 'package:icue_ui/icue_ui.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
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
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range,
    );
    if (picked != null) _onRangeChanged(picked);
  }

  Future<void> _exportCsv(List<String> header, List<List<String>> rows) async {
    final library = context.read<LibraryProvider>();
    if (_def.kind == LibraryReportKind.loans) {
      // The table holds one page; export every matching loan.
      final names = LibraryNames(
        title: library.titleName,
        library: library.libraryName,
      );
      try {
        rows = [
          for (final row in await library.exportReportLoans())
            [for (final column in _def.cols) column.cell(row, names)],
        ];
      } catch (error) {
        if (mounted) showMessage(context, callableErrorMessage(error));
        return;
      }
    }
    final csv = toCsv(header, rows);
    final saved = await saveCsvFile('${_def.key}-report.csv', csv);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Downloaded ${rows.length} ${rows.length == 1 ? 'row' : 'rows'} as CSV${rows.length >= LibraryService.loanLimit ? '. The limit was reached; choose a shorter period for the rest.' : ''}'
              : 'Download cancelled',
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

    final pager = library.reportLoans;
    final paged = _def.kind == LibraryReportKind.loans;
    final header = [for (final column in _def.cols) column.label];
    final rows = [
      for (final row in paged ? pager.items : library.reportRows)
        [for (final column in _def.cols) column.cell(row, names)],
    ];
    final sumColumns = {
      for (var index = 0; index < _def.cols.length; index++)
        if (_def.cols[index].sum) index,
    };

    final horizontalPadding = context.isWide ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Reports'),
        bottom: library.insightsLoading || (paged && pager.loading)
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
              loanTotal: pager.total,
              loanCounts: library.reportLoanCounts,
            );
            final table = LibraryReportTable(
              header: header,
              rows: rows,
              sumColumns: sumColumns,
              filtersActive: _libraryId != null || _status != null,
              filters: [
                IcueTableFilter(
                  id: 'report',
                  allowAll: false,
                  label: 'Report',
                  options: const [
                    IcueTableFilterOption('dateRange', 'All'),
                    IcueTableFilterOption('student', 'By Student'),
                    IcueTableFilterOption('staff', 'By Staff'),
                    IcueTableFilterOption('monthly', 'By Month'),
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
                  allowAll: false,
                  label: 'Period',
                  options: [
                    for (final preset in LibraryDatePreset.values)
                      IcueTableFilterOption(preset.name, preset.label),
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
              isLoading: paged
                  ? pager.loading && pager.items.isEmpty
                  : library.insightsLoading,
              errorMessage: paged
                  ? (pager.error == null ? null : library.errorMessage)
                  : library.errorMessage,
              onExport: rows.isEmpty ? null : () => _exportCsv(header, rows),
              count: pager.total ?? pager.items.length,
              onRetry: pager.retry,
              pagination: paged ? IcueTablePagination.pager(pager) : null,
            );
            final notice = library.reportCapped && !paged
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Only the latest ${LibraryService.loanLimit} loans in this period are counted. Choose a shorter period for complete figures.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : const SizedBox.shrink();
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
                        notice,
                        const SizedBox(height: 18),
                        Expanded(child: table),
                      ],
                    ),
                  )
                : ListView(
                    padding: padding,
                    children: [kpis, notice, const SizedBox(height: 18), table],
                  );
          },
        ),
      ),
    );
  }
}
