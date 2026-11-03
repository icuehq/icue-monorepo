import 'package:admin_ui/admin_ui.dart';
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
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    readOnly: true,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
    ),
    validator: required ? requiredText : null,
    onTap: () async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(controller.text) ?? now,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 15),
      );
      if (date != null) {
        controller.text = date.toIso8601String().substring(0, 10);
      }
    },
  );
}
