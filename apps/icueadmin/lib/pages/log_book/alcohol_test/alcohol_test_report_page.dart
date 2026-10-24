import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../../models/alcohol_test_report.dart';
import '../../../models/drivers.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../utils/app_utils.dart';
import '../../../utils/constants.dart';
import '../../../widgets/driver_auto_complete_field.dart';
import '../../../widgets/no_data_widget.dart';
import '../../../widgets/report_filter_modal.dart';
import '../../vehicle_management/reports/image_view.dart';

class AlcoholTestReportPage extends StatefulWidget {
  const AlcoholTestReportPage({super.key, this.personId});

  final int? personId;

  @override
  State<AlcoholTestReportPage> createState() => _AlcoholTestReportPageState();
}

class _AlcoholTestReportPageState extends State<AlcoholTestReportPage> {
  int _currentPage = 1;
  late final TextEditingController _driverSearchController;
  FilterMode _filterMode = FilterMode.bymonth;
  final ScrollController _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  Driver? _selectedDriver;
  String _selectedMonth = months[DateTime.now().month - 1]['val']!;
  DateTimeRange? _selectedRange;
  String _selectedYear = DateTime.now().year.toString();

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _driverSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _driverSearchController = TextEditingController();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      final driverProvider = context.read<DriverProvider>();
      driverProvider.getDrivers().then((_) {
        if (widget.personId != null) {
          final initialDriver = driverProvider.drivers
              .where((d) => d.id == widget.personId)
              .firstOrNull;
          if (initialDriver != null) {
            _selectedDriver = initialDriver;
            _driverSearchController.text = _fullName(initialDriver);
          } else {
            _driverSearchController.text = '';
          }
        }
      });
      _fetchPage(1);
    });
    _scrollController.addListener(_onScroll);
  }

  String _fullName(Driver d) {
    final parts = [
      d.firstName,
      d.middleName,
      d.lastName,
    ].where((e) => e != null && e.isNotEmpty).cast<String>().toList();
    return parts.join(' ');
  }

  void _onScroll() {
    if (!mounted) return;
    final provider = context.read<ReportsProvider>();
    final hasMore =
        provider.alcoholTestReport.length < (provider.metadata?.total ?? 0);

    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !provider.loading &&
        hasMore) {
      _fetchPage(_currentPage + 1);
    }
  }

  void _fetchPage(int page) {
    if (!mounted) return;
    final rpt = context.read<ReportsProvider>();

    if (page == 1) {
      rpt.clearData();
      if (_currentPage != 1) {
        setState(() => _currentPage = 1);
      }
    } else if (_currentPage != page) {
      setState(() => _currentPage = page);
    }

    rpt.getAlcoholTestReport(
      reportMode: _filterMode,
      personId: widget.personId ?? _selectedDriver?.id,
      month: _selectedMonth,
      year: _selectedYear,
      startDate: _filterMode == FilterMode.bydate
          ? _selectedDate
          : _selectedRange?.start,
      endDate: _selectedRange?.end,
      page: page,
    );
  }

  Future<void> _refresh() async => _fetchPage(1);

  Future<void> _openFilterSheet() async {
    final result = await ReportFilterModal.show(
      context,
      month: _selectedMonth,
      year: _selectedYear,
      range: _selectedRange,
      filterMode: _filterMode,
      date: _selectedDate,
    );
    if (result == null) return;
    var shouldFetch = false;

    setState(() {
      if (result.mode == FilterMode.bydate) {
        if (_selectedDate != result.date || _filterMode != FilterMode.bydate) {
          _selectedDate = result.date ?? DateTime.now();
          _selectedRange = null;
          _filterMode = FilterMode.bydate;
          shouldFetch = true;
        }
      } else if (result.mode == FilterMode.bymonth) {
        if (_selectedMonth != result.month ||
            _selectedYear != result.year ||
            _filterMode != FilterMode.bymonth) {
          _selectedRange = null;
          _selectedMonth = result.month!;
          _selectedYear = result.year!;
          _filterMode = FilterMode.bymonth;
          shouldFetch = true;
        }
      } else {
        if (_selectedRange != result.range ||
            _filterMode != FilterMode.byperiod) {
          _selectedRange = result.range!;
          _filterMode = FilterMode.byperiod;
          shouldFetch = true;
        }
      }
    });

    if (shouldFetch) {
      _fetchPage(1);
    }
  }

  Widget _buildBody() {
    return Selector<
      ReportsProvider,
      ({bool loading, List<AlcoholTest> rows, int totalRecords})
    >(
      selector: (_, provider) => (
        loading: provider.loading,
        rows: provider.alcoholTestReport,
        totalRecords: provider.metadata?.total ?? 0,
      ),
      builder: (context, data, child) {
        final rows = data.rows;
        final totalRecords = data.totalRecords;
        final hasMore = rows.length < totalRecords;

        if (data.loading && rows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (rows.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: const NoDataWidget(msg: 'No Records Found!'),
                ),
              );
            },
          );
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(12),
          itemCount: rows.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == rows.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final item = rows[index];
            return _ReportCard(item: item);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alcohol Test Report'),
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
            child: DriverAutoCompleteField(
              selectedDriver: _selectedDriver,
              fullName: _fullName,
              onDriverSelected: (drv) {
                setState(() => _selectedDriver = drv);
                _fetchPage(1);
              },
              onDriverCleared: () {
                setState(() => _selectedDriver = null);
                _fetchPage(1);
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item});

  final AlcoholTest item;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'fail':
        return Colors.red.shade400;
      case 'pass':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade500;
    }
  }

  Widget _infoChip(String label, String value) {
    return Chip(
      label: Text('$label: $value', style: const TextStyle(fontSize: 13)),
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _statusChip(String status) {
    final statusLower = status.toLowerCase();
    final isFail = statusLower == 'fail';
    return Chip(
      avatar: Icon(
        isFail ? Icons.warning : Icons.check_circle,
        color: Colors.white,
        size: 18,
      ),
      label: Text(
        status,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: _statusColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = item.personInfo?.name ?? 'N/A';
    final testStatus = item.alcoholTest ?? 'N/A';
    final hasImage = item.imageUrl?.isNotEmpty == true;

    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.submittedDate.formatAsIndianDate(fallback: '')} • ${item.submittedTime.formatAsIndianTime(fallback: '')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasImage)
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ImageView(url: item.imageUrl!, isBase64: false),
                        ),
                      );
                    },
                    icon: const Icon(Icons.image, color: Colors.blue),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Info Section
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _infoChip('Type', item.personType ?? 'N/A'),
                _infoChip('Mobile', item.personInfo?.mobile ?? 'N/A'),
                _statusChip(testStatus),
                _infoChip(
                  'Reading',
                  item.alcoholTestReading?.toString() ?? 'N/A',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
