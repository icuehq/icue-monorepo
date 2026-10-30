import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:vehicles/vehicles.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, required this.onTap});

  final VehicleData vehicle;
  final VoidCallback onTap;

  List<String> _getExpiredAlerts() {
    final alerts = <String>[];
    final docs = {
      'Insurance': vehicle.insuranceExpiryDate,
      'RC': vehicle.rcExpiryDate,
      'Fitness': vehicle.fitnessExpiryDate,
      'Road Tax': vehicle.roadTaxExpiryDate,
      'Pollution': vehicle.pollutionExpiryDate,
      'Permit': vehicle.permitExpiryDate,
    };

    for (final entry in docs.entries) {
      final date = AppDateUtils.tryParseDate(entry.value);
      final status = AppDateUtils.checkExpiryStatus(entry.key, date);
      if (status != null) {
        alerts.add(status);
      }
    }
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _getExpiredAlerts();
    final hasAlerts = alerts.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasAlerts ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).primaryColor
                        .withValues(alpha: 0.1),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.number,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (vehicle.make != null || vehicle.model != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${vehicle.make ?? ''} ${vehicle.model ?? ''}'
                                .trim(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (vehicle.capacity != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Cap: ${vehicle.capacity}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
              if (vehicle.driverName != null &&
                  vehicle.driverName!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Driver: ${vehicle.driverName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (vehicle.driverNumber != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${vehicle.driverNumber})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (hasAlerts) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alerts.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (alerts.length > 1)
                        Text(
                          '+${alerts.length - 1} more',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
