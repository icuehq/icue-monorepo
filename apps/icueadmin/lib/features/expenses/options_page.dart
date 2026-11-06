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
  static const Map<String, String> _assetMap = {
    'fuel': 'assets/dashboard/expense-fuel.png',
    'tyres': 'assets/dashboard/expense-tyres.png',
    'maintenance': 'assets/dashboard/expense-maintenance.png',
    'salary': 'assets/dashboard/expense-salary.png',
    'battery': 'assets/dashboard/expense-battery.png',
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
                    fuelPrice: widget.vehicle.price,
                  ),
                );
                break;
              case FuelModeAction.selfFilling:
                context.push(
                  AppRoutes.selfFilling,
                  extra: widget.vehicle.fuelType?.toString(),
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
      appBar: AppBar(title: Text(widget.vehicle.number)),
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
                  Image.asset(
                    'assets/dashboard/vehicles.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.contain,
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
              leading: Image.asset(
                'assets/dashboard/manage-expense.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
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
                    final asset =
                        _assetMap[type.code] ??
                        'assets/dashboard/manage-expense.png';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Image.asset(
                        asset,
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                      title: Text(
                        type.expenseTypeDesc,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
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
