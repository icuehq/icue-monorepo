import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isNewerVersion compares dotted versions numerically', () {
    expect(AppUpdateService.isNewerVersion('1.0.10', '1.0.9'), isTrue);
    expect(AppUpdateService.isNewerVersion('1.1', '1.0.5'), isTrue);
    expect(AppUpdateService.isNewerVersion('1.0', '1.0.0'), isFalse);
    expect(AppUpdateService.isNewerVersion('1.0.0', '1.0.1'), isFalse);
  });
}
