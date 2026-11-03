import 'package:flutter/material.dart';

/// Centralized font tokens and typography builders for icue apps.
abstract final class AppFonts {
  static const String montserrat = 'Montserrat';
  static const String package = 'core_ui';

  /// Generates a Montserrat [TextStyle] referencing the centralized `core_ui` package.
  static TextStyle textStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: montserrat,
      package: package,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }

  /// Creates a base [TextTheme] styled with Montserrat for use in any app's theme builder.
  static TextTheme createTextTheme({required Color textColor}) {
    final base = Typography.material2021().black.apply(
      fontFamily: montserrat,
      package: package,
      bodyColor: textColor,
      displayColor: textColor,
    );

    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontFamily: montserrat,
        package: package,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.35,
        fontFamily: montserrat,
        package: package,
      ),
    );
  }
}
