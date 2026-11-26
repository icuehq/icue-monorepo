import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:parent_transport/src/models/live_data.dart';
import 'package:parent_transport/src/models/live_track.dart';
import 'package:parent_transport/src/models/route_coordinates.dart';
import 'package:parent_transport/src/models/vehicle_location.dart';
import 'package:parent_transport/src/services/location_service.dart';
import 'package:parent_transport/src/services/parent_transport_service.dart';

enum TrackingStatus {
  /// First fetch in flight.
  loading,

  /// The bus is on the map.
  live,

  /// No run is active yet today.
  notStarted,

  /// The run finished.
  completed,

  /// The server refused or returned nothing usable; see
  /// [ParentTrackingProvider.message].
  unavailable,
}

/// Live bus tracking for the selected student. Students on the serverless
/// tracker (`isServerLessConfig`) use [LocationService]; the others poll the
/// school server. Route data is cached in memory per student.
@lazySingleton
class ParentTrackingProvider extends ChangeNotifier {
  ParentTrackingProvider(
    this._service,
    this._location,
    this._auth,
    this._deviceInfo,
  ) {
    _studentIdSeen = _auth.selectedStudent?.id;
    _auth.addListener(_onAuthChanged);
  }

  final ParentTransportService _service;
  final LocationService _location;
  final ParentAuthProvider _auth;
  final ParentDeviceInfo _deviceInfo;

  TrackingStatus status = TrackingStatus.loading;
  String? message;
  LiveData? liveData;

  /// Shown on the info card.
  String routeNo = '';
  int routeTrackId = 0;
  String? driverMobile;

  RouteCoordinates? _route;
  List<RouteStop> _stops = <RouteStop>[];
  String? _mode;
  ActiveRoute? _activeRoute;
  int? _routeDetailsId;
  int? _studentIdSeen;

  ParentStudent? get student => _auth.selectedStudent;
  bool get isLive => status == TrackingStatus.live;

  void _onAuthChanged() {
    final id = _auth.selectedStudent?.id;
    if (id == _studentIdSeen) return;
    _studentIdSeen = id;
    reset();
  }

  /// Forgets all cached route data (student changed or tracking restarted).
  void reset() {
    status = TrackingStatus.loading;
    message = null;
    liveData = null;
    routeNo = '';
    routeTrackId = 0;
    driverMobile = null;
    _route = null;
    _stops = <RouteStop>[];
    _mode = null;
    _activeRoute = null;
    _routeDetailsId = null;
    notifyListeners();
  }

  /// One refresh. [polling] is false for the first call of a page visit.
  Future<void> refresh({bool polling = false}) async {
    final current = student;
    if (current == null) return;
    try {
      if (current.isServerLessConfig ?? false) {
        await _refreshServerless(current);
      } else {
        await _refreshServer(current, polling: polling);
      }
    } on ApiException {
      // ApiClient already told the user; keep the last data on screen.
    } finally {
      notifyListeners();
    }
  }

  Future<void> _refreshServer(
    ParentStudent student, {
    required bool polling,
  }) async {
    final result = await _service.getVehicleLocation(
      studentId: student.id,
      routeCached: _route != null,
    );
    switch (result) {
      case VehicleLocationNone():
        _finish(
          _route != null ? TrackingStatus.completed : TrackingStatus.notStarted,
        );
      case VehicleLocationRefused(:final message):
        _finish(TrackingStatus.unavailable, message: message);
      case VehicleLocationData(:final location):
        final firstLoad = _route == null;
        routeNo = location.routeNo.isEmpty ? routeNo : location.routeNo;
        routeTrackId = location.routeTrackId;
        _mode = location.mode ?? _mode;
        if (location.driver != null) driverMobile = location.driver!.mobile;
        if (location.stops != null) _stops = location.stops!;
        await _loadRoute(student.id, location.routeDetailsId);
        status = TrackingStatus.live;
        message = null;
        liveData = _buildLiveData(
          student: student,
          coordinates: location.coordinates,
          coordinatesTime: location.coordinatesTime,
          serverTime: location.serverTime,
          etaValue: location.etaValue,
          msgAvailable: location.msgAvailable,
        );
        if (firstLoad && !polling) unawaited(_ping(student));
    }
  }

  Future<void> _refreshServerless(ParentStudent student) async {
    if (_activeRoute == null) {
      final route = await _service.getStudentRoute(student.id);
      if (route == null) return _finish(TrackingStatus.notStarted);
      _mode = route.mode;
      _routeDetailsId = route.routeId;
      _activeRoute = await _location.getActiveRoute(route.routeId);
      await _loadRoute(student.id, route.routeId);
    }
    final track = await _location.getLiveTrack(_activeRoute!);
    routeTrackId = int.tryParse(track.routeTrackId) ?? 0;
    status = TrackingStatus.live;
    message = null;
    liveData = _buildLiveData(
      student: student,
      coordinates: track.coordinates,
      coordinatesTime: track.coordinatesTime,
      serverTime: track.serverTime,
    );
  }

  void _finish(TrackingStatus end, {String? message}) {
    status = end;
    this.message = message;
    liveData = null;
    _route = null;
    _stops = <RouteStop>[];
    _activeRoute = null;
  }

  /// Fetches the route path, or reuses the cached one while the server says it is current.
  Future<void> _loadRoute(int studentId, int routeDetailsId) async {
    final cached = _route;
    if (cached != null && _routeDetailsId == routeDetailsId) {
      final date = cached.defaultRouteDate;
      final stale = date == null
          ? true
          : await _service.routeChanged(
              studentId: studentId,
              routeDetailsId: routeDetailsId,
              traceDate: date,
            );
      if (!stale) return;
    }
    _route = await _service.getRouteCoordinates(
      studentId: studentId,
      routeDetailsId: routeDetailsId,
    );
    _routeDetailsId = routeDetailsId;
  }

  Future<void> _ping(ParentStudent student) async {
    try {
      await _service.pingConnectionStats(
        studentId: student.id,
        contact: student.primaryContact,
        deviceInfo: _deviceInfo.json,
        now: DateTime.now(),
      );
    } on ApiException {
      // Statistics only.
    }
  }

  LiveData _buildLiveData({
    required ParentStudent student,
    required List<List<double>> coordinates,
    required String coordinatesTime,
    required String serverTime,
    String? etaValue,
    bool? msgAvailable,
  }) {
    final polyline = (_route?.path ?? <List<double>>[])
        .where((e) => e.length >= 2 && e.first.isFinite && e.last.isFinite)
        .map((e) => LatLng(e.first, e.last))
        .toList();
    return LiveData(
      coordinates: coordinates.firstOrNull ?? <double>[],
      polyline: polyline,
      hasNetwork: fixAgeSeconds(coordinatesTime, serverTime) < 25,
      studentStop: _studentStop(student),
      stops: _stops,
      etaValue: etaValue,
      msgAvailable: msgAvailable,
    );
  }

  /// The stop where this student boards (`Pickup`) or leaves (`Drop`) the bus.
  RouteStop? _studentStop(ParentStudent student) {
    final point = switch (_mode) {
      'Pickup' => student.pickPoint,
      'Drop' => student.dropPoint,
      _ => null,
    };
    if (point == null) return null;
    return _stops.where((s) => s.pickPoint == point).firstOrNull;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
