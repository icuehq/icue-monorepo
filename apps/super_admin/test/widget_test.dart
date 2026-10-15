import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_admin/ui/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassCard(child: Text('ICUE Glass Card'))),
      ),
    );

    expect(find.text('ICUE Glass Card'), findsOneWidget);
  });
}
