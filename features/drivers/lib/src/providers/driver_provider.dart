import 'package:api_client/api_client.dart';
import 'package:drivers/src/models/add_driver_request.dart';
import 'package:drivers/src/models/driver.dart';
import 'package:drivers/src/models/driver_document.dart';
import 'package:drivers/src/models/place.dart';
import 'package:drivers/src/services/driver_service.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class DriverProvider extends ChangeNotifier {
  DriverProvider(this._driverService);

  final DriverService _driverService;

  List<Driver> _drivers = <Driver>[];
  List<Place> _countries = <Place>[];
  List<Place> _places = <Place>[];
  final Map<String, DriverDocs?> _driverDocs = <String, DriverDocs?>{};
  bool _isLoading = false;
  String? _errorMessage;

  List<Driver> get drivers => List.unmodifiable(_drivers);
  Map<String, DriverDocs?> get driverDocs => Map.unmodifiable(_driverDocs);
  List<Place> get countries => List.unmodifiable(_countries);
  List<Place> get places => List.unmodifiable(_places);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Loads the country list for the address form.
  Future<void> fetchCountries() async {
    try {
      _countries = await _driverService.getCountries();
    } catch (_) {
      // The form keeps working with an empty list.
    }
    notifyListeners();
  }

  /// Loads the states of the country with id [countryId].
  Future<void> fetchPlaces(String countryId) async {
    try {
      _places = await _driverService.getChildPlaces(countryId);
    } catch (_) {
      _places = <Place>[];
    }
    notifyListeners();
  }

  /// Fetches all drivers from the server.
  Future<void> fetchDrivers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _drivers = await _driverService.getDrivers();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new driver and refreshes the driver list.
  Future<bool> addDriver(AddDriverRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _driverService.createDriver(request);
      _drivers = await _driverService.getDrivers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates driver details and refreshes the list.
  Future<bool> updateDriver(AddDriverRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _driverService.updateDriver(request);
      _drivers = await _driverService.getDrivers();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a driver by ID.
  Future<bool> deleteDriver(int driverId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _driverService.deleteDriver(driverId);
      _drivers.removeWhere((d) => d.id == driverId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches documents for a driver by document type.
  Future<void> fetchDriverDoc(int driverId, String docType) async {
    try {
      final doc = await _driverService.getDriverDocs(driverId, docType);
      _driverDocs[docType] = doc;
      notifyListeners();
    } catch (_) {
      // Ignored per document fallback rules
    }
  }

  /// Uploads driver documents via FormData.
  Future<bool> uploadDriverDoc({
    required int driverId,
    required String docType,
    required FormData formData,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _driverService.uploadDriverDocs(formData);
      await fetchDriverDoc(driverId, docType);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a driver's document.
  Future<bool> deleteDriverDoc(int driverId, String docType) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = _driverDocs[docType];
      // Front/back photos and single-file docs each carry their own id.
      for (final id in {
        doc?.documentId,
        doc?.frontPhotoDocumentId,
        doc?.backPhotoDocumentId,
      }) {
        if (id != null && id.isNotEmpty) {
          await _driverService.deleteDriverDoc(driverId, docType, id);
        }
      }
      _driverDocs.remove(docType);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears stored document state when changing driver screens.
  void clearDocs() {
    _driverDocs.clear();
    notifyListeners();
  }
}
