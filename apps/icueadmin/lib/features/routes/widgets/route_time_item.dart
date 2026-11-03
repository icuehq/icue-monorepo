import 'package:flutter/material.dart';
import 'package:routes/routes.dart';

class RouteTimeItem extends StatelessWidget {
  const RouteTimeItem({
    super.key,
    required this.route,
    required this.isSelected,
    required this.onChanged,
  });

  final Routee route;
  final bool isSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade200,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (val) => onChanged(val ?? false),
        title: Text(
          'Route ${route.routeNo}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'Current Start Time: ${route.routeStartTime != null && route.routeStartTime!.isNotEmpty ? route.routeStartTime : 'Not set'}  •  Vehicle: ${route.vehicleNumber ?? 'Unassigned'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        secondary: CircleAvatar(
          radius: 18,
          backgroundColor: route.mode == RouteMode.pickup
              ? Colors.green.shade50
              : Colors.blue.shade50,
          child: Icon(
            route.mode == RouteMode.pickup
                ? Icons.north_east_rounded
                : Icons.south_west_rounded,
            size: 18,
            color: route.mode == RouteMode.pickup
                ? Colors.green.shade700
                : Colors.blue.shade700,
          ),
        ),
      ),
    );
  }
}
