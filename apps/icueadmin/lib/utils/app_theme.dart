import 'package:flutter/material.dart';

/// ------- Brand Tokens -------
class BrandColors {
  // Dev
  static const devPrimary = Color(0xFF570987);

  static const devPrimaryDark = Color(0xFF570987);
  static const devSecondary = Color(0xFFF9C02D);
  static const divider = Color(0xFF808080);
  static const hint = Color(0xFF808080);
  // Prod
  static const prodPrimary = Color(0xFF13967E);

  static const prodPrimaryDark = Color.fromARGB(255, 9, 98, 82);
  static const prodSecondary = Color(0xFFF9C02D);
  static const text = Color(0xFF1F1D31);
}

/// Auto-picks a readable foreground for solid fills.
/// (Simple heuristic: light on dark, dark on light.)
Color _onColor(Color c) =>
    c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// ------- Public API: Themes -------
ThemeData prodTheme() => _buildTheme(
  primary: BrandColors.prodPrimary,
  primaryDark: BrandColors.prodPrimaryDark,
  secondary: BrandColors.prodSecondary,
  fontFamily: 'Montserrat',
);

ThemeData devTheme() => _buildTheme(
  primary: BrandColors.devPrimary,
  primaryDark: BrandColors.devPrimaryDark,
  secondary: BrandColors.devSecondary,
  fontFamily: 'Montserrat',
);

/// ------- Core Theme Builder (Material 3–first) -------
ThemeData _buildTheme({
  required Color primary,
  required Color primaryDark,
  required Color secondary,
  String? fontFamily,
}) {
  final scheme = ColorScheme.light(
    primary: primary,
    onPrimary: _onColor(primary),
    primaryContainer: primaryDark,
    onPrimaryContainer: _onColor(primaryDark),
    secondary: secondary,
    onSecondary: _onColor(secondary),
    onSurface: BrandColors.text,
  );

  final baseTextTheme = Typography.material2021().black.apply(
    fontFamily: fontFamily,
    bodyColor: BrandColors.text,
    displayColor: BrandColors.text,
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  );

  return ThemeData(
    useMaterial3: true,
    primaryColor: primary,
    primaryColorDark: primaryDark,
    colorScheme: scheme,
    // Typography
    textTheme: baseTextTheme.copyWith(
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontFamily: fontFamily,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        height: 1.35,
        fontFamily: fontFamily,
      ),
    ),
    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: _onColor(primary),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: baseTextTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _onColor(primary),
        fontFamily: fontFamily,
      ),
      iconTheme: IconThemeData(color: _onColor(primary)),
    ),
    // Dividers & hints
    dividerColor: BrandColors.divider,
    hintColor: BrandColors.hint,

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: buttonShape,
        foregroundColor: scheme.onPrimary,
        backgroundColor: scheme.primary,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // minimumSize: const Size(double.infinity, 48),
        shape: buttonShape,
        foregroundColor: scheme.onPrimary,
        backgroundColor: scheme.primaryContainer,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        // minimumSize: const Size(double.infinity, 48),
        shape: buttonShape,
        side: BorderSide(color: scheme.primary, width: 2),
        foregroundColor: scheme.primary,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    ),

    // FAB
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryDark,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      extendedTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Cards
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.grey.shade50,
      hintStyle: const TextStyle(color: BrandColors.hint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    // Chips (useful if you have filters/pills)
    chipTheme: ChipThemeData(
      labelStyle: baseTextTheme.labelLarge,
      backgroundColor: Colors.grey.shade100,
      selectedColor: scheme.secondary.withValues(alpha: .15),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Alert Dialog
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.all(16),
      titleTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black,
        fontSize: 18,
      ),
    ),

    // Icon defaults
    iconTheme: IconThemeData(color: scheme.onSurface),
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: scheme.surface,
  );
}
