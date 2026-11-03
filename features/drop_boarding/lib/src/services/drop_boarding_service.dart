import 'package:api_client/api_client.dart';
import 'package:drop_boarding/src/models/boarding_type.dart';
import 'package:drop_boarding/src/models/vehicle_arrival.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class DropBoardingService {
  DropBoardingService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches the current vehicle arrival statuses for the given organization/branch.
  Future<List<VehicleArrival>> getVehicleArrivals({
    required int zoneId,
    required int branchId,
    required int organizationId,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhArrivals',
      data: {
        'ZoneId': zoneId,
        'BranchId': branchId,
        'OrganizationId': organizationId,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final res = VehicleArrivalsResponse.fromJson(data);
      return res.data;
    }
    return <VehicleArrival>[];
  }

  /// Fetches available boarding zone types for the branch.
  Future<List<BoardingType>> getBoardingTypes({
    required int zoneId,
    required int branchId,
    required int organizationId,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getBoardingTypes',
      data: {
        'ZoneId': zoneId,
        'BranchId': branchId,
        'OrganizationId': organizationId,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final res = BoardingTypesResponse.fromJson(data);
      return res.data;
    }
    return <BoardingType>[];
  }

  /// Updates arrival or departure status for a collection of vehicle routes.
  Future<bool> updateMultiVehicleArrivalStatus({
    required int zoneId,
    required int branchId,
    required int organizationId,
    required List<Map<String, dynamic>> vehicles,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/updateMultiVehicleArrivalStatus',
      data: {
        'ZoneId': zoneId,
        'BranchId': branchId,
        'OrganizationId': organizationId,
        'Vehicles': vehicles,
      },
    );

    return response.statusCode == 200;
  }
}
