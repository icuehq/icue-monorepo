import 'package:expenses/src/models/expense_requests.dart';
import 'package:expenses/src/models/expense_type.dart';
import 'package:expenses/src/models/fuel_storage.dart';
import 'package:expenses/src/services/expense_service.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider(this._expenseService);

  final ExpenseService _expenseService;

  List<ExpenseType> _expenseTypes = <ExpenseType>[];
  List<Detail> _categories = <Detail>[];
  List<Detail> _subCategories = <Detail>[];
  List<Storage> _fuelStorages = <Storage>[];
  String? _startGaugeReading;
  final List<String> _filledVehicleNumbers = <String>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<ExpenseType> get expenseTypes => List.unmodifiable(_expenseTypes);
  List<Detail> get categories => List.unmodifiable(_categories);
  List<Detail> get subCategories => List.unmodifiable(_subCategories);
  List<Storage> get fuelStorages => List.unmodifiable(_fuelStorages);
  String? get startGaugeReading => _startGaugeReading;
  List<String> get filledVehicleNumbers =>
      List.unmodifiable(_filledVehicleNumbers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setStartGaugeReading(String? reading) {
    _startGaugeReading = reading;
    notifyListeners();
  }

  void reset() {
    _filledVehicleNumbers.clear();
    _startGaugeReading = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetches all dynamic expense types.
  Future<void> fetchExpenseTypes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _expenseTypes = await _expenseService.getExpenseTypes();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches high-level expense categories.
  Future<void> fetchExpenseCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _expenseService.getExpenseCategories();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches sub-categories for a given category ID.
  Future<void> fetchExpenseSubCategories(int categoryId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _subCategories = await _expenseService.getExpenseSubCategories(
        categoryId,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches fuel storages by fuel type.
  Future<void> fetchFuelStorages(String? fuelType) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _fuelStorages = await _expenseService.getFuelStorages(fuelType);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates pump status for self filling.
  Future<bool> updateSelfFillingStatus(SelfFillingStatusRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (request.startReading != null) {
        _startGaugeReading = request.startReading;
      }
      final success = await _expenseService.updateSelfFillingStatus(request);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits an expense record.
  Future<bool> submitExpense(StoreExpenseRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _expenseService.storeExpense(request);
      if (success) {
        final vehicleIdentifier =
            request.extraFields['StorName'] ?? request.vehicleNumber;
        if (!_filledVehicleNumbers.contains(vehicleIdentifier.toString())) {
          _filledVehicleNumbers.add(vehicleIdentifier.toString());
        }
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
