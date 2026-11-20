import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/icue_sdk.dart';

void main() {
  test('IcueSdk.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(IcueSdk.version, declared);
  });

  test('isBeta is true only for prerelease versions', () {
    expect(IcueSdk.isBeta, IcueSdk.version.contains('-beta.'));
  });
}
