import 'package:icue_ui/src/utils/icue_date_time_formatting.dart';
import 'package:flutter/material.dart';

/// Read-only date field with a picker. [controller] keeps the stored `yyyy-MM-dd` value;
/// the field shows it the Indian way (`05/03/2025`).
class IcueDateField extends StatelessWidget {
  const IcueDateField({
    super.key,
    required this.controller,
    required this.label,
    required this.firstDate,
    required this.lastDate,
    this.initialDate,
    this.validator,
    this.prefixIcon,
    this.clearable = false,
  });

  final TextEditingController controller;
  final String label;
  final DateTime firstDate;
  final DateTime lastDate;

  /// Picker start when the field is empty; defaults to today.
  final DateTime? initialDate;

  /// Receives the stored `yyyy-MM-dd` value.
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;

  /// Shows a clear button once a date is picked.
  final bool clearable;

  Future<void> _pick(BuildContext context, FormFieldState<String> field) async {
    final current =
        controller.text.toDateOrNull() ?? initialDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: current.isBefore(firstDate)
          ? firstDate
          : current.isAfter(lastDate)
          ? lastDate
          : current,
    );
    if (date == null) return;
    controller.text = date.toApiDate();
    field.didChange(controller.text);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FormField<String>(
      validator: validator == null ? null : (_) => validator!(controller.text),
      builder: (field) => InkWell(
        onTap: () => _pick(context, field),
        child: InputDecorator(
          isEmpty: controller.text.isEmpty,
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            prefixIcon: prefixIcon,
            suffixIcon: clearable && controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: controller.clear,
                  )
                : const Icon(Icons.event_rounded),
          ),
          child: Text(controller.text.toDisplayDay()),
        ),
      ),
    ),
  );
}
