import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFonts', () {
    test('constants are configured', () {
      expect(AppFonts.montserrat, equals('Montserrat'));
      expect(AppFonts.package, equals('core_ui'));
    });

    test('textStyle includes package and font family', () {
      final style = AppFonts.textStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
      expect(style.fontFamily, equals('packages/core_ui/Montserrat'));
      expect(style.fontSize, equals(14));
      expect(style.fontWeight, equals(FontWeight.w600));
    });

    test('createTextTheme creates complete TextTheme', () {
      final textTheme = AppFonts.createTextTheme(textColor: Colors.black);
      expect(
        textTheme.titleLarge?.fontFamily,
        equals('packages/core_ui/Montserrat'),
      );
    });
  });
}
