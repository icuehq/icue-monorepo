import 'package:icue_ui/src/widgets/icue_text_field.dart';
import 'package:flutter/material.dart';

/// The one dropdown of every form, styled like [IcueTextField]. Pass `onChanged: null` to disable it.
class IcueDropdown<T> extends StatelessWidget {
  const IcueDropdown({
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
    decoration: icueInputDecoration(
      label: label,
      hintText: hintText,
      helperText: helperText,
      icon: icon,
    ),
  );
}
