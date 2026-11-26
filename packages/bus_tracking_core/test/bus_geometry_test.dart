import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('distance of one degree of latitude is about 111 km', () {
    final d = distanceMeters(const LatLng(0, 0), const LatLng(1, 0));
    expect(d, closeTo(111195, 200));
  });

  test('distance of identical points is zero', () {
    const p = LatLng(17.4065, 78.4772);
    expect(distanceMeters(p, p), 0);
  });

  test('bearing is 0 going north and 90 going east', () {
    const origin = LatLng(17.4, 78.4);
    expect(bearingDegrees(origin, const LatLng(17.41, 78.4)), closeTo(0, 0.5));
    expect(bearingDegrees(origin, const LatLng(17.4, 78.41)), closeTo(90, 0.5));
  });

  test('bus icon rotation is the bearing plus 90', () {
    const origin = LatLng(17.4, 78.4);
    expect(busRotation(origin, const LatLng(17.41, 78.4)), closeTo(90, 0.5));
  });

  test('rotation takes the short way round 0/360', () {
    expect(interpolateRotation(350, 10, 0.5), closeTo(0, 0.001));
    expect(interpolateRotation(10, 350, 0.5), closeTo(0, 0.001));
  });

  test('interpolateLatLng halves the distance at t=0.5', () {
    final mid = interpolateLatLng(
      const LatLng(10, 20),
      const LatLng(20, 40),
      0.5,
    );
    expect(mid, const LatLng(15, 30));
  });

  test('extrapolate moves 100 m north', () {
    const start = LatLng(17.4, 78.4);
    final next = extrapolate(start, 0, 100);
    expect(distanceMeters(start, next), closeTo(100, 0.5));
    expect(next.longitude, closeTo(start.longitude, 1e-6));
  });

  test('snapper snaps near fixes and leaves far ones alone', () {
    const line = [LatLng(0, 0), LatLng(0, 0.0005), LatLng(0, 0.001)];
    final snapper = PolylineSnapper();
    const near = LatLng(0.00001, 0.00051);
    expect(snapper.snap(near, line), line[1]);
    const far = LatLng(0.01, 0.0005);
    expect(snapper.snap(far, line), far);
    expect(snapper.snap(const LatLng(5, 5), const []), const LatLng(5, 5));
  });
}
