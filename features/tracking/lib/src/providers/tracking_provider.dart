import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:tracking/src/models/fleet_status_report.dart';
import 'package:tracking/src/models/vehicle_slot_item.dart';
import 'package:tracking/src/services/tracking_service.dart';
import 'package:tracking/src/services/tracking_socket_service.dart';

@lazySingleton
class TrackingProvider extends ChangeNotifier {
  TrackingProvider(this._trackingService, this._socketService);

  final TrackingService _trackingService;
  final TrackingSocketService _socketService;

  bool _isLoading = false;
  String? _errorMessage;
  FleetStatusReport? _fleetStatus;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  FleetStatusReport? get fleetStatus => _fleetStatus;

  /// Returns vehicles currently in progress for live tracking.
  List<VehicleSlotItem> get activeRunningVehicles =>
      _fleetStatus?.allInProgress ?? const <VehicleSlotItem>[];

  /// Loads fleet departure and operational progress from API.
  Future<void> fetchFleetStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _fleetStatus = await _trackingService.getVehicleStartStatusReport();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resolves the live map tracking link for a vehicle run.
  Future<String?> resolveLiveTrackUrl({
    required int routeDetailsId,
    required String routeNo,
    required String mode,
  }) async {
    try {
      return await _trackingService.getLiveTrackUrl(
        routeDetailsId: routeDetailsId,
        routeNo: routeNo,
        mode: mode,
      );
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  /// Connects to real-time socket and updates fleet status as live events arrive.
  void initSocket({
    required String baseUrl,
    required int zoneId,
    required int branchId,
    required int organizationId,
  }) {
    _socketSub?.cancel();
    _socketService.connect(
      baseUrl: baseUrl,
      zoneId: zoneId,
      branchId: branchId,
      organizationId: organizationId,
    );

    _socketSub = _socketService.onRouteStats.listen((data) {
      updateFromSocket(data);
    });
  }

  /// Ingests real-time packet from websocket.
  void updateFromSocket(Map<String, dynamic> raw) {
    try {
      _fleetStatus = FleetStatusReport.fromJson(raw);
      notifyListeners();
    } catch (e) {
      debugPrint('[TrackingProvider] Failed to parse socket routeStats: $e');
    }
  }

  /// Disconnects the live socket.
  void disconnectSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _socketService.disconnect();
  }

  @override
  void dispose() {
    disconnectSocket();
    super.dispose();
  }
}
