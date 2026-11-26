import 'dart:developer';

import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:icue_sdk/src/models/live_data.dart';
import 'package:icue_sdk/src/models/route_coordinates.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/models/vehicle_location.dart';
import 'package:icue_sdk/src/services/device_info_service.dart';
import 'package:icue_sdk/src/services/networking/api_client.dart';
import 'package:injectable/injectable.dart';

@lazySingleton

/// Orchestrates live route polling, coordinates caching, and UI-facing state
/// for vehicle tracking.
class VehicleProvider extends ChangeNotifier {
  VehicleProvider({
    required ApiClient apiClient,
    required DeviceInfoService deviceInfoService,
  })  : _apiClient = apiClient,
        _deviceInfoService = deviceInfoService;

  Map<int, List<RouteCoOrdinate>> busStopsMap = {};
  String? driverMobile;
  String? errorMessage;
  bool isTrackingAvailable = false;
  LiveData? liveData;
  bool loading = false;
  Map<int, String> modeMap = {};
  Map<int, RouteCoordinates> routeCoordinatesMap = {};
  bool routeEnded = false;
  Map<String, RouteCoOrdinate> studentPointMap = {};
  bool toUpdate = true;
  VehicleLocation? vehicleLocation;

  final ApiClient _apiClient;
  final DeviceInfoService _deviceInfoService;
  // Cancel token for the active getVehicleLocation request.
  CancelToken? _locationCancelToken;

  /// Resets all in-memory state for a fresh tracking session.
  Future<void> clearAllData({
    bool clearMsg = false,
    bool clearHive = true,
  }) async {
    _locationCancelToken?.cancel('Tracking session ended');
    _locationCancelToken = null;

    if (clearMsg) {
      errorMessage = null;
    }
    isTrackingAvailable = false;
    routeEnded = false;
    liveData = null;
    toUpdate = true;
    driverMobile = null;
    routeCoordinatesMap.clear();
    busStopsMap.clear();
    vehicleLocation = null;
    studentPointMap.clear();

    notifyListeners();
  }

  Future<bool> getTraceDate({
    required int studentId,
    String? date,
    int? routeDetailsId,
  }) async {
    if (date == null || routeDetailsId == null) return true;

    try {
      final response = await _apiClient.postJson<dynamic>(
        ApiRoutes.traceDate,
        body: {
          'StudentId': studentId,
          'RouteDetailsId': routeDetailsId,
          'TraceDate': date,
        },
      );
      if (response.isSuccess && response.data != null) {
        return (response.data as Map<String, dynamic>)['ToUpdate'] == true;
      }
      log(
        'getTraceDate failed [${response.statusCode}]: ${response.error?.message}',
      );
      return false;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        log('getTraceDate network error', error: e);
      }
      return false;
    } catch (error, stack) {
      log('getTraceDate error', error: error, stackTrace: stack);
      return false;
    }
  }

  Future<void> getRouteCoordinate({
    required int studentId,
    int? routeDetailsId,
    CancelToken? cancelToken,
  }) async {
    final cache = routeCoordinatesMap[studentId];
    toUpdate = cache == null ||
        await getTraceDate(
          studentId: studentId,
          date: cache.defaultRouteDate,
          routeDetailsId: routeDetailsId,
        );

    if (!toUpdate) return;

    try {
      final response = await _apiClient.postJson<RouteCoordinates>(
        ApiRoutes.routeCoordinate,
        body: {'StudentId': studentId, 'RouteDetailsId': routeDetailsId},
        decoder: (json) =>
            RouteCoordinates.fromJson(json as Map<String, dynamic>),
        cancelToken: cancelToken,
      );
      if (response.isSuccess && response.data != null) {
        routeCoordinatesMap[studentId] = response.data!;
      } else if (response.error != null) {
        log(
          'getRouteCoordinate failed [${response.statusCode}]: ${response.error?.message}',
        );
      }
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        log('getRouteCoordinate network error', error: e);
      }
    } catch (error, stack) {
      log('getRouteCoordinate error', error: error, stackTrace: stack);
    } finally {
      notifyListeners();
    }
  }

  Future<void> pingConnStats(int studentId, {CancelToken? cancelToken}) async {
    try {
      final now = DateTime.now();
      final deviceInfo = await _deviceInfoService.getDeviceInfo();
      await _apiClient.postJson<dynamic>(
        ApiRoutes.pingConnStats,
        body: {
          'StudentId': studentId,
          'State': 'api',
          'Month': now.month.toString(),
          'Year': now.year.toString(),
          'App': 'iCueParentApp',
          ...deviceInfo,
        },
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        log('pingConnStats network error', error: e);
      }
    } catch (error, stack) {
      log('pingConnStats error', error: error, stackTrace: stack);
    }
  }

  Future<LiveData?> getVehicleLocation({
    bool isPolling = false,
    required User student,
  }) async {
    // Cancel any in-flight request before starting a new one.
    _locationCancelToken?.cancel('New request started');
    _locationCancelToken = CancelToken();
    final cancelToken = _locationCancelToken!;

    try {
      final cache = routeCoordinatesMap[student.id];
      if (cache == null) {
        loading = true;
        notifyListeners();
      }

      final response = await _apiClient.postJson<dynamic>(
        ApiRoutes.vehicleLocation,
        body: {
          'StudentId': student.id,
          'isCoOrdinatesAvailable': cache != null,
          'updateApp': true,
        },
        cancelToken: cancelToken,
      );
      if (response.statusCode == 200) {
        return await _handleSuccess(
          response.data as Map<String, dynamic>,
          cache != null,
          isPolling,
          student,
          cancelToken,
        );
      } else if (response.statusCode == 204) {
        await _handleNoContent(cache != null);
        return null;
      } else {
        log(
          'getVehicleLocation unexpected status [${response.statusCode}]: ${response.error?.message}',
        );
        await _handleOther(response.data as Map<String, dynamic>?);
        return null;
      }
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        log('getVehicleLocation network error', error: e);
      }
      return null;
    } catch (error, stack) {
      log('getVehicleLocation error', error: error, stackTrace: stack);
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _handleNoContent(bool hadCache) async {
    errorMessage = hadCache ? 'Route is Completed' : 'Route not started';
    await clearAllData();
  }

  Future<LiveData> _handleSuccess(
    Map<String, dynamic> data,
    bool hadCache,
    bool isPolling,
    User student,
    CancelToken cancelToken,
  ) async {
    errorMessage = null;
    isTrackingAvailable = true;
    routeEnded = false;

    final details = VehicleLocation.fromJson(data);
    vehicleLocation = details;
    if (driverMobile != null) {
      final digits = driverMobile!.replaceAll(RegExp(r'\D'), '');
      vehicleLocation?.driverData?.mobile = int.tryParse(digits) ?? 0;
    }

    if (details.mode != null) {
      modeMap[student.id] = details.mode!;
    }

    if (details.routeCoOrdinates != null) {
      busStopsMap[student.id] = details.routeCoOrdinates ?? [];
    }

    // cache driver mobile
    if (details.driverData != null) {
      driverMobile = '${details.driverData?.mobile}';
    }

    // on first load, seed student pickup/drop points
    if (!hadCache) {
      for (final RouteCoOrdinate pt in details.routeCoOrdinates ?? []) {
        if (pt.pickPoint == student.dropPoint) {
          studentPointMap['Drop'] = pt;
        }

        if (pt.pickPoint == student.pickPoint) {
          studentPointMap['Pickup'] = pt;
        }
      }
    } else {
      log('getVehicleLocation polled => ${details.coordinates.firstOrNull}');
    }
    if (!isPolling) {
      await Future.wait([
        getRouteCoordinate(
          studentId: student.id,
          routeDetailsId: details.routeDetailsId,
          cancelToken: cancelToken,
        ),
        pingConnStats(student.id, cancelToken: cancelToken),
      ]);
    }

    final newData = await _buildLiveData(details, student.id);
    liveData = newData;
    return newData;
  }

  Future<void> _handleOther(Map<String, dynamic>? respData) async {
    if (respData?['err'] == true) {
      errorMessage = respData?['message']?.toString();
      await clearAllData();
    }
  }

  Future<LiveData> _buildLiveData(
    VehicleLocation details,
    int studentId,
  ) async {
    final mode = modeMap[studentId];
    List<double> curr = [];
    List<double> prev = [];

    prev = details.coordinates.lastOrNull ?? [];
    curr = details.coordinates.firstOrNull ?? [];

    final pt = studentPointMap[mode];
    final routeCoordinates = routeCoordinatesMap[studentId];
    final route = routeCoordinates?.offlineCoordinates ?? [];

    final poly = route
        .map((e) => LatLng(e.firstOrNull ?? 0, e.lastOrNull ?? 0))
        .toList();
    final ageSec = fixAgeSeconds(details.coordinatesTime, details.serverTime);

    return LiveData(
      coordinates: curr,
      prevCoordinates: prev,
      studentPoint: pt,
      busStops: busStopsMap[studentId],
      polylineCoordinates: poly,
      hasNetwork: ageSec < 25,
      recentCoordinates: details.coordinates,
      etaValue: details.etaValue,
      speed: details.coordinatesSpeed,
      routeCoordinates: routeCoordinatesMap[studentId],
      msgAvailable: details.msgAvailable,
      routeNo: details.routeNo,
      routeTrackId: details.routeTrackId,
      pickupPoint: studentPointMap['Pickup'],
      dropPoint: studentPointMap['Drop'],
    );
  }
}
