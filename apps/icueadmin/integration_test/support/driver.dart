import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/main.dart' as app;

/// Starts the real app (against the emulators, see e2e/README.md) and waits for its first screen: the Dashboard,
/// or the login screen when there is no stored session (see auth/login.dart).
Future<void> startApp(WidgetTester tester) async {
  app.main();
  await waitFor(
    tester,
    find.byWidgetPredicate(
      (_) =>
          find.textContaining('Welcome back').evaluate().isNotEmpty ||
          find.text('Generate OTP').evaluate().isNotEmpty,
    ),
    timeout: 60,
  );
}

/// Pumps frames until [finder] matches, failing after [timeout] seconds. Waiting on what the test expects is
/// faster and steadier than pumpAndSettle, which never settles while a progress indicator animates.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  int timeout = 15,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeout));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out after ${timeout}s waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 50));
}

/// True when [finder] matches within [wait] ms (for "skip if it already exists" guards).
Future<bool> appears(
  WidgetTester tester,
  Finder finder, {
  int wait = 600,
}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: wait));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) return false;
    await tester.pump(const Duration(milliseconds: 50));
  }
  return true;
}

/// Goes to a route directly, so a test does not click through the Dashboard and the hub every time.
Future<void> open(WidgetTester tester, String path) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(path);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Taps the first widget showing exactly [text], scrolling it into view first.
Future<void> tapText(WidgetTester tester, String text, {int index = 0}) async {
  final finder = find.text(text).at(index);
  await waitFor(tester, find.text(text));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Taps a widget found by [finder] (cards, icons, anything without exact text).
Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 200));
}

/// A text field by its label or hint text (they are rendered differently per screen).
Finder field(String label, {int index = 0}) => find
    .byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          (widget.decoration?.labelText == label ||
              widget.decoration?.hintText == label),
    )
    .at(index);

/// Replaces the content of the field labelled [label].
Future<void> fill(
  WidgetTester tester,
  String label,
  String value, {
  int index = 0,
}) async {
  await waitFor(tester, field(label, index: index));
  await tester.ensureVisible(field(label, index: index));
  await tester.enterText(field(label, index: index), value);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Finds a control by its text, tooltip or semantics label, in that order (FABs and icon buttons expose the label
/// as a tooltip, buttons as text).
Finder labelled(String label) {
  final byText = find.text(label);
  if (byText.evaluate().isNotEmpty) return byText;
  final byTooltip = find.byTooltip(label);
  if (byTooltip.evaluate().isNotEmpty) return byTooltip;
  return find.bySemanticsLabel(label);
}

/// Taps a text, tooltip or semantics label; [last] picks the last match (a dialog's confirm button that shares
/// its label with the title).
Future<void> tapLabel(
  WidgetTester tester,
  String label, {
  bool last = false,
}) async {
  await waitFor(
    tester,
    find.byWidgetPredicate((_) => labelled(label).evaluate().isNotEmpty),
  );
  final finder = last ? labelled(label).last : labelled(label).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Taps the [button] vertically closest to [target] (a per-row action menu in a list).
Future<void> tapNear(
  WidgetTester tester,
  Finder target,
  Finder button,
) async {
  await waitFor(tester, target);
  await tester.ensureVisible(target.first);
  await tester.pump(const Duration(milliseconds: 100));
  final targetY = tester.getCenter(target.first).dy;
  Element? best;
  var bestDistance = double.infinity;
  for (final element in button.evaluate()) {
    final box = element.renderObject! as RenderBox;
    final distance = (box.localToGlobal(box.size.center(Offset.zero)).dy - targetY).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      best = element;
    }
  }
  if (best == null) throw TestFailure('No $button near $target');
  await tester.tap(find.byElementPredicate((element) => element == best));
  await tester.pump(const Duration(milliseconds: 200));
}

/// Goes back one screen like the system Back button.
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Opens a date field showing [label] and sets it to today + [days] through the picker's text input mode.
Future<void> pickDate(WidgetTester tester, String label, int days) async {
  final date = DateTime.now().add(Duration(days: days));
  String two(int n) => n.toString().padLeft(2, '0');
  await tapText(tester, label);
  await waitFor(tester, find.byIcon(Icons.edit_outlined));
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(
    find.byType(TextField).last,
    '${two(date.month)}/${two(date.day)}/${date.year}',
  );
  await tapText(tester, 'OK');
}

final List<String> _failures = [];

/// Runs one guide step; a failure is recorded and the run continues with the next step. Call [finish] last.
Future<void> step(
  WidgetTester tester,
  String name,
  Future<void> Function() body,
) async {
  final stopwatch = Stopwatch()..start();
  try {
    await body();
    debugPrint('PASS  $name (${stopwatch.elapsed.inSeconds}s)');
  } on Object catch (error) {
    _failures.add('$name: $error');
    debugPrint('FAIL  $name: $error');
    for (var i = 0; i < 3; i++) {
      await tester.binding.handlePopRoute(); // close a dialog or page a failed step left open
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
}

/// Fails the test when any [step] failed.
void finish() {
  if (_failures.isNotEmpty) {
    throw TestFailure('${_failures.length} step(s) failed:\n${_failures.join('\n')}');
  }
}

/// A text field whose label or hint starts with [prefix] (labels that carry a count, e.g. "Quantity (max 62)").
Finder fieldStarting(String prefix, {int index = 0}) => find
    .byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          ((widget.decoration?.labelText ?? '').startsWith(prefix) ||
              (widget.decoration?.hintText ?? '').startsWith(prefix)),
    )
    .at(index);

/// Enters [value] in the field found by [finder].
Future<void> enter(WidgetTester tester, Finder finder, String value) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Taps the first widget whose text contains [part] (list cards show several lines in one widget).
Future<void> tapContaining(WidgetTester tester, String part, {int index = 0}) async {
  final finder = find.textContaining(part).at(index);
  await waitFor(tester, find.textContaining(part));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Prints every visible text, to discover labels on a screen while writing a step.
void dumpTexts(String where) {
  final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '').where((t) => t.isNotEmpty).toSet();
  debugPrint('TEXTS@$where: ${texts.join(' | ')}');
}
