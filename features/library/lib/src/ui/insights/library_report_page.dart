import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_library/school_library.dart';

/// One library report: server filters (library, date range, status), then the shared report table.
class LibraryReportPage extends StatefulWidget {
  const LibraryReportPage({required this.def, super.key});

  final LibraryReportDef def;

  @override
  State<LibraryReportPage> createState() => _LibReportPageState();
}

class _LibReportPageState extends State<LibraryReportPage> {
  DateTimeRange? _range;
  String? _status;
  String? _libraryId;

  LibraryReportDef get _def => widget.def;

  Future<void> _load() async {
    final library = context.read<LibraryProvider>();
    if (library.libraries.isEmpty) await library.loadMasters();
    if (!mounted) return;
    await library.loadReport(
      _def,
      library: library.libraries
          .where((schoolLibrary) => schoolLibrary.id == _libraryId)
          .firstOrNull,
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

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final names = LibraryNames(
      title: library.titleName,
      library: library.libraryName,
      category: library.categoryName,
    );
    return ReportScreen(
      title: _def.title,
      header: [for (final column in _def.cols) column.label],
      rows: [
        for (final row in library.reportRows)
          [for (final column in _def.cols) column.cell(row, names)],
      ],
      sumColumns: {
        for (var index = 0; index < _def.cols.length; index++)
          if (_def.cols[index].sum) index,
      },
      searchHint: 'Search these rows (member, author, category…)',
      isLoading: library.insightsLoading,
      errorMessage: library.errorMessage,
      footerNote:
          _def.type == LibraryReportType.query &&
              library.reportRows.length >= LibraryService.reportLimit
          ? 'Showing the latest ${LibraryService.reportLimit} rows; narrow the date range.'
          : null,
      filters: Column(
        children: [
          if (_def.hasLibrary)
            DropdownButton<String?>(
              isExpanded: true,
              value: _libraryId,
              items: [
                const DropdownMenuItem(child: Text('All libraries')),
                for (final schoolLibrary in library.libraries)
                  DropdownMenuItem(
                    value: schoolLibrary.id,
                    child: Text(schoolLibrary.name),
                  ),
              ],
              onChanged: (id) {
                _libraryId = id;
                _load();
              },
            ),
          ReportFilterBar(
            showDateRange: _def.hasDates && !_def.overdue,
            range: _range,
            onRangeChanged: (range) {
              _range = range;
              _load();
            },
            statuses: _def.statuses,
            status: _status,
            onStatusChanged: (status) {
              _status = status;
              _load();
            },
          ),
        ],
      ),
    );
  }
}
