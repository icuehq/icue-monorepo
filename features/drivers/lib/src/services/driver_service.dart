import 'package:api_client/api_client.dart';
import 'package:drivers/src/models/add_driver_request.dart';
import 'package:drivers/src/models/driver.dart';
import 'package:drivers/src/models/driver_document.dart';
import 'package:drivers/src/models/place.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class DriverService {
  DriverService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches all drivers for the authenticated organization & branch.
  Future<List<Driver>> getDrivers() async {
    final response = await _apiClient.post<dynamic>('/v1.0/getDrivers');
    return _apiClient.parse(
      response,
      (payload) => parseList(
        payload,
        Driver.fromJson,
        compare: (a, b) => a.firstName.compareTo(b.firstName),
      ),
    );
  }

  /// Fetches the selectable countries.
  Future<List<Place>> getCountries() async {
    final response = await _apiClient.get<dynamic>('/v1.0/getCountries');
    return _apiClient.parse(
      response,
      (payload) => parseList(payload, Place.fromJson),
    );
  }

  /// Fetches the states (child places) of [parentId].
  Future<List<Place>> getChildPlaces(String parentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getChildPlaces',
      data: {'ParentId': parentId},
    );
    return _apiClient.parse(
      response,
      (payload) => parseList(payload, Place.fromJson),
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
      '/v1.0/deleteDrivers',
      data: {
        'Ids': [driverId],
      },
    );
  }

  /// Retrieves a specific document (e.g. 'License', 'Id', 'Profile') for [driverId].
  Future<DriverDocs?> getDriverDocs(int driverId, String docType) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '/v1.0/getDriverDocs',
        data: {'Target': 'Driver', 'RecordId': driverId, 'Type': docType},
      );
      return await _apiClient.parse(response, (payload) {
        if (payload is Map<String, dynamic>) {
          final docResponse = DriverDocumentResponse.fromJson(payload);
          return docResponse.docs;
        }
        return null;
      });
    } catch (error, stack) {
      reportError(error, stack, 'DriverService.getDriverDocs');
      // Per old app error rules, document lookups that fail or return 404 return null
      return null;
    }
  }

  /// Uploads or updates document files for a driver.
  Future<void> uploadDriverDocs(FormData formData) async {
    await _apiClient.post<dynamic>('/v1.0/uploadDriverDocs', data: formData);
  }

  /// Deletes one stored document file ([docId]) of [docType] for [driverId].
  Future<void> deleteDriverDoc(
    int driverId,
    String docType,
    String docId,
  ) async {
    await _apiClient.post<dynamic>(
      '/v1.0/deleteDriverDocs',
      data: {
        'Target': 'Driver',
        'RecordId': driverId,
        'Type': docType,
        'DocumentId': docId,
      },
    );
  }
}
