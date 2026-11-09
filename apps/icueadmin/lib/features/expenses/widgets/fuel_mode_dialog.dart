import 'package:core_ui/core_ui.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';

enum FuelModeAction { fuelStation, selfFilling }

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
            iconAsset: 'assets/dashboard/expense-fuel.png',
            title: 'Commercial Fuel Station',
            subtitle: 'External petrol pump / retail filling',
            onTap: () {
              Navigator.of(context).pop();
              onSelect(FuelModeAction.fuelStation);
            },
          ),
          const SizedBox(height: 10),
          _ModeTile(
            iconAsset: 'assets/dashboard/fuel-start-filling.png',
            title: 'Start Campus Self-Filling',
            subtitle: 'Begin dispensing from internal campus fuel pump',
            onTap: () {
              Navigator.of(context).pop();
              onSelect(FuelModeAction.selfFilling);
            },
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: AppButtonVariant.ghost,
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
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
            Image.asset(iconAsset, width: 42, height: 42, fit: BoxFit.contain),
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
