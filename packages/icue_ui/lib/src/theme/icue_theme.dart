import 'package:icue_ui/src/theme/icue_brand_colors.dart';
import 'package:icue_ui/src/theme/icue_fonts.dart';
import 'package:flutter/material.dart';

/// Auto-picks a readable foreground for solid fills.
Color _onColor(Color c) =>
    c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

abstract final class IcueTheme {
  /// Prod (teal) or dev (purple) theme.
  static ThemeData forEnvironment({required bool isProd}) =>
      isProd ? prodTheme() : devTheme();

  /// Production theme (Teal/Emerald).
  static ThemeData prodTheme() => _buildTheme(
    primary: IcueBrandColors.prodPrimary,
    primaryDark: IcueBrandColors.prodPrimaryDark,
    secondary: IcueBrandColors.prodSecondary,
  );

  /// Development theme (Deep Purple).
  static ThemeData devTheme() => _buildTheme(
    primary: IcueBrandColors.devPrimary,
    primaryDark: IcueBrandColors.devPrimaryDark,
    secondary: IcueBrandColors.devSecondary,
  );

  /// Core Theme Builder (Material 3–first).
  static ThemeData _buildTheme({
    required Color primary,
    required Color primaryDark,
    required Color secondary,
  }) {
    final scheme = ColorScheme.light(
      primary: primary,
      onPrimary: _onColor(primary),
      primaryContainer: primaryDark,
      onPrimaryContainer: _onColor(primaryDark),
      secondary: secondary,
      onSecondary: _onColor(secondary),
      onSurface: IcueBrandColors.text,
    );

    final baseTextTheme = IcueFonts.createTextTheme(
      textColor: IcueBrandColors.text,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );

    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      primaryColorDark: primaryDark,
      colorScheme: scheme,

      // Centralized Typography from icue_ui
      textTheme: baseTextTheme,

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
        ),
        iconTheme: IconThemeData(color: _onColor(primary)),
      ),

      // Dividers & hints
      dividerColor: IcueBrandColors.divider,
      hintColor: IcueBrandColors.hint,

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: buttonShape,
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          textStyle: IcueFonts.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: buttonShape,
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primaryContainer,
          textStyle: IcueFonts.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: buttonShape,
          side: BorderSide(color: scheme.primary, width: 2),
          foregroundColor: scheme.primary,
          textStyle: IcueFonts.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: IcueFonts.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        extendedTextStyle: IcueFonts.textStyle(
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
        hintStyle: const TextStyle(color: IcueBrandColors.hint),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        labelStyle: baseTextTheme.labelLarge,
        backgroundColor: Colors.grey.shade100,
        selectedColor: scheme.secondary.withValues(alpha: 0.15),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Alert Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        insetPadding: const EdgeInsets.all(16),
        titleTextStyle: IcueFonts.textStyle(
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
}
