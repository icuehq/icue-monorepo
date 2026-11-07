import 'package:admin_ui/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// One inventory report: server filters (date range, status), then the shared report table.
class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({required this.def, super.key});

  final ReportDef def;

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  DateTimeRange? _range;
  String? _status;

  ReportDef get _def => widget.def;

  Future<void> _load() async {
    final inventory = context.read<InventoryProvider>();
    if (inventory.stores.isEmpty) await inventory.loadMasters();
    if (!mounted) return;
    await context.read<InsightsProvider>().loadReport(
      inventory.access,
      _def,
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
    final insights = context.watch<InsightsProvider>();
    final inventory = context.watch<InventoryProvider>();
    final names = ReportNames(
      item: insights.itemName,
      store: (id) =>
          inventory.stores.where((store) => store.id == id).firstOrNull?.name ??
          '${id ?? ''}',
    );
    return ReportScreen(
      title: _def.title,
      header: [for (final column in _def.cols) column.label],
      rows: [
        for (final row in insights.rows)
          [for (final column in _def.cols) column.cell(row, names)],
      ],
      sumColumns: {
        for (var index = 0; index < _def.cols.length; index++)
          if (_def.cols[index].sum) index,
      },
      searchHint: 'Search these rows (item, vendor, person…)',
      isLoading: insights.isLoading,
      errorMessage: insights.errorMessage,
      footerNote: insights.rows.length >= InsightsService.reportLimit
          ? 'Showing the latest ${InsightsService.reportLimit} rows; narrow the date range.'
          : null,
      filters: ReportFilterBar(
        showDateRange: _def.hasDates,
        range: _range,
        onRangeChanged: (range) {
          setState(() => _range = range);
          _load();
        },
        statuses: _def.statuses,
        status: _status,
        onStatusChanged: (status) {
          setState(() => _status = status);
          _load();
        },
      ),
    );
  }
}
