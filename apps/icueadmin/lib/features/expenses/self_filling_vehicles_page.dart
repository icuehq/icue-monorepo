import 'package:core_ui/core_ui.dart';
import 'package:expenses/expenses.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/features/expenses/generic_expense_form_page.dart';
import 'package:icueadmin/features/expenses/loose_fuel_expense_page.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:vehicles/vehicles.dart';

/// Vehicles and fuel storages that can still be filled in a self-filling
/// session. Filled ones are disabled; End Filling closes the session.
class SelfFillingVehiclesPage extends StatefulWidget {
  const SelfFillingVehiclesPage({super.key, required this.fuelType});

  final String fuelType;

  @override
  State<SelfFillingVehiclesPage> createState() =>
      _SelfFillingVehiclesPageState();
}

class _SelfFillingVehiclesPageState extends State<SelfFillingVehiclesPage> {
  String _query = '';

  bool _sameFuel(Object? fuelType) =>
      fuelType?.toString().toUpperCase() == widget.fuelType.toUpperCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final expenses = context.read<ExpenseProvider>();
      if (expenses.expenseTypes.isEmpty) expenses.fetchExpenseTypes();
      expenses.fetchFuelStorages(widget.fuelType);
      context.read<VehicleProvider>().fetchVehicles();
    });
  }

  void _confirmEndFilling() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Filling'),
        content: const Text('Are you sure you want to end the fuel filling?'),
        actions: [
          AppButton(
            label: 'No',
            onPressed: () => Navigator.of(ctx).pop(),
            variant: AppButtonVariant.ghost,
          ),
          AppButton(
            label: 'Yes',
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pushReplacement(
                AppRoutes.endFilling,
                extra: widget.fuelType,
              );
            },
            variant: AppButtonVariant.ghost,
          ),
        ],
      ),
    );
  }

  ExpenseType? _type(ExpenseProvider provider, String code) {
    for (final type in provider.expenseTypes) {
      if (type.code == code) return type;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>();
    final vehicles = context.watch<VehicleProvider>();
    final filled = expenses.filledVehicleNumbers;
    final query = _query.toLowerCase();

    final storages = [
      for (final storage in expenses.fuelStorages)
        for (final item in storage.items)
          if (_sameFuel(item.fuelType) &&
              item.name.toLowerCase().contains(query))
            StorageItem(
              name: item.name,
              capacity: item.capacity,
              fuelType: item.fuelType,
              fuelPrice: item.fuelPrice,
              type: storage.type,
            ),
    ];
    final fleet = vehicles.vehicles
        .where(
          (v) =>
              _sameFuel(v.fuelType) && v.number.toLowerCase().contains(query),
        )
        .toList();

    final fuelType = _type(expenses, 'fuel');
    final looseType = _type(expenses, 'loosefuel');

    return PopScope(
      canPop: filled.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEndFilling();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vehicles'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search Vehicle...',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
          ),
        ),
        bottomNavigationBar: filled.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppButton(
                    label: 'End Filling',
                    onPressed: _confirmEndFilling,
                  ),
                ),
              ),
        body:
            (expenses.isLoading || vehicles.isLoading) &&
                fleet.isEmpty &&
                storages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final item in storages)
                    _tile(
                      title: item.name,
                      subtitle: '${item.type} - ${item.fuelType}',
                      isFilled: filled.contains(item.name),
                      onTap: looseType == null
                          ? null
                          : () => context.push(
                              AppRoutes.looseFuel,
                              extra: LooseFuelArgs(
                                expenseType: looseType,
                                storage: item,
                              ),
                            ),
                    ),
                  for (final vehicle in fleet)
                    _tile(
                      title: vehicle.number,
                      subtitle: vehicle.fuelType?.toString() ?? '',
                      isFilled: filled.contains(vehicle.number),
                      onTap: fuelType == null
                          ? null
                          : () => context.push(
                              AppRoutes.addExpense,
                              extra: GenericExpenseArgs(
                                expenseType: fuelType,
                                vehicleNumber: vehicle.number,
                                fuelType: vehicle.fuelType?.toString(),
                                fuelPrice: vehicle.price,
                                mode: 'SelfFilling',
                              ),
                            ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required bool isFilled,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.grey),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(isFilled ? 'Already Filled' : subtitle),
        enabled: !isFilled && onTap != null,
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: onTap,
      ),
    );
  }
}
