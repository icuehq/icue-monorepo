import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logbook/logbook.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

class CleaningLogPage extends StatefulWidget {
  const CleaningLogPage({super.key});

  @override
  State<CleaningLogPage> createState() => _CleaningLogPageState();
}

class _CleaningLogPageState extends State<CleaningLogPage> {
  int _currentStep = 0;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  final Set<int> _selectedVehicleIds = <int>{};
  final Set<int> _selectedPartIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicles();
      context.read<LogBookProvider>().fetchCleaningParts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitCleaning(List<Vehicle> allVehicles) async {
    if (_selectedVehicleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one vehicle')),
      );
      return;
    }
    if (_selectedPartIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one cleaned area')),
      );
      return;
    }

    final vehicleEntries = allVehicles
        .where((v) => _selectedVehicleIds.contains(v.id))
        .map((v) => CleanedVehicleEntry(id: v.id, vehicleNo: v.number))
        .toList();

    final req = SubmitCleaningDataRequest(
      cleanedPartIds: _selectedPartIds.toList(),
      vehicles: vehicleEntries,
    );

    final res = await context.read<LogBookProvider>().submitCleaningData(req);

    if (!mounted) return;

    if (res.success && res.failedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleaning inspection recorded successfully!'),
        ),
      );
      context.pop();
    } else if (res.failedCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cleaning Record Warning'),
          content: Text(
            '${res.failedCount} vehicle(s) were already logged or could not be updated:\n${res.failedMessages.join("\n")}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LogBookProvider>().errorMessage ??
                'Failed to record cleaning inspection.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final logBookProvider = context.watch<LogBookProvider>();
    final allVehicles = vehicleProvider.vehicles;
    final parts = logBookProvider.cleaningParts;

    final filteredVehicles = allVehicles.where((v) {
      if (_query.isEmpty) return true;
      return v.number.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Cleaning Log'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep = 0),
                    child: const Text('Back to Vehicles'),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _currentStep == 0
                      ? () {
                          if (_selectedVehicleIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Select at least one vehicle'),
                              ),
                            );
                            return;
                          }
                          setState(() => _currentStep = 1);
                        }
                      : () => _submitCleaning(allVehicles),
                  child: Text(
                    _currentStep == 0
                        ? 'Next: Cleaning Checklist (${_selectedVehicleIds.length})'
                        : 'Submit Inspection',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _currentStep == 0
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search vehicles by number...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_query.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedVehicleIds.length ==
                                    allVehicles.length) {
                                  _selectedVehicleIds.clear();
                                } else {
                                  _selectedVehicleIds.addAll(
                                    allVehicles.map((v) => v.id),
                                  );
                                }
                              });
                            },
                            child: Text(
                              _selectedVehicleIds.length == allVehicles.length
                                  ? 'Deselect All'
                                  : 'Select All',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (val) => setState(() => _query = val),
                  ),
                ),
                Expanded(
                  child: filteredVehicles.isEmpty
                      ? const Center(
                          child: Text('No vehicles found.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredVehicles.length,
                          itemBuilder: (context, index) {
                            final vehicle = filteredVehicles[index];
                            final isChecked =
                                _selectedVehicleIds.contains(vehicle.id);

                            return CheckboxListTile(
                              dense: true,
                              value: isChecked,
                              title: Text(
                                vehicle.number,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                vehicle.fuelType != null
                                    ? 'Fuel: ${vehicle.fuelType}'
                                    : 'Fleet vehicle',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedVehicleIds.add(vehicle.id);
                                  } else {
                                    _selectedVehicleIds.remove(vehicle.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    'Selected ${_selectedVehicleIds.length} vehicle(s) for cleaning inspection.\nCheck all cleaned areas below:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (parts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  ...parts.map((p) {
                    final isChecked = _selectedPartIds.contains(p.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        value: isChecked,
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedPartIds.add(p.id);
                            } else {
                              _selectedPartIds.remove(p.id);
                            }
                          });
                        },
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
