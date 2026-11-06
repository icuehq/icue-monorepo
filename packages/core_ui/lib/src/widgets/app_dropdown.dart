import 'package:core_ui/src/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// The one dropdown of every form, styled like [AppTextField]. Pass `onChanged: null` to disable it.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.hintText,
    this.helperText,
    this.icon,
    this.validator,
    super.key,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String? label;
  final String? hintText;
  final String? helperText;
  final IconData? icon;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    items: items,
    onChanged: onChanged,
    validator: validator,
    isExpanded: true,
    decoration: appInputDecoration(
      label: label,
      hintText: hintText,
      helperText: helperText,
      icon: icon,
    ),
  );
}
