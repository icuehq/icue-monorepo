import 'dart:async';

import 'package:drop_boarding/src/models/boarding_type.dart';
import 'package:drop_boarding/src/models/vehicle_arrival.dart';
import 'package:drop_boarding/src/services/drop_boarding_service.dart';
import 'package:drop_boarding/src/services/drop_boarding_socket_service.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:routes/routes.dart';

@injectable
class DropBoardingProvider extends ChangeNotifier {
  DropBoardingProvider(
    this._dropBoardingService,
    this._dropBoardingSocketService,
    this._routeService,
  );

  final DropBoardingService _dropBoardingService;
  final DropBoardingSocketService _dropBoardingSocketService;
  final RouteService _routeService;

  List<VehicleArrival> _vehicleArrivals = <VehicleArrival>[];
  List<Routee> _dropRoutes = <Routee>[];
  List<BoardingType> _boardingTypes = <BoardingType>[];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<VehicleArrival>>? _socketSubscription;

  List<VehicleArrival> get vehicleArrivals =>
      List<VehicleArrival>.unmodifiable(_vehicleArrivals);

  /// Arrived vehicles waiting for boarding / departure.
  List<VehicleArrival> get arrivedVehicles =>
      _vehicleArrivals.where((v) => v.status == 'ARRIVED').toList();

  /// Routes eligible for drop-off arrival (not yet arrived).
  List<Routee> get routesForDropOff {
    final arrivedIds = _vehicleArrivals.map((e) => e.id).toSet();
    return _dropRoutes.where((r) => !arrivedIds.contains(r.id)).toList();
  }

  List<BoardingType> get boardingTypes =>
      List<BoardingType>.unmodifiable(_boardingTypes);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetches both current vehicle arrivals and drop routes in parallel.
  Future<void> fetchInitialData({
    required int zoneId,
    required int branchId,
    required int organizationId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _dropBoardingService.getVehicleArrivals(
          zoneId: zoneId,
          branchId: branchId,
          organizationId: organizationId,
        ),
        _routeService.getRoutesAndPoints(RouteMode.drop),
      ]);

      _vehicleArrivals = results[0] as List<VehicleArrival>;
      _dropRoutes = results[1] as List<Routee>;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches vehicle arrivals list only.
  Future<void> fetchVehicleArrivals({
    required int zoneId,
    required int branchId,
    required int organizationId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehicleArrivals = await _dropBoardingService.getVehicleArrivals(
        zoneId: zoneId,
        branchId: branchId,
        organizationId: organizationId,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches configured boarding zone types.
  Future<void> fetchBoardingTypes({
    required int zoneId,
    required int branchId,
    required int organizationId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _boardingTypes = await _dropBoardingService.getBoardingTypes(
        zoneId: zoneId,
        branchId: branchId,
        organizationId: organizationId,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits ARRIVED status for selected drop-off routes.
  Future<bool> markVehiclesArrived({
    required int zoneId,
    required int branchId,
    required int organizationId,
    required List<int> routeIds,
    String? boardingZone,
  }) async {
    final idSet = routeIds.toSet();
    final selectedRoutes = _dropRoutes
        .where((r) => idSet.contains(r.id))
        .toList();

    if (selectedRoutes.isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final vehiclesPayload = selectedRoutes
          .map(
            (e) => <String, dynamic>{
              'RouteId': e.id,
              'RouteNo': e.routeNo,
              'VehicleNumber': e.vehicleNumber ?? '',
              'StartTime': e.routeStartTime ?? '',
              'Status': 'ARRIVED',
              'BoardingType': ?boardingZone,
            },
          )
          .toList();

      final success = await _dropBoardingService
          .updateMultiVehicleArrivalStatus(
            zoneId: zoneId,
            branchId: branchId,
            organizationId: organizationId,
            vehicles: vehiclesPayload,
          );

      if (success) {
        await fetchVehicleArrivals(
          zoneId: zoneId,
          branchId: branchId,
          organizationId: organizationId,
        );
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submits LEFT status for departed vehicles.
  Future<bool> markVehiclesLeft({
    required int zoneId,
    required int branchId,
    required int organizationId,
    required List<int> routeIds,
  }) async {
    if (routeIds.isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final vehiclesPayload = routeIds.map((id) {
        final dropRoute = _dropRoutes.where((r) => r.id == id).firstOrNull;
        final arrival = _vehicleArrivals.where((a) => a.id == id).firstOrNull;

        return <String, dynamic>{
          'RouteId': id,
          'RouteNo': dropRoute?.routeNo ?? arrival?.routeNo ?? '',
          'VehicleNumber':
              dropRoute?.vehicleNumber ?? arrival?.vehicleNumber ?? '',
          'StartTime': dropRoute?.routeStartTime ?? '',
          'Status': 'LEFT',
        };
      }).toList();

      final success = await _dropBoardingService
          .updateMultiVehicleArrivalStatus(
            zoneId: zoneId,
            branchId: branchId,
            organizationId: organizationId,
            vehicles: vehiclesPayload,
          );

      if (success) {
        await fetchVehicleArrivals(
          zoneId: zoneId,
          branchId: branchId,
          organizationId: organizationId,
        );
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initializes real-time socket updates for vehicle arrivals.
  void initSocket({required String baseUrl, required int branchId}) {
    _socketSubscription?.cancel();
    _dropBoardingSocketService.connect(baseUrl: baseUrl, branchId: branchId);

    _socketSubscription = _dropBoardingSocketService.onArrivalsUpdated.listen((
      arrivals,
    ) {
      _vehicleArrivals = arrivals;
      notifyListeners();
    });
  }

  /// Updates vehicle arrivals directly (useful for tests and socket events).
  void updateArrivals(List<VehicleArrival> arrivals) {
    _vehicleArrivals = arrivals;
    notifyListeners();
  }

  /// Disconnects real-time socket updates.
  void disconnectSocket() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _dropBoardingSocketService.disconnect();
  }

  @override
  void dispose() {
    disconnectSocket();
    super.dispose();
  }
}
