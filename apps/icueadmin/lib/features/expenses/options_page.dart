import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/expenses/generic_expense_form_page.dart';
import 'package:icueadmin/features/expenses/widgets/fuel_mode_dialog.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  static const Map<String, IconData> _iconMap = {
    'fuel': Icons.local_gas_station_rounded,
    'tyres': Icons.tire_repair_rounded,
    'maintenance': Icons.build_circle_outlined,
    'salary': Icons.account_balance_wallet_outlined,
    'battery': Icons.battery_charging_full_rounded,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchExpenseTypes();
    });
  }

  void _onExpenseTypeSelected(ExpenseType type) {
    if (type.code == 'fuel') {
      showDialog<void>(
        context: context,
        builder: (ctx) => FuelModeDialog(
          expenseType: type,
          onSelect: (mode) {
            switch (mode) {
              case FuelModeAction.fuelStation:
                context.push(
                  AppRoutes.addExpense,
                  extra: GenericExpenseArgs(
                    expenseType: type,
                    vehicleNumber: widget.vehicle.number,
                    fuelType: widget.vehicle.fuelType?.toString(),
                    mode: 'FuelStation',
                  ),
                );
                break;
              case FuelModeAction.selfFilling:
                context.push(
                  AppRoutes.selfFilling,
                  extra: widget.vehicle.fuelType?.toString() ?? 'Diesel',
                );
                break;
              case FuelModeAction.endFilling:
                context.push(
                  AppRoutes.endFilling,
                  extra: widget.vehicle.fuelType?.toString() ?? 'Diesel',
                );
                break;
            }
          },
        ),
      );
    } else {
      context.push(
        AppRoutes.addExpense,
        extra: GenericExpenseArgs(
          expenseType: type,
          vehicleNumber: widget.vehicle.number,
          fuelType: widget.vehicle.fuelType?.toString(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseProvider = context.watch<ExpenseProvider>();
    final expenseTypes = expenseProvider.expenseTypes
        .where((e) => !['loosefuel', 'statutory'].contains(e.code))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle.number),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: theme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.vehicle.number,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fuel Type: ${widget.vehicle.fuelType ?? "Not specified"}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.receipt_long_rounded, color: Colors.blue),
              title: const Text(
                'Record Expense',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Add maintenance, fuel, parts, or salaries'),
              children: [
                if (expenseProvider.isLoading && expenseTypes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ...expenseTypes.map((type) {
                    final icon = _iconMap[type.code] ?? Icons.payment_rounded;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(icon, color: Colors.blue.shade700, size: 18),
                      ),
                      title: Text(
                        type.expenseTypeDesc,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                      onTap: () => _onExpenseTypeSelected(type),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
