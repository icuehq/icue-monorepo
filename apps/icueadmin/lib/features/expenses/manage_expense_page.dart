import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/expenses/widgets/fuel_mode_dialog.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';

class ManageExpensePage extends StatefulWidget {
  const ManageExpensePage({super.key});

  @override
  State<ManageExpensePage> createState() => _ManageExpensePageState();
}

class _ManageExpensePageState extends State<ManageExpensePage> {
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

  void _onCategoryTapped(ExpenseType item) {
    if (item.code == 'fuel') {
      showDialog<void>(
        context: context,
        builder: (ctx) => FuelModeDialog(
          expenseType: item,
          onSelect: (mode) {
            switch (mode) {
              case FuelModeAction.fuelStation:
                context.push(AppRoutes.repairsExpense);
                break;
              case FuelModeAction.selfFilling:
                context.push(AppRoutes.selfFilling);
                break;
              case FuelModeAction.endFilling:
                context.push(AppRoutes.endFilling);
                break;
            }
          },
        ),
      );
    } else {
      context.push(AppRoutes.repairsExpense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final types = provider.expenseTypes
        .where((e) => !['loosefuel', 'statutory'].contains(e.code))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Expenses')),
      body: provider.isLoading && types.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<ExpenseProvider>().fetchExpenseTypes(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: types.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = types[index];
                  final icon = _iconMap[item.code] ?? Icons.payment_rounded;

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(
                          icon,
                          color: Colors.blue.shade700,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item.expenseTypeDesc,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Record & manage ${item.expenseTypeDesc.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () => _onCategoryTapped(item),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
