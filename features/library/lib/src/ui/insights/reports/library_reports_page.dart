import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  Future<void> _exportCsv(List<String> header, List<List<String>> rows) async {
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
              .where(
                (row) => row.any((cell) => cell.toLowerCase().contains(query)),
              )
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
        actions: [
          AppButton(
            label: 'Export CSV',
            variant: AppButtonVariant.outline,
            size: AppButtonSize.small,
            leadingIcon: Icons.download_rounded,
            onPressed: rows.isNotEmpty ? () => _exportCsv(header, rows) : null,
          ),
          const SizedBox(width: 8),
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
      body: CenteredBody(
        maxWidth: double.infinity,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 20,
          ),
          children: [
            LibraryReportFilters(
              reports: libraryReports,
              selectedReport: _def,
              onReportChanged: _onReportChanged,
              datePreset: _datePreset,
              onDatePresetChanged: _onDatePresetChanged,
              range: _range,
              onRangeChanged: _onRangeChanged,
              libraries: library.libraries,
              selectedLibraryId: _libraryId,
              onLibraryChanged: (libraryId) {
                setState(() => _libraryId = libraryId);
                _load();
              },
              statuses: _def.statuses,
              selectedStatus: _status,
              onStatusChanged: (status) {
                setState(() => _status = status);
                _load();
              },
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              onClearSearch: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              rowCount: rows.length,
              filteredRowCount: filteredCount,
            ),
            const SizedBox(height: 18),
            LibraryReportKpis(kind: _def.kind, rows: library.reportRows),
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
