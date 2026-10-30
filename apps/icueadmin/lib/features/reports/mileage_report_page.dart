import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/features/reports/widgets/report_empty_state.dart';
import 'package:provider/provider.dart';
import 'package:reports/reports.dart';
import 'package:vehicles/vehicles.dart';

class MileageReportPage extends StatefulWidget {
  const MileageReportPage({super.key});

  @override
  State<MileageReportPage> createState() => _MileageReportPageState();
}

class _MileageReportPageState extends State<MileageReportPage> {
  Vehicle? _selectedVehicle;
  String _selectedMonth = DateTime.now().month.toString().padLeft(2, '0');
  String _selectedYear = DateTime.now().year.toString();

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicles();
    });
  }

  void _fetchData() {
    if (_selectedVehicle == null) return;
    context.read<ReportsProvider>().fetchMileageReports(
          vehicleNumber: _selectedVehicle!.number,
          month: _selectedMonth,
          year: _selectedYear,
        );
  }

  @override
  Widget build(BuildContext context) {
    final reportsProvider = context.watch<ReportsProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();
    final reports = reportsProvider.mileageReports;
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => (currentYear - i).toString());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mileage Analytics Report'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                AppSearchableAutocomplete<Vehicle>(
                  label: 'Vehicle *',
                  hintText: 'Select vehicle to view mileage...',
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          isDense: true,
                        ),
                        items: years
                            .map(
                              (y) => DropdownMenuItem(
                                value: y,
                                child: Text(y),
                              ),
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
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedVehicle == null
                ? const ReportEmptyState(
                    icon: Icons.directions_bus_outlined,
                    message: 'Please choose a vehicle to view mileage analytics.',
                  )
                : reportsProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : reports.isEmpty
                        ? ReportEmptyState(
                            message:
                                'No mileage records found for ${_selectedVehicle!.number} in $_selectedMonth/$_selectedYear.',
                            onRetry: _fetchData,
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DataTable(
                                  headingRowColor:
                                      WidgetStatePropertyAll(Colors.grey.shade50),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Route',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Total Kms',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Readings',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Speedometer Diff',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: reports.map((r) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            r.routeNo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text('${r.actualTotalKmsDriven} km'),
                                        ),
                                        DataCell(
                                          Text('${r.totalNoOfKmReadingsTaken}'),
                                        ),
                                        DataCell(
                                          Text('${r.speedometerDiff} km'),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
