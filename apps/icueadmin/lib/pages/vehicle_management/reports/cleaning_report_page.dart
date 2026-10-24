import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../models/vehicle.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../utils/app_utils.dart';
import '../../../utils/constants.dart';
import '../../../widgets/no_data_widget.dart';
import '../../../widgets/report_filter_modal.dart';
import '../../../widgets/vehicle_autocomplete_field.dart';

class CleaningReportPage extends StatefulWidget {
  const CleaningReportPage({super.key, this.vehicleId, this.vehicleNumber});

  final int? vehicleId;
  final String? vehicleNumber;

  @override
  State<CleaningReportPage> createState() => _CleaningReportPageState();
}

class _CleaningReportPageState extends State<CleaningReportPage> {
  FilterMode _filterMode = FilterMode.bymonth;
  int _page = 1;
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = months[DateTime.now().month - 1]['val']!;
  DateTimeRange? _selectedRange;
  String _selectedYear = DateTime.now().year.toString();
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().getVehicles();
      _loadPage(1);
    });
  }

  void _loadPage(int page) {
    final provider = Provider.of<ReportsProvider>(context, listen: false);
    if (page == 1) provider.clearData();
    provider.getCleaningReport(
      page: page,
      vehicleId: widget.vehicleId,
      month: _selectedMonth,
      year: _selectedYear,
      reportMode: _filterMode,
      startDate: _filterMode == FilterMode.bydate
          ? _selectedDate
          : _selectedRange?.start,
      endDate: _selectedRange?.end,
      vehicleNo: _selectedVehicle?.number,
    );
    setState(() => _page = page);
  }

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

    setState(() {
      _filterMode = result.mode;
      switch (result.mode) {
        case FilterMode.bydate:
          _selectedDate = result.date ?? DateTime.now();
          _selectedRange = null;
          break;
        case FilterMode.bymonth:
          _selectedMonth = result.month!;
          _selectedYear = result.year!;
          _selectedRange = null;
          break;
        case FilterMode.byperiod:
          _selectedRange = result.range!;
          break;
      }
    });
    _loadPage(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.vehicleNumber == null
              ? 'Vehicle Cleaning Report'
              : '${widget.vehicleNumber} - Cleaning Report',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _openFilterSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: VehicleAutocompleteField(
              selectedVehicle: _selectedVehicle,
              onVehicleSelected: (selection) {
                setState(() => _selectedVehicle = selection);
                _loadPage(1);
              },
              onVehicleCleared: () {
                setState(() => _selectedVehicle = null);
                _loadPage(1);
              },
            ),
          ),
        ),
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, child) {
          // initial loading state
          if (provider.loading && _page == 1) {
            return const Center(child: CircularProgressIndicator());
          }
          // no data
          if (provider.cleaningReport.isEmpty) {
            return const NoDataWidget(msg: 'No Records Found!');
          }
          // data + load more as last list item
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemCount: provider.cleaningReport.length + 1,
            itemBuilder: (context, index) {
              if (index < provider.cleaningReport.length) {
                final report = provider.cleaningReport[index];
                return ExpansionTile(
                  dense: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(color: Colors.green),
                  ),
                  collapsedShape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(color: Colors.green),
                  ),
                  leading: const Icon(
                    Icons.cleaning_services,
                    color: Colors.green,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        report.createdDate.formatAsIndianDate(fallback: ''),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        report.createdTime.formatAsIndianTime(fallback: ''),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    report.vehicleNo ?? 'Unknown Vehicle',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  children:
                      report.cleanedData != null &&
                          report.cleanedData!.isNotEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                for (var part in report.cleanedData!)
                                  SizedBox(
                                    width:
                                        (MediaQuery.of(context).size.width /
                                            2) -
                                        40,
                                    child: RichText(
                                      text: TextSpan(
                                        text: '${part.name}: ',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: part.status,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: part.status == 'Yes'
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ]
                      : const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No cleaning data available.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                );
              }

              // load-more row
              if (provider.loading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (provider.metadata?.total == provider.cleaningReport.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ElevatedButton(
                  onPressed: () => _loadPage(_page + 1),
                  child: const Text('Load More'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
