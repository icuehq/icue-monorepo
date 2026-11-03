import 'package:flutter/material.dart';

/// Brand color tokens for iCue Admin.
abstract final class BrandColors {
  // Dev palette (Purple & Gold)
  static const Color devPrimary = Color(0xFF570987);
  static const Color devPrimaryDark = Color(0xFF570987);
  static const Color devSecondary = Color(0xFFF9C02D);

  // Prod palette (Teal & Gold)
  static const Color prodPrimary = Color(0xFF13967E);
  static const Color prodPrimaryDark = Color.fromARGB(255, 9, 98, 82);
  static const Color prodSecondary = Color(0xFFF9C02D);

  // Shared neutral tokens
  static const Color text = Color(0xFF1F1D31);
  static const Color divider = Color(0xFF808080);
  static const Color hint = Color(0xFF808080);
}
