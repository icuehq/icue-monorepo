import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parent_transport/src/models/vehicle_location.dart';

/// Everything the map needs for one refresh.
class LiveData {
  const LiveData({
    required this.coordinates,
    required this.polyline,
    required this.hasNetwork,
    this.studentStop,
    this.stops = const <RouteStop>[],
    this.etaValue,
    this.msgAvailable,
  });

  /// Newest [lat, lng] fix of the bus; empty when unknown.
  final List<double> coordinates;
  final List<LatLng> polyline;

  /// False when the bus's last fix is 25 s or older than the server time.
  final bool hasNetwork;
  final RouteStop? studentStop;

  /// All stops of the route, shown as tappable markers.
  final List<RouteStop> stops;
  final String? etaValue;
  final bool? msgAvailable;

  /// Null unless both coordinates are finite; Google Maps throws on NaN.
  LatLng? get busPosition =>
      coordinates.length >= 2 &&
          coordinates.first.isFinite &&
          coordinates.last.isFinite
      ? LatLng(coordinates.first, coordinates.last)
      : null;
}
