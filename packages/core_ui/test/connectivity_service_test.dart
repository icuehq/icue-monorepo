import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements Connectivity {
  // Test-lifetime controller; never needs closing.
  // ignore: close_sinks
  final controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> current = [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;
}

void main() {
  test('tracks online/offline and notifies only on change', () async {
    final fake = _Fake();
    final s = ConnectivityService(connectivity: fake);
    var notified = 0;
    s.addListener(() => notified++);
    await s.init();
    expect(s.isOnline, isTrue);

    fake.controller.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(s.isOnline, isFalse);

    fake.controller.add([ConnectivityResult.none]);
    fake.controller.add([ConnectivityResult.mobile, ConnectivityResult.vpn]);
    await Future<void>.delayed(Duration.zero);
    expect(s.isOnline, isTrue);
    expect(notified, 2);
  });

  test('starts offline when initial check reports none', () async {
    final fake = _Fake()..current = [ConnectivityResult.none];
    final s = ConnectivityService(connectivity: fake);
    await s.init();
    expect(s.isOnline, isFalse);
  });
}
