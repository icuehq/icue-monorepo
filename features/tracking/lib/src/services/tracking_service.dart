import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';
import 'package:tracking/src/models/fleet_status_report.dart';

@lazySingleton
class TrackingService {
  const TrackingService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches fleet departure and trip operational progress by slot.
  Future<FleetStatusReport> getVehicleStartStatusReport() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVehicleStartStatusReport',
      data: <String, dynamic>{},
    );

    if (response.data is Map<String, dynamic>) {
      return FleetStatusReport.fromJson(response.data as Map<String, dynamic>);
    }
    return const FleetStatusReport();
  }

  /// Fetches real-time web map tracking URL for a specific route run.
  Future<String?> getLiveTrackUrl({
    required int routeDetailsId,
    required String routeNo,
    required String mode,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getLiveTrackUrl',
      data: <String, dynamic>{
        'RouteDetailsId': routeDetailsId,
        'RouteNo': routeNo,
        'Mode': mode,
      },
    );

    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      final err = map['err'] as bool? ?? false;
      if (!err && map['data'] is Map<String, dynamic>) {
        final data = map['data'] as Map<String, dynamic>;
        return data['trackLink'] as String?;
      }
    }
    return null;
  }
}
