import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/src/dialogs/tracking_info_dialog.dart';

/// Home -> maps page -> "Show Dialog" opens the SDK info dialog.
Future<void> _openMapsAndDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () =>
                          showTrackingInfoDialog(context, 'Route Ended'),
                      child: const Text('Show Dialog'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Open Maps'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Maps'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Show Dialog'));
  await tester.pump();
  expect(find.text('Route Ended'), findsOneWidget);
}

void main() {
  group('showTrackingInfoDialog', () {
    testWidgets('Close pops both the dialog and the maps page', (tester) async {
      await _openMapsAndDialog(tester);
      await tester.tap(find.textContaining('Close ('));
      await tester.pumpAndSettle();
      expect(find.text('Route Ended'), findsNothing);
      expect(find.text('Show Dialog'), findsNothing);
      expect(find.text('Open Maps'), findsOneWidget);
    });

    testWidgets('countdown completion pops both', (tester) async {
      await _openMapsAndDialog(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Route Ended'), findsNothing);
      expect(find.text('Open Maps'), findsOneWidget);
    });

    testWidgets('stays open for the countdown with animations disabled', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _openMapsAndDialog(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Route Ended'), findsOneWidget);
    });
  });
}
