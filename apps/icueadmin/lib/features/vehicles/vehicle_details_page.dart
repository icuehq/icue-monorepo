import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

class VehicleDetailsPage extends StatelessWidget {
  const VehicleDetailsPage({super.key, required this.vehicle});

  final VehicleData vehicle;

  void _confirmDelete(BuildContext context) {
    if (vehicle.id == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text(
          'Are you sure you want to remove vehicle ${vehicle.number} from the fleet?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = context.read<VehicleProvider>();
              final success = await provider.deleteVehicle(vehicle.id!);
              if (context.mounted) {
                if (success) {
                  track(AppEvents.vehicleDeleted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vehicle removed from fleet successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.errorMessage ?? 'Failed to delete vehicle',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String? value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(':', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value != null && value.trim().isNotEmpty ? value : '-',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color ?? const Color(0xFF1F1D31),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = {
      'Insurance': vehicle.insuranceExpiryDate,
      'RC': vehicle.rcExpiryDate,
      'Fitness': vehicle.fitnessExpiryDate,
      'Road Tax': vehicle.roadTaxExpiryDate,
      'Pollution': vehicle.pollutionExpiryDate,
      'Permit': vehicle.permitExpiryDate,
    };

    final alerts = <String>[];
    for (final entry in docs.entries) {
      final date = AppDateUtils.tryParseDate(entry.value);
      final status = AppDateUtils.checkExpiryStatus(entry.key, date);
      if (status != null) {
        alerts.add(status);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicle.number),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Vehicle',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context).primaryColor
                          .withValues(alpha: 0.15),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.number,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle.make ?? ''} ${vehicle.model ?? ''} • ${vehicle.year ?? ''}'
                                .trim(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (vehicle.capacity != null)
                      Chip(
                        label: Text('Capacity: ${vehicle.capacity}'),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Compliance Alerts',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...alerts.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $a',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fleet Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow('Make', vehicle.make),
                    _buildInfoRow('Model', vehicle.model),
                    _buildInfoRow('Year', vehicle.year),
                    _buildInfoRow('Fuel Type', vehicle.fuelType),
                    _buildInfoRow('Colour', vehicle.colour),
                    _buildInfoRow('Air Condition', vehicle.airCondition),
                    _buildInfoRow('Chassis No.', vehicle.chasisNumber),
                    _buildInfoRow('Engine No.', vehicle.engineNumber),
                    _buildInfoRow('Date of Reg', vehicle.dateOfReg),
                    _buildInfoRow('RTA Office', vehicle.rtaOfcName),
                    _buildInfoRow(
                      'Claimed Mileage',
                      vehicle.companyClaimedMileage != null
                          ? '${vehicle.companyClaimedMileage} km/l'
                          : null,
                    ),
                    _buildInfoRow(
                      'Expected Mileage',
                      vehicle.actualExpectedMileage != null
                          ? '${vehicle.actualExpectedMileage} km/l'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assigned Driver',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRow('Driver Name', vehicle.driverName),
                    _buildInfoRow(
                      'Driver Phone',
                      '${vehicle.driverNumber ?? '-'}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      context.push(AppRoutes.addVehicle, extra: vehicle);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit Vehicle'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      context.push(AppRoutes.vehicleDocs, extra: vehicle);
                    },
                    icon: const Icon(Icons.folder_shared_outlined, size: 18),
                    label: const Text('Documents'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
