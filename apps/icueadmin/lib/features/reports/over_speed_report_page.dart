import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:icueadmin/features/reports/widgets/speed_violation_card.dart';
import 'package:provider/provider.dart';
import 'package:reports/reports.dart';
import 'package:vehicles/vehicles.dart';

class OverSpeedReportPage extends StatefulWidget {
  const OverSpeedReportPage({super.key});

  @override
  State<OverSpeedReportPage> createState() => _OverSpeedReportPageState();
}

class _OverSpeedReportPageState extends State<OverSpeedReportPage> {
  Vehicle? _selectedVehicle;
  String _selectedMonth = DateTime.now().month.toString().padLeft(2, '0');
  String _selectedYear = DateTime.now().year.toString();
  String _selectedSpeedLimit = '50';

  static const List<Map<String, String>> _months = [
    {'val': '01', 'name': 'January'},
    {'val': '02', 'name': 'February'},
    {'val': '03', 'name': 'March'},
    {'val': '04', 'name': 'April'},
    {'val': '05', 'name': 'May'},
    {'val': '06', 'name': 'June'},
    {'val': '07', 'name': 'July'},
    {'val': '08', 'name': 'August'},
    {'val': '09', 'name': 'September'},
    {'val': '10', 'name': 'October'},
    {'val': '11', 'name': 'November'},
    {'val': '12', 'name': 'December'},
  ];

  static const List<String> _speedLimits = ['30', '40', '50', '60', '70', '80'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicles();
    });
  }

  void _fetchData() {
    if (_selectedVehicle == null) return;
    context.read<ReportsProvider>().fetchOverSpeedReports(
      vehicleNumber: _selectedVehicle!.number,
      month: _selectedMonth,
      year: _selectedYear,
      speedLimit: _selectedSpeedLimit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();
    final violations = reportsProvider.overSpeedList;
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => (currentYear - i).toString());

    return Scaffold(
      appBar: AppBar(title: const Text('Over-Speed Violations')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                AppSearchableAutocomplete<Vehicle>(
                  label: 'Vehicle *',
                  hintText: 'Select vehicle to inspect speed violations...',
                  optionsBuilder: (textEditingValue) {
                    final list = vehicleProvider.vehicles;
                    if (textEditingValue.text.isEmpty) return list;
                    final q = textEditingValue.text.toLowerCase();
                    return list.where(
                      (v) => v.number.toLowerCase().contains(q),
                    );
                  },
                  displayStringForOption: (v) => v.number,
                  initialSelection: _selectedVehicle,
                  onSelected: (v) {
                    setState(() => _selectedVehicle = v);
                    _fetchData();
                  },
                  onCleared: () {
                    setState(() => _selectedVehicle = null);
                    context.read<ReportsProvider>().clearData();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          isDense: true,
                        ),
                        items: _months
                            .map(
                              (m) => DropdownMenuItem(
                                value: m['val'],
                                child: Text(m['name']!),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMonth = val);
                            _fetchData();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          isDense: true,
                        ),
                        items: years
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedYear = val);
                            _fetchData();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSpeedLimit,
                        decoration: const InputDecoration(
                          labelText: 'Limit (km/h)',
                          isDense: true,
                        ),
                        items: _speedLimits
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text('$s km/h'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSpeedLimit = val);
                            _fetchData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (violations.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${violations.length} Violation(s) recorded',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.red.shade800,
                    ),
                  ),
                  Text(
                    'Threshold: >$_selectedSpeedLimit km/h',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _selectedVehicle == null
                ? const ReportEmptyState(
                    icon: Icons.speed_rounded,
                    message:
                        'Please choose a vehicle to view over-speed incidents.',
                  )
                : reportsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : violations.isEmpty
                ? ReportEmptyState(
                    message:
                        'No over-speed incidents detected for ${_selectedVehicle!.number} exceeding $_selectedSpeedLimit km/h in $_selectedMonth/$_selectedYear.',
                    onRetry: _fetchData,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: violations.length,
                    itemBuilder: (context, index) {
                      return SpeedViolationCard(record: violations[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
