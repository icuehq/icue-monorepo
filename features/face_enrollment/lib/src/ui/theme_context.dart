import 'package:flutter/material.dart';

extension ThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
