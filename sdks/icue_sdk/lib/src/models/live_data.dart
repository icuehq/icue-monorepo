import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:icue_sdk/src/models/route_coordinates.dart';
import 'package:icue_sdk/src/models/vehicle_location.dart';

class LiveData {
  LiveData({
    required this.coordinates,
    required this.prevCoordinates,
    required this.polylineCoordinates,
    required this.hasNetwork,
    required this.recentCoordinates,
    required this.speed,
    required this.routeNo,
    required this.routeTrackId,
    this.studentPoint,
    this.busStops,
    this.routeCoordinates,
    this.etaValue,
    this.msgAvailable,
    this.pickupPoint,
    this.dropPoint,
  });

  final List<double> coordinates;
  final String? etaValue;
  final bool hasNetwork;
  final bool? msgAvailable;
  final List<LatLng> polylineCoordinates;
  final List<double> prevCoordinates;
  final List<List<double>> recentCoordinates;
  final RouteCoordinates? routeCoordinates;
  final RouteCoOrdinate? studentPoint;
  final RouteCoOrdinate? pickupPoint;
  final RouteCoOrdinate? dropPoint;
  final List<RouteCoOrdinate>? busStops;
  final num speed;
  final String routeNo;
  final int routeTrackId;
}
