import 'package:flutter/material.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:inventory/src/ui/insights/reports/widgets/inventory_report_table.dart';
import 'package:inventory/src/ui/shared/widgets/inventory_status_chip.dart';
import 'package:provider/provider.dart';

/// One inventory report: the period reloads from Firestore; store and the report's own filter
/// narrow the loaded rows, which the table searches, sorts and pages.
class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({required this.report, super.key});

  final InventoryReport report;

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  IcueDatePreset _preset = IcueDatePreset.currentMonth;
  late DateTimeRange _range = _preset.range();
  String? _filter;
  String? _storeId;

  InventoryReport get _report => widget.report;

  Future<void> _load() async {
    final inventory = context.read<InventoryProvider>();
    if (inventory.stores.isEmpty) await inventory.loadMasters();
    if (!mounted) return;
    await context.read<InsightsProvider>().loadReport(
      _report,
      from: _range.start,
      to: _range.end,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _onPresetChanged(IcueDatePreset preset) async {
    var range = preset.range();
    if (preset == IcueDatePreset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: _range,
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _preset = preset;
      _range = range;
    });
    await _load();
  }

  Future<void> _export(ReportTable table) async {
    final csv = toCsv(table.header, [
      for (final row in table.rows)
        [
          for (var index = 0; index < row.length; index++)
            table.columns[index].kind == ReportCell.status
                ? inventoryStatusLabel(row[index])
                : row[index],
        ],
    ]);
    final saved = await saveCsvFile('${_report.name}-report.csv', csv);
    if (!mounted) return;
    if (!saved) return IcueToast.info(context, 'Download cancelled');
    IcueToast.success(
      context,
      'Downloaded ${table.rows.length} ${table.rows.length == 1 ? 'row' : 'rows'} as CSV',
    );
  }

  List<IcueTableFilter> _filters(InventoryProvider inventory) => [
    if (_report.source.hasDates)
      IcueTableFilter(
        id: 'period',
        label: 'Period',
        allowAll: false,
        options: [
          for (final preset in IcueDatePreset.values)
            IcueTableFilterOption(
              preset.name,
              preset == IcueDatePreset.custom && _preset == preset
                  ? '${_range.start.toNumericDate()} – ${_range.end.toNumericDate()}'
                  : preset.label,
            ),
        ],
        value: _preset.name,
        onChanged: (name) => _onPresetChanged(
          name == null
              ? IcueDatePreset.currentMonth
              : IcueDatePreset.values.byName(name),
        ),
      ),
    if (inventory.showStoreFilter)
      IcueTableFilter(
        id: 'store',
        label: 'Store',
        options: [
          for (final store in inventory.stores)
            IcueTableFilterOption(store.id, store.name),
        ],
        value: _storeId,
        onChanged: (storeId) => setState(() => _storeId = storeId),
      ),
    if (_report.filters.isNotEmpty)
      IcueTableFilter(
        id: 'filter',
        label: _report.filterLabel,
        options: [
          for (final filter in _report.filters)
            IcueTableFilterOption(
              filter,
              humanizeStatus(filter, overrides: InventoryReport.filterLabels),
            ),
        ],
        value: _filter,
        onChanged: (filter) => setState(() => _filter = filter),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final insights = context.watch<InsightsProvider>();
    final inventory = context.watch<InventoryProvider>();
    final table = buildReport(
      _report,
      ReportInput(
        documents: insights.documents,
        items: insights.items,
        categoryNames: {
          for (final category in inventory.categories)
            category.id: category.name,
        },
        storeNames: {
          for (final store in inventory.stores) store.id: store.name,
        },
        today: todayIST(),
        balances: insights.balances,
        periodEnd: _range.end.toApiDate(),
      ),
      storeId: _storeId,
      filter: _filter,
    );
    final theme = Theme.of(context);
    final capped = insights.documents.length >= InsightsService.reportLimit;
    final intro = Text(
      capped
          ? 'Only the latest ${InsightsService.reportLimit} records are included. Choose a shorter period for complete figures.'
          : _report.description,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: capped
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
    final reportTable = InventoryReportTable(
      table: table,
      filters: _filters(inventory),
      filtersActive: _storeId != null || _filter != null,
      onClearFilters: () => setState(() {
        _storeId = null;
        _filter = null;
      }),
      isLoading: insights.isLoading,
      errorMessage: insights.errorMessage,
      onRetry: _load,
      onExport: table.rows.isEmpty ? null : () => _export(table),
    );
    final padding = EdgeInsets.symmetric(
      horizontal: context.isWide ? 24 : 16,
      vertical: 20,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_report.title),
        bottom: insights.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: IcueCenteredBody(
        maxWidth: double.infinity,
        // Wide: the table fills the screen and scrolls under its header.
        child: context.isWide
            ? Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    intro,
                    const SizedBox(height: 16),
                    Expanded(child: reportTable),
                  ],
                ),
              )
            : ListView(
                padding: padding,
                children: [intro, const SizedBox(height: 16), reportTable],
              ),
      ),
    );
  }
}
