import 'package:api_client/api_client.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:parent_transport/src/models/route_coordinates.dart';
import 'package:parent_transport/src/models/route_notification.dart';
import 'package:parent_transport/src/models/student_vehicle.dart';
import 'package:parent_transport/src/models/transport_record.dart';
import 'package:parent_transport/src/models/vehicle_location.dart';

/// Outcome of `/getVehicleLocation`: 204 means no run is active.
sealed class VehicleLocationResult {
  const VehicleLocationResult();
}

class VehicleLocationData extends VehicleLocationResult {
  const VehicleLocationData(this.location);
  final VehicleLocation location;
}

class VehicleLocationNone extends VehicleLocationResult {
  const VehicleLocationNone();
}

class VehicleLocationRefused extends VehicleLocationResult {
  const VehicleLocationRefused(this.message);
  final String? message;
}

/// Route/vehicle/attendance endpoints of the parent app.
@lazySingleton
class ParentTransportService {
  const ParentTransportService(this._apiClient);

  final ApiClient _apiClient;

  Future<VehicleLocationResult> getVehicleLocation({
    required int studentId,
    required bool routeCached,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVehicleLocation',
      data: <String, dynamic>{
        'StudentId': studentId,
        'isCoOrdinatesAvailable': routeCached,
        'updateApp': true,
      },
    );
    if (response.statusCode == 204) return const VehicleLocationNone();
    final data = response.data as Map<String, dynamic>?;
    if (response.statusCode == 200 && data != null) {
      return VehicleLocationData(VehicleLocation.fromJson(data));
    }
    return VehicleLocationRefused(data?['message'] as String?);
  }

  /// True when the cached route is outdated (or the check failed to run).
  Future<bool> routeChanged({
    required int studentId,
    required int routeDetailsId,
    required String traceDate,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getTraceDate',
      data: <String, dynamic>{
        'StudentId': studentId,
        'RouteDetailsId': routeDetailsId,
        'TraceDate': traceDate,
      },
    );
    return (response.data as Map<String, dynamic>)['ToUpdate'] == true;
  }

  Future<RouteCoordinates> getRouteCoordinates({
    required int studentId,
    required int routeDetailsId,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getRouteCoordinate',
      data: <String, dynamic>{
        'StudentId': studentId,
        'RouteDetailsId': routeDetailsId,
      },
    );
    return RouteCoordinates.fromJson(response.data as Map<String, dynamic>);
  }

  /// Connection statistics the school uses to monitor parent app usage.
  Future<void> pingConnectionStats({
    required int studentId,
    required String? contact,
    required Map<String, dynamic> deviceInfo,
    required DateTime now,
  }) => _apiClient.post<dynamic>(
    '/v1.0/pingConnStats',
    data: <String, dynamic>{
      'StudentId': studentId,
      'State': 'api',
      'Month': '${now.month}',
      'Year': '${now.year}',
      'App': 'iCueParentApp',
      'Contact': contact,
      ...deviceInfo,
    },
  );

  /// Route id and mode of the student's first route (`/getStuRtDetails`),
  /// used to ask the serverless tracker for the active run.
  Future<({int routeId, String? mode})?> getStudentRoute(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getStuRtDetails',
      data: <String, dynamic>{'StudentId': studentId},
    );
    final routes =
        (response.data as Map<String, dynamic>)['Routes'] as List<dynamic>?;
    final first = routes?.firstOrNull as Map<String, dynamic>?;
    if (first == null) return null;
    return (
      routeId: (first['Id'] as num).toInt(),
      mode: first['Mode'] as String?,
    );
  }

  Future<List<RouteNotification>> getRouteNotifications({
    required int studentId,
    required int routeTrackId,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getRouteNotifications',
      data: <String, dynamic>{
        'StudentId': studentId,
        'RouteTrackId': routeTrackId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['msgs'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => RouteNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransportRecord>> getTransportRecords({
    required int studentId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getStuTransportInfo',
      data: <String, dynamic>{
        'StudentId': studentId,
        'ReportMode': 'byperiod',
        'FromDate': from?.toUsDate(),
        'ToDate': to?.toUsDate(),
        'PageNumber': 1,
        'PageSize': 50,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => TransportRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StudentVehicle>> getStudentVehicles(StudentScope student) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/getStudentVehicles',
      data: student.toJson(),
    );
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => StudentVehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveStudentVehicle(
    StudentScope student,
    String vehicleNumber,
    List<String> mobiles,
  ) => _apiClient.post<dynamic>(
    '/v2.0/saveStudentVehicle',
    data: <String, dynamic>{
      'VehicleNo': vehicleNumber,
      'Mobiles': mobiles,
      ...student.toJson(),
    },
  );

  Future<void> deleteStudentVehicle(int studentId, int vehicleId) =>
      _apiClient.post<dynamic>(
        '/v2.0/deleteStudentVehicle',
        data: <String, dynamic>{'Id': vehicleId, 'StudentId': studentId},
      );
}

/// A student with the organisation/zone/branch the v2.0 vehicle endpoints want in the body.
class StudentScope {
  const StudentScope({
    required this.studentId,
    required this.organizationId,
    required this.zoneId,
    required this.branchId,
  });

  final int studentId;
  final int organizationId;
  final int zoneId;
  final int branchId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'StudentId': studentId,
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
  };
}
