import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';
import 'package:vehicles/src/models/add_vehicle_request.dart';
import 'package:vehicles/src/models/vehicle.dart';
import 'package:vehicles/src/models/vehicle_data.dart';
import 'package:vehicles/src/models/vehicle_docs.dart';

@lazySingleton
class VehicleService {
  VehicleService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches basic vehicle numbers list for dropdowns and selectors.
  Future<List<Vehicle>> getVehicles() async {
    final response =
        await _apiClient.post<dynamic>('/v1.0/getVehiclesNumbersByBranch');
    return parseList(
      response.data,
      Vehicle.fromJson,
      compare: (a, b) => a.number.compareTo(b.number),
    );
  }

  /// Fetches full vehicle fleet data with compliance dates and driver associations.
  Future<List<VehicleData>> getVehiclesData() async {
    final response = await _apiClient.post<dynamic>('/v1.0/getVehicles');
    return parseList(
      response.data,
      VehicleData.fromJson,
      compare: (a, b) => a.number.compareTo(b.number),
    );
  }

  /// Fetches complete vehicle details by vehicle number.
  Future<VehicleDetails?> getVehicleDetails(String vehicleNumber) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVehicleByNumber',
      data: {'Number': vehicleNumber},
    );
    if (response.data is Map<String, dynamic>) {
      return VehicleDetails.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  /// Creates a new vehicle in the fleet.
  Future<void> createVehicle(AddVehicleRequest request) async {
    await _apiClient.post<dynamic>('/v1.0/createVehicle', data: request.toJson());
  }

  /// Updates an existing vehicle.
  Future<void> updateVehicle(AddVehicleRequest request) async {
    await _apiClient.post<dynamic>('/v1.0/updateVehicle', data: request.toJson());
  }

  /// Deletes a vehicle by its ID.
  Future<void> deleteVehicle(int vehicleId) async {
    await _apiClient.post<dynamic>(
      '/v1.0/deleteVehicles',
      data: {
        'Ids': [vehicleId],
      },
    );
  }

  /// Retrieves document data for a vehicle and doc type (e.g. 'Insurance', 'RC', 'Fitness', etc.).
  Future<Docs?> getVehicleDocs({
    required int id,
    required String type,
  }) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/v1.0/getVehicleDocs',
        data: {'Target': 'Vehicle', 'RecordId': id, 'Type': type},
      );
      if (response.data is Map<String, dynamic>) {
        final docsResponse = VehicleDocs.fromJson(
          response.data as Map<String, dynamic>,
        );
        return docsResponse.docs;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Uploads or updates document files for a vehicle.
  Future<void> uploadVehicleDocs(FormData formData) async {
    await _apiClient.post<dynamic>('/v1.0/uploadVehicleDocs', data: formData);
  }

  /// Deletes a specific vehicle document.
  Future<void> deleteVehicleDoc({
    required int id,
    required String type,
  }) async {
    await _apiClient.post<dynamic>(
      '/v1.0/deleteVehicleDocs',
      data: {'Target': 'Vehicle', 'RecordId': id, 'Type': type},
    );
  }

  /// Checks if a vehicle number is already registered in the system.
  Future<bool> checkVehicleNumber(String number) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/v1.0/checkVehicleNumber',
        data: {'Number': number},
      );
      if (response.data is Map<String, dynamic>) {
        return (response.data as Map<String, dynamic>)['IsAlreadyRegistered']
                as bool? ??
            false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
