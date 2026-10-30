import 'package:api_client/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:vehicles/src/models/add_vehicle_request.dart';
import 'package:vehicles/src/models/vehicle.dart';
import 'package:vehicles/src/models/vehicle_data.dart';
import 'package:vehicles/src/models/vehicle_docs.dart';
import 'package:vehicles/src/services/vehicle_service.dart';

@lazySingleton
class VehicleProvider extends ChangeNotifier {
  VehicleProvider(this._vehicleService);

  final VehicleService _vehicleService;

  List<Vehicle> _vehicles = <Vehicle>[];
  List<VehicleData> _vehiclesData = <VehicleData>[];
  VehicleDetails? _vehicleDetails;
  final Map<String, Docs?> _vehicleDocs = <String, Docs?>{};
  bool _isLoading = false;
  String? _errorMessage;

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<VehicleData> get vehiclesData => List.unmodifiable(_vehiclesData);
  VehicleDetails? get vehicleDetails => _vehicleDetails;
  Map<String, Docs?> get vehicleDocs => Map.unmodifiable(_vehicleDocs);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetches basic vehicle numbers for dropdowns.
  Future<void> fetchVehicles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehicles = await _vehicleService.getVehicles();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches complete vehicle fleet data with compliance records.
  Future<void> fetchVehiclesData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehiclesData = await _vehicleService.getVehiclesData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches vehicle details by number.
  Future<void> fetchVehicleDetails(String vehicleNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehicleDetails = await _vehicleService.getVehicleDetails(vehicleNumber);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new vehicle and refreshes the fleet list.
  Future<bool> addVehicle(AddVehicleRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _vehicleService.createVehicle(request);
      _vehiclesData = await _vehicleService.getVehiclesData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing vehicle and refreshes the fleet list.
  Future<bool> updateVehicle(AddVehicleRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _vehicleService.updateVehicle(request);
      _vehiclesData = await _vehicleService.getVehiclesData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a vehicle by ID.
  Future<bool> deleteVehicle(int vehicleId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _vehicleService.deleteVehicle(vehicleId);
      _vehiclesData.removeWhere((v) => v.id == vehicleId);
      _vehicles.removeWhere((v) => v.id == vehicleId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches a vehicle document by type.
  Future<void> fetchVehicleDoc({required int id, required String type}) async {
    try {
      final doc = await _vehicleService.getVehicleDocs(id: id, type: type);
      _vehicleDocs[type] = doc;
      notifyListeners();
    } catch (_) {
      // Ignored fallback
    }
  }

  /// Uploads a vehicle document.
  Future<bool> uploadVehicleDoc({
    required int vehicleId,
    required String type,
    required FormData formData,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _vehicleService.uploadVehicleDocs(formData);
      await fetchVehicleDoc(id: vehicleId, type: type);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a vehicle document.
  Future<bool> deleteVehicleDoc({
    required int vehicleId,
    required String type,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _vehicleService.deleteVehicleDoc(id: vehicleId, type: type);
      _vehicleDocs.remove(type);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Checks if a vehicle number is already registered.
  Future<bool> checkVehicleNumber(String number) {
    return _vehicleService.checkVehicleNumber(number);
  }

  /// Clears stored document state when changing vehicles.
  void clearDocs() {
    _vehicleDocs.clear();
    _vehicleDetails = null;
    notifyListeners();
  }
}
