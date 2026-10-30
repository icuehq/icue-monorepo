import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';

enum FuelModeAction { fuelStation, selfFilling, endFilling }

class FuelModeDialog extends StatelessWidget {
  const FuelModeDialog({
    super.key,
    required this.expenseType,
    required this.onSelect,
  });

  final ExpenseType expenseType;
  final ValueChanged<FuelModeAction> onSelect;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Select Fuel Filling Mode',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTile(
            icon: Icons.local_gas_station_rounded,
            title: 'Commercial Fuel Station',
            subtitle: 'External petrol pump / retail filling',
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).pop();
              onSelect(FuelModeAction.fuelStation);
            },
          ),
          const SizedBox(height: 10),
          _ModeTile(
            icon: Icons.play_circle_fill_rounded,
            title: 'Start Campus Self-Filling',
            subtitle: 'Begin dispensing from internal campus fuel pump',
            color: Colors.green,
            onTap: () {
              Navigator.of(context).pop();
              onSelect(FuelModeAction.selfFilling);
            },
          ),
          const SizedBox(height: 10),
          _ModeTile(
            icon: Icons.stop_circle_rounded,
            title: 'End Campus Self-Filling',
            subtitle: 'Record final gauge reading and finish session',
            color: Colors.deepOrange,
            onTap: () {
              Navigator.of(context).pop();
              onSelect(FuelModeAction.endFilling);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
