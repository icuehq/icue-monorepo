import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fixAgeSeconds reads HH:mm:ss and falls back to 999', () {
    expect(fixAgeSeconds('10:00:00', '10:00:20'), 20);
    expect(fixAgeSeconds('x', '10:00:20'), 999);
  });
}
