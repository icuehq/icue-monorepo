import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, {bool eta = true, String? mobile}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackingInfoCard(
              pickPoint: 'Main Gate',
              routeNo: 'R1',
              showEta: eta,
              etaValue: '10:30',
              driverMobile: mobile,
            ),
          ),
        ),
      );

  testWidgets('shows route and ETA, hides call without a number', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Main Gate'), findsOneWidget);
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    expect(find.text('CALL DRIVER'), findsNothing);
  });

  testWidgets('hides ETA when disabled and shows call with a number', (
    tester,
  ) async {
    await pump(tester, eta: false, mobile: '9999999999');
    expect(find.text('10:30'), findsNothing);
    expect(find.text('CALL DRIVER'), findsOneWidget);
  });
}
