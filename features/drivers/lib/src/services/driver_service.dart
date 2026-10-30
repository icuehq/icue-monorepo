import 'package:api_client/api_client.dart';
import 'package:drivers/src/models/add_driver_request.dart';
import 'package:drivers/src/models/driver.dart';
import 'package:drivers/src/models/driver_document.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class DriverService {
  DriverService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches all drivers for the authenticated organization & branch.
  Future<List<Driver>> getDrivers() async {
    final response = await _apiClient.post<dynamic>('/v1.0/getDrivers');
    return parseList(
      response.data,
      Driver.fromJson,
      compare: (a, b) => a.firstName.compareTo(b.firstName),
    );
  }

  /// Creates a new driver record.
  Future<void> createDriver(AddDriverRequest request) async {
    await _apiClient.post<dynamic>(
      '/v1.0/createDriver',
      data: request.toJson(),
    );
  }

  /// Updates an existing driver record.
  Future<void> updateDriver(AddDriverRequest request) async {
    await _apiClient.post<dynamic>(
      '/v1.0/updateDriver',
      data: request.toJson(),
    );
  }

  /// Deletes a driver by their ID.
  Future<void> deleteDriver(int driverId) async {
    await _apiClient.post<dynamic>(
      '/v1.0/deleteDriver',
      data: {'id': driverId},
    );
  }

  /// Retrieves a specific document (e.g. 'License', 'Id', 'Profile') for [driverId].
  Future<DriverDocs?> getDriverDocs(int driverId, String docType) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/v1.0/getDriverDocs',
        data: {'id': driverId, 'type': docType},
      );
      if (response.data is Map<String, dynamic>) {
        final docResponse = DriverDocumentResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
        return docResponse.docs;
      }
      return null;
    } catch (_) {
      // Per old app error rules, document lookups that fail or return 404 return null
      return null;
    }
  }

  /// Uploads or updates document files for a driver.
  Future<void> uploadDriverDocs(FormData formData) async {
    await _apiClient.post<dynamic>('/v1.0/uploadDriverDocs', data: formData);
  }

  /// Deletes a specific document for [driverId].
  Future<void> deleteDriverDoc(int driverId, String docType) async {
    await _apiClient.post<dynamic>(
      '/v1.0/deleteDriverDoc',
      data: {'id': driverId, 'type': docType},
    );
  }
}
