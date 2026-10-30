import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/reports/widgets/cleaning_report_card.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:icueadmin/features/reports/widgets/report_filter_bar.dart';
import 'package:provider/provider.dart';
import 'package:reports/reports.dart';
import 'package:vehicles/vehicles.dart';

class CleaningReportPage extends StatefulWidget {
  const CleaningReportPage({super.key});

  @override
  State<CleaningReportPage> createState() => _CleaningReportPageState();
}

class _CleaningReportPageState extends State<CleaningReportPage> {
  int _page = 1;
  Vehicle? _selectedVehicle;
  late AppFilterResult _filterResult;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterResult = AppFilterResult.byMonth(
      month: now.month.toString().padLeft(2, '0'),
      year: now.year.toString(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicles();
      _fetchData(isInitial: true);
    });
  }

  void _fetchData({bool isInitial = false}) {
    if (isInitial) {
      _page = 1;
    }
    context.read<ReportsProvider>().fetchCleaningReport(
      filter: _filterResult,
      page: _page,
      vehicleNo: _selectedVehicle?.number,
    );
  }

  void _loadMore() {
    _page++;
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();
    final reports = reportsProvider.cleaningReports;
    final total = reportsProvider.cleaningMetadata?.total ?? 0;
    final hasMore = total > reports.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaning Inspection Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchData(isInitial: true),
          ),
        ],
      ),
      body: Column(
        children: [
          ReportFilterBar(
            currentFilter: _filterResult,
            onFilterChanged: (newFilter) {
              setState(() => _filterResult = newFilter);
              _fetchData(isInitial: true);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppSearchableAutocomplete<Vehicle>(
              hintText: 'Filter by vehicle number...',
              optionsBuilder: (textEditingValue) {
                final list = vehicleProvider.vehicles;
                if (textEditingValue.text.isEmpty) return list;
                final q = textEditingValue.text.toLowerCase();
                return list.where((v) => v.number.toLowerCase().contains(q));
              },
              displayStringForOption: (v) => v.number,
              initialSelection: _selectedVehicle,
              onSelected: (v) {
                setState(() => _selectedVehicle = v);
                _fetchData(isInitial: true);
              },
              onCleared: () {
                setState(() => _selectedVehicle = null);
                _fetchData(isInitial: true);
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: reportsProvider.isLoading && reports.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async => _fetchData(isInitial: true),
                    child: reports.isEmpty
                        ? ReportEmptyState(
                            onRetry: () => _fetchData(isInitial: true),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: reports.length + (hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == reports.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: reportsProvider.isLoading
                                        ? const CircularProgressIndicator()
                                        : ElevatedButton(
                                            onPressed: _loadMore,
                                            child: const Text('Load More'),
                                          ),
                                  ),
                                );
                              }

                              return CleaningReportCard(report: reports[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
