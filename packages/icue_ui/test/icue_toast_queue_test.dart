import 'package:flutter_test/flutter_test.dart';
import 'package:icue_ui/icue_ui.dart';

void main() {
  test('identical message replaces the existing toast', () {
    final queue = IcueToastQueue()
      ..add(IcueToastSeverity.error, 'Failed')
      ..add(IcueToastSeverity.error, 'Failed');
    expect(queue.items, hasLength(1));
  });

  test('keeps at most three, dropping the oldest', () {
    final queue = IcueToastQueue();
    for (final message in ['a', 'b', 'c', 'd']) {
      queue.add(IcueToastSeverity.info, message);
    }
    expect(queue.items.map((item) => item.message), ['b', 'c', 'd']);
  });

  test('dismiss removes only that toast', () {
    final queue = IcueToastQueue()
      ..add(IcueToastSeverity.info, 'a')
      ..add(IcueToastSeverity.warning, 'b');
    queue.dismiss(queue.items.first.id);
    expect(queue.items.single.message, 'b');
  });
}
