import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/expenses/widgets/fuel_mode_dialog.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:icueadmin/widgets/option_card_tile.dart';
import 'package:provider/provider.dart';

class ManageExpensePage extends StatefulWidget {
  const ManageExpensePage({super.key});

  @override
  State<ManageExpensePage> createState() => _ManageExpensePageState();
}

class _ManageExpensePageState extends State<ManageExpensePage> {
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
                  final assetPath = _assetMap[item.code];

                  return OptionCardTile(
                    title: item.expenseTypeDesc,
                    subtitle:
                        'Record & manage ${item.expenseTypeDesc.toLowerCase()}',
                    iconAsset: assetPath,
                    onTap: () => _onCategoryTapped(item),
                  );
                },
              ),
            ),
    );
  }
}
