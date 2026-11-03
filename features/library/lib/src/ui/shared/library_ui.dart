import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Read-only field that opens a date picker; the value is `yyyy-MM-dd`.
class LibraryDateField extends StatelessWidget {
  const LibraryDateField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AppDateField(
      controller: controller,
      label: required ? '$label *' : label,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
      validator: required ? requiredText : null,
    );
  }
}
