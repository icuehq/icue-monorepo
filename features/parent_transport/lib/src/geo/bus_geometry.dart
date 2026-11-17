import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Great-circle distance in metres; infinity when the result is not finite.
double distanceMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = (b.latitude - a.latitude) * pi / 180;
  final dLng = (b.longitude - a.longitude) * pi / 180;
  final h =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(a.latitude * pi / 180) *
          cos(b.latitude * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final clamped = h.clamp(0.0, 1.0);
  final meters = earthRadius * 2 * atan2(sqrt(clamped), sqrt(1 - clamped));
  return meters.isFinite ? meters : double.infinity;
}

/// Marker rotation in degrees [0, 360) for a bus driving from [start] to [end]
/// (the bus icon points right, hence the +90).
double busRotation(LatLng start, LatLng end) {
  final lat1 = start.latitude * pi / 180;
  final lat2 = end.latitude * pi / 180;
  final dLng = (end.longitude - start.longitude) * pi / 180;
  final y = sin(dLng) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 90) % 360;
}

/// Rotates from [start] to [end] by fraction [t] along the shorter way round.
double interpolateRotation(double start, double end, double t) {
  var diff = end - start;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  final result = (start + diff * t) % 360;
  return result < 0 ? result + 360 : result;
}

LatLng interpolateLatLng(LatLng start, LatLng end, double t) => LatLng(
  start.latitude + (end.latitude - start.latitude) * t,
  start.longitude + (end.longitude - start.longitude) * t,
);

/// Snaps GPS fixes to the route polyline so the bus stays on the road.
/// Remembers the last match so each search starts near it.
class PolylineSnapper {
  int _lastIndex = 0;

  /// Distance above which a fix is considered off-route and left unsnapped.
  static const double offRouteMeters = 50;

  void reset() => _lastIndex = 0;

  LatLng snap(LatLng position, List<LatLng> polyline) {
    if (polyline.isEmpty) return position;
    var start = _lastIndex;
    if (start >= polyline.length) start = 0;

    var nearest = polyline[start];
    var best = double.infinity;
    var bestIndex = start;

    for (var i = start; i < polyline.length; i++) {
      final d = distanceMeters(position, polyline[i]);
      if (d < best) {
        best = d;
        nearest = polyline[i];
        bestIndex = i;
      } else if (d > best * 2) {
        break;
      }
    }
    for (var i = start - 1; i >= 0 && i >= start - 10; i--) {
      final d = distanceMeters(position, polyline[i]);
      if (d < best) {
        best = d;
        nearest = polyline[i];
        bestIndex = i;
      }
    }
    _lastIndex = bestIndex;
    return best > offRouteMeters ? position : nearest;
  }
}
