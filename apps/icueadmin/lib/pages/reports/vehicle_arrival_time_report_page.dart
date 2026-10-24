import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../models/arrival_time_report.dart';
import '../../models/vehicle.dart';
import '../../providers/reports_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../utils/app_utils.dart';
import '../../utils/constants.dart';
import '../../widgets/dropdown.dart';
import '../../widgets/no_data_widget.dart';
import '../../widgets/report_filter_modal.dart';
import '../../widgets/vehicle_autocomplete_field.dart';

class VehicleArrivalTimeReportPage extends StatefulWidget {
  const VehicleArrivalTimeReportPage({super.key});

  @override
  State<VehicleArrivalTimeReportPage> createState() =>
      _VehicleArrivalTimeReportPageState();
}

class _VehicleArrivalTimeReportPageState
    extends State<VehicleArrivalTimeReportPage> {
  FilterMode _filterMode = FilterMode.bymonth;
  String _mode = 'Pickup';
  int _page = 1;
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = months[DateTime.now().month - 1]['val']!;
  DateTimeRange? _selectedRange;
  Vehicle? _selectedVehicle;
  String _selectedYear = DateTime.now().year.toString();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().getVehicles();
      _loadData(isInitialLoad: true);
    });
  }

  void _loadData({bool isInitialLoad = false}) {
    if (!mounted) return;
    final provider = context.read<ReportsProvider>();

    if (isInitialLoad) {
      _page = 1;
      provider.clearData();
    } else if (_page != _page) {
      // Logic error in original: `_page` is always equal to `_page`.
      // Corrected logic: `_page` is incremented in `_loadMore`, so no need for setState there.
    }

    provider.getArrivalTimeReport(
      page: _page,
      month: _selectedMonth,
      year: _selectedYear,
      mode: _mode,
      reportMode: _filterMode,
      startDate: _filterMode == FilterMode.bydate
          ? _selectedDate
          : _selectedRange?.start,
      endDate: _selectedRange?.end,
      vehicleNo: _selectedVehicle?.number,
    );
  }

  void _loadMore() {
    _page++;
    _loadData();
  }

  Future<void> _refresh() async => _loadData(isInitialLoad: true);

  Future<void> _openFilterSheet() async {
    final result = await ReportFilterModal.show(
      context,
      month: _selectedMonth,
      year: _selectedYear,
      range: _selectedRange,
      filterMode: _filterMode,
      date: _selectedDate,
    );
    if (result == null || !mounted) return;

    var shouldFetch = false;
    final oldFilterMode = _filterMode;

    setState(() {
      _filterMode = result.mode;
      switch (result.mode) {
        case FilterMode.bydate:
          if (oldFilterMode != FilterMode.bydate ||
              _selectedDate != result.date) {
            _selectedDate = result.date ?? DateTime.now();
            _selectedRange = null;
            shouldFetch = true;
          }
          break;
        case FilterMode.bymonth:
          if (oldFilterMode != FilterMode.bymonth ||
              _selectedMonth != result.month ||
              _selectedYear != result.year) {
            _selectedMonth = result.month!;
            _selectedYear = result.year!;
            _selectedRange = null;
            shouldFetch = true;
          }
          break;
        case FilterMode.byperiod:
          if (oldFilterMode != FilterMode.byperiod ||
              _selectedRange != result.range) {
            _selectedRange = result.range!;
            shouldFetch = true;
          }
          break;
      }
    });

    if (shouldFetch) {
      _loadData(isInitialLoad: true);
    }
  }

  // Handle vehicle mode change.
  void _onModeChanged(String? newMode) {
    if (newMode == null || newMode == _mode) return;
    setState(() {
      _mode = newMode;
    });
    _loadData(isInitialLoad: true);
  }

  Widget _buildLoadMoreIndicator(ReportsProvider provider) {
    final hasMore =
        (provider.metadata?.total ?? 0) > provider.arrivalTimeReports.length;

    if (provider.loading && hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ElevatedButton(
          onPressed: _loadMore,
          child: const Text('Load More'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Arrival Time Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _openFilterSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReportFilters(mode: _mode, onChanged: _onModeChanged),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: VehicleAutocompleteField(
                  selectedVehicle: _selectedVehicle,
                  onVehicleSelected: (selection) {
                    setState(() => _selectedVehicle = selection);
                    _loadData(isInitialLoad: true);
                  },
                  onVehicleCleared: () {
                    setState(() => _selectedVehicle = null);
                    _loadData(isInitialLoad: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, child) {
          final reports = provider.arrivalTimeReports;

          if (provider.loading && reports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (reports.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: const NoDataWidget(msg: 'No Records Found!'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemCount: reports.length + 1,
              itemBuilder: (context, index) {
                if (index == reports.length) {
                  return _buildLoadMoreIndicator(provider);
                }
                final report = reports[index];
                return _ReportListItem(report: report);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Dropdown(
        title: 'Select Mode',
        value: mode,
        filled: true,
        onChanged: onChanged,
        items: getDropDownMenuItems(['Pickup', 'Drop']),
      ),
    );
  }
}

class _ReportListItem extends StatelessWidget {
  const _ReportListItem({required this.report});

  final TimeReport report;

  @override
  Widget build(BuildContext context) {
    final isRouteEnded =
        report.arrivalTime == null || report.arrivalTime!.isEmpty;
    final color = isRouteEnded ? Colors.red : Colors.green;

    return ExpansionTile(
      dense: true,
      childrenPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: color),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: color),
      ),
      leading: Icon(Icons.bus_alert_outlined, color: color, size: 30),
      title: Text(
        report.vehicleNumber,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(report.routeNo),
          Text(
            report.mode,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
      children: [
        _ReportDetails(
          report: report,
          isRouteEnded: isRouteEnded,
          color: color,
        ),
      ],
    );
  }
}

class _ReportDetails extends StatelessWidget {
  const _ReportDetails({
    required this.report,
    required this.isRouteEnded,
    required this.color,
  });

  final Color color;
  final bool isRouteEnded;
  final TimeReport report;

  Widget _buildDetailRow(String label, String value, {Color? highlightColor}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlightColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Optimization: Pre-calculate values to avoid repeated logic inside the build method
    final arrivalTimeText = isRouteEnded
        ? report.endTime.formatAsIndianTime()
        : report.arrivalTime.formatAsIndianTime();
    final arrivalTimeLabel = isRouteEnded
        ? 'Route Ended Time: '
        : 'Arrival Time: ';
    final startedTimeText = '${report.startDate} ${report.startTime}'
        .formatAsIndianFullDateTime();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(
          arrivalTimeLabel,
          arrivalTimeText,
          highlightColor: color, // Use the passed-down color
        ),
        const SizedBox(height: 8),
        _buildDetailRow('Started Time: ', startedTimeText),
        if (report.endDate != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            'Ended Time: ',
            '${report.endDate} ${report.endTime}'.formatAsIndianFullDateTime(),
          ),
        ],
      ],
    );
  }
}
