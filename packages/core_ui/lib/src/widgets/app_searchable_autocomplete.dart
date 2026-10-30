import 'dart:async';
import 'package:flutter/material.dart';

/// Generic, accessible autocomplete input field for searching and picking items
/// such as vehicles, drivers, or students.
///
/// Handles search filtering, keyboard unfocus, clear action, and clean Material styling.
class AppSearchableAutocomplete<T extends Object> extends StatefulWidget {
  const AppSearchableAutocomplete({
    super.key,
    required this.optionsBuilder,
    required this.displayStringForOption,
    required this.onSelected,
    this.initialSelection,
    this.label,
    this.hintText,
    this.isRequired = false,
    this.onCleared,
    this.validator,
    this.debounceDuration = const Duration(milliseconds: 250),
    this.enabled = true,
    this.maxOptionsHeight = 250,
  });

  /// Function that returns candidate options matching the user's text query.
  final FutureOr<Iterable<T>> Function(TextEditingValue textEditingValue) optionsBuilder;

  /// String representation of an option shown in text field and option rows.
  final String Function(T option) displayStringForOption;

  /// Callback when an item is chosen.
  final ValueChanged<T> onSelected;

  /// Currently selected item (if any) to populate the field initially.
  final T? initialSelection;

  /// Optional label text displayed above or inside the input.
  final String? label;

  /// Placeholder hint text.
  final String? hintText;

  /// Whether to display a red asterisk indicating mandatory field.
  final bool isRequired;

  /// Callback triggered when the selection is cleared via the trailing cross icon.
  final VoidCallback? onCleared;

  /// Custom validation logic.
  final FormFieldValidator<String>? validator;

  /// Search input debounce duration.
  final Duration debounceDuration;

  /// Whether the input is active.
  final bool enabled;

  /// Maximum height for the options overlay popup.
  final double maxOptionsHeight;

  @override
  State<AppSearchableAutocomplete<T>> createState() => _AppSearchableAutocompleteState<T>();
}

class _AppSearchableAutocompleteState<T extends Object> extends State<AppSearchableAutocomplete<T>> {
  FocusNode? _focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text.rich(
            TextSpan(
              text: widget.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              children: [
                if (widget.isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        RawAutocomplete<T>(
          displayStringForOption: widget.displayStringForOption,
          optionsBuilder: widget.optionsBuilder,
          onSelected: (option) {
            widget.onSelected(option);
            _focusNode?.unfocus();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _focusNode = focusNode;

            if (widget.initialSelection != null && controller.text.isEmpty) {
              controller.text = widget.displayStringForOption(widget.initialSelection!);
            }

            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.isNotEmpty;

                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: widget.enabled,
                  validator: widget.validator ??
                      (widget.isRequired
                          ? (val) => (val == null || val.trim().isEmpty)
                              ? 'This field is required'
                              : null
                          : null),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    suffixIcon: hasText && widget.enabled
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              controller.clear();
                              widget.onCleared?.call();
                            },
                          )
                        : const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ),
                  onFieldSubmitted: (text) => onFieldSubmitted(),
                );
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final optionList = options.toList();
            if (optionList.isEmpty) return const SizedBox.shrink();

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: theme.cardColor,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: widget.maxOptionsHeight,
                    maxWidth: MediaQuery.of(context).size.width - 32,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: optionList.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = optionList[index];
                      final title = widget.displayStringForOption(option);

                      return ListTile(
                        dense: true,
                        title: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
