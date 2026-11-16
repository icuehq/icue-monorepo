import 'package:expenses/expenses.dart';

class GenericExpenseArgs {
  const GenericExpenseArgs({
    required this.expenseType,
    required this.vehicleNumber,
    this.fuelType,
    this.fuelPrice,
    this.mode,
  });

  final ExpenseType expenseType;
  final String vehicleNumber;
  final String? fuelType;
  final String? fuelPrice;
  final String? mode;
}

class LooseFuelArgs {
  const LooseFuelArgs({required this.expenseType, required this.storage});

  /// The `loosefuel` expense type.
  final ExpenseType expenseType;
  final StorageItem storage;
}
