import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:icueadmin/features/reports/widgets/report_filter_bar.dart';
import 'package:provider/provider.dart';
import 'package:reports/reports.dart';
import 'package:vehicles/vehicles.dart';

class ArrivalTimeReportPage extends StatefulWidget {
  const ArrivalTimeReportPage({super.key});

  @override
  State<ArrivalTimeReportPage> createState() => _ArrivalTimeReportPageState();
}

class _ArrivalTimeReportPageState extends State<ArrivalTimeReportPage> {
  String _mode = 'Pickup';
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
    context.read<ReportsProvider>().fetchArrivalTimeReport(
          filter: _filterResult,
          mode: _mode,
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
    final reports = reportsProvider.arrivalTimeReports;
    final total = reportsProvider.arrivalMetadata?.total ?? 0;
    final hasMore = total > reports.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Arrival Time'),
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
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Pickup', label: Text('Pickup')),
                ButtonSegment(value: 'Drop', label: Text('Drop')),
              ],
              selected: {_mode},
              onSelectionChanged: (set) {
                setState(() => _mode = set.first);
                _fetchData(isInitial: true);
              },
            ),
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

                              final item = reports[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.vehicleNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Route ${item.routeNo}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildDetailCol(
                                            'Trip Start',
                                            '${item.startDate} ${item.startTime}'.trim(),
                                          ),
                                          _buildDetailCol(
                                            'Arrival Time',
                                            item.arrivalTime ?? 'Pending',
                                            isHighlight: item.arrivalTime != null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCol(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? Colors.green.shade700 : Colors.black87,
          ),
        ),
      ],
    );
  }
}
