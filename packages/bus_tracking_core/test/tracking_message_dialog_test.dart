import 'package:bus_tracking_core/bus_tracking_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _open(WidgetTester tester) async {
  var closed = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => TrackingMessageDialog(
                message: 'Route not started',
                onClose: (context) {
                  closed++;
                  Navigator.of(context).pop();
                },
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  return closed;
}

void main() {
  testWidgets('counts down and closes once after 5 seconds', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingMessageDialog(
          message: 'Route not started',
          onClose: (_) => closed++,
        ),
      ),
    );
    expect(find.text('Close (5)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Close (3)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(closed, 1);
  });

  testWidgets('Close button closes the dialog', (tester) async {
    await _open(tester);
    expect(find.text('Route not started'), findsOneWidget);
    await tester.tap(find.textContaining('Close ('));
    await tester.pumpAndSettle();
    expect(find.text('Route not started'), findsNothing);
  });

  testWidgets('back closes through onClose', (tester) async {
    await _open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Route not started'), findsNothing);
  });

  testWidgets('keeps the countdown when animations are disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Route not started'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Route not started'), findsNothing);
  });
}
