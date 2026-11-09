import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/insights/reports/widgets/library_report_filters.dart';
import 'package:school_library/src/ui/insights/reports/widgets/library_report_header.dart';
import 'package:school_library/src/ui/insights/reports/widgets/library_report_kpis.dart';
import 'package:school_library/src/ui/insights/reports/widgets/library_report_selector.dart';
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
  late DateTimeRange _range = _defaultRange();
  String? _status;
  String? _libraryId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// This month, or the last 12 months for the monthly report.
  DateTimeRange _defaultRange() {
    final today = DateTime.now().dateOnly;
    return DateTimeRange(
      start: DateTime(
        today.year,
        today.month - (_def.kind == LibraryReportKind.monthly ? 11 : 0),
      ),
      end: today,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      _range = _defaultRange();
    });
    _load();
  }

  Future<void> _exportCsv(
    List<String> header,
    List<List<String>> rows,
  ) async {
    final query = _searchQuery.toLowerCase().trim();
    final matchingRows = rows
        .where(
          (row) =>
              query.isEmpty ||
              row.any((cell) => cell.toLowerCase().contains(query)),
        )
        .toList();

    final csv = toCsv(header, matchingRows);
    await Clipboard.setData(ClipboardData(text: csv));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${matchingRows.length} ${matchingRows.length == 1 ? 'row' : 'rows'} to clipboard as CSV',
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

    final query = _searchQuery.toLowerCase().trim();
    final filteredCount = query.isEmpty
        ? rows.length
        : rows
            .where((row) => row.any((cell) => cell.toLowerCase().contains(query)))
            .length;

    final footerNote =
        _def.kind == LibraryReportKind.loans &&
            library.reportRows.length >= LibraryService.reportLimit
        ? 'Showing the latest ${LibraryService.reportLimit} records. Narrow down the date range to view older loans.'
        : null;

    final horizontalPadding = context.isWide ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Reports'),
        bottom: library.insightsLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: CenteredBody(
        maxWidth: 1400,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 20,
          ),
          children: [
            LibraryReportHeader(
              title: _def.title,
              description: _def.blurb,
              rowCount: rows.length,
              filteredRowCount: filteredCount,
              onRefresh: _load,
              onExportCsv: () => _exportCsv(header, rows),
              isLoading: library.insightsLoading,
            ),
            const SizedBox(height: 18),
            LibraryReportSelector(
              reports: libraryReports,
              selected: _def,
              onSelected: _onReportChanged,
            ),
            const SizedBox(height: 18),
            LibraryReportKpis(
              kind: _def.kind,
              rows: library.reportRows,
            ),
            const SizedBox(height: 18),
            LibraryReportFilters(
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              libraries: library.libraries,
              selectedLibraryId: _libraryId,
              onLibraryChanged: (id) {
                setState(() => _libraryId = id);
                _load();
              },
              range: _range,
              onRangeChanged: (range) {
                setState(() => _range = range);
                _load();
              },
              statuses: _def.statuses,
              selectedStatus: _status,
              onStatusChanged: (status) {
                setState(() => _status = status);
                _load();
              },
              isMonthly: _def.kind == LibraryReportKind.monthly,
            ),
            const SizedBox(height: 18),
            LibraryReportTable(
              header: header,
              rows: rows,
              sumColumns: sumColumns,
              searchQuery: _searchQuery,
              isLoading: library.insightsLoading,
              errorMessage: library.errorMessage,
              footerNote: footerNote,
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ],
        ),
      ),
    );
  }
}
