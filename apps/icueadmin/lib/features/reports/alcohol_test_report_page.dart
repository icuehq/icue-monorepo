import 'package:core_ui/core_ui.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/reports/widgets/alcohol_report_card.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:icueadmin/features/reports/widgets/report_filter_bar.dart';
import 'package:provider/provider.dart';
import 'package:reports/reports.dart';

class AlcoholTestReportPage extends StatefulWidget {
  const AlcoholTestReportPage({super.key});

  @override
  State<AlcoholTestReportPage> createState() => _AlcoholTestReportPageState();
}

class _AlcoholTestReportPageState extends State<AlcoholTestReportPage> {
  int _page = 1;
  Driver? _selectedDriver;
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
      context.read<DriverProvider>().fetchDrivers();
      _fetchData(isInitial: true);
    });
  }

  void _fetchData({bool isInitial = false}) {
    if (isInitial) {
      _page = 1;
    }
    context.read<ReportsProvider>().fetchAlcoholTestReport(
      filter: _filterResult,
      page: _page,
      personId: _selectedDriver?.id,
    );
  }

  void _loadMore() {
    _page++;
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final driverProvider = context.watch<DriverProvider>();
    final reports = reportsProvider.alcoholTestReports;
    final total = reportsProvider.alcoholMetadata?.total ?? 0;
    final hasMore = total > reports.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Alcohol Test Report'),
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
            child: AppSearchableAutocomplete<Driver>(
              hintText: 'Filter by driver name or mobile...',
              optionsBuilder: (textEditingValue) {
                final list = driverProvider.drivers;
                if (textEditingValue.text.isEmpty) return list;
                final q = textEditingValue.text.toLowerCase();
                return list.where(
                  (d) => '${d.firstName} ${d.lastName ?? ''} ${d.mobile ?? ''}'
                      .toLowerCase()
                      .contains(q),
                );
              },
              displayStringForOption: (d) =>
                  '${d.firstName} ${d.lastName ?? ''}'.trim(),
              initialSelection: _selectedDriver,
              onSelected: (d) {
                setState(() => _selectedDriver = d);
                _fetchData(isInitial: true);
              },
              onCleared: () {
                setState(() => _selectedDriver = null);
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

                              return AlcoholReportCard(record: reports[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
