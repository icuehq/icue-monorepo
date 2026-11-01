import 'package:flutter/material.dart';
import 'package:vehicles/vehicles.dart';

class ExpenseVehicleCard extends StatelessWidget {
  const ExpenseVehicleCard({
    super.key,
    required this.vehicle,
    required this.onTap,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Image.asset(
          'assets/dashboard/vehicles.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
        ),
        title: Text(
          vehicle.number,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          vehicle.fuelType?.toString().isNotEmpty == true
              ? 'Fuel: ${vehicle.fuelType}'
              : 'ID: ${vehicle.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}
