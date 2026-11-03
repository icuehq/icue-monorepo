import 'package:api_client/api_client.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:icueadmin/theme/brand_colors.dart';

/// Auto-picks a readable foreground for solid fills.
Color _onColor(Color c) =>
    c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

abstract final class AppTheme {
  /// Returns the appropriate theme for the active [ApiEnvironment] (Dev vs Prod).
  static ThemeData forEnvironment(ApiEnvironment environment) {
    return environment.isProd ? prodTheme() : devTheme();
  }

  /// Production theme (Teal/Emerald).
  static ThemeData prodTheme() => _buildTheme(
    primary: BrandColors.prodPrimary,
    primaryDark: BrandColors.prodPrimaryDark,
    secondary: BrandColors.prodSecondary,
  );

  /// Development theme (Deep Purple).
  static ThemeData devTheme() => _buildTheme(
    primary: BrandColors.devPrimary,
    primaryDark: BrandColors.devPrimaryDark,
    secondary: BrandColors.devSecondary,
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
      onSurface: BrandColors.text,
    );

    final baseTextTheme = AppFonts.createTextTheme(textColor: BrandColors.text);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );

    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      primaryColorDark: primaryDark,
      colorScheme: scheme,

      // Centralized Typography from core_ui
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
      dividerColor: BrandColors.divider,
      hintColor: BrandColors.hint,

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: buttonShape,
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          textStyle: AppFonts.textStyle(
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
          textStyle: AppFonts.textStyle(
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
          textStyle: AppFonts.textStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppFonts.textStyle(
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
        extendedTextStyle: AppFonts.textStyle(
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
        titleTextStyle: AppFonts.textStyle(
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
