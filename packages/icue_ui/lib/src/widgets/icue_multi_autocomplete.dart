import 'package:icue_ui/src/widgets/icue_text_field.dart';
import 'package:flutter/material.dart';

/// Pick items by typing: chosen ones show as removable chips, the rest are
/// suggested (all of them while the box is empty), built on [RawAutocomplete].
/// With `multiple: false` picking an item replaces the current one.
class IcueMultiAutocomplete<T extends Object> extends StatelessWidget {
  const IcueMultiAutocomplete({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.multiple = true,
    this.label,
    this.hintText,
    this.helperText,
    this.icon,
    super.key,
  });

  final List<T> options;
  final List<T> selected;
  final String Function(T option) labelOf;
  final ValueChanged<List<T>> onChanged;
  final bool multiple;
  final String? label;
  final String? hintText;
  final String? helperText;
  final IconData? icon;

  Iterable<T> _matches(String text) {
    final query = text.trim().toLowerCase();
    return options.where(
      (option) =>
          (!multiple || !selected.contains(option)) &&
          labelOf(option).toLowerCase().contains(query),
    );
  }

  void _pick(T option) =>
      onChanged(multiple ? [...selected, option] : [option]);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RawAutocomplete<T>(
      // Empty so a picked item leaves the box clear; the chip shows it.
      displayStringForOption: (_) => '',
      optionsBuilder: (value) => _matches(value.text),
      onSelected: _pick,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration:
              icueInputDecoration(
                label: label,
                hintText: selected.isEmpty ? hintText : null,
                helperText: helperText,
                icon: icon,
              ).copyWith(
                // The text is empty, so the label would sit over the chips.
                floatingLabelBehavior: selected.isEmpty
                    ? FloatingLabelBehavior.auto
                    : FloatingLabelBehavior.always,
                prefix: selected.isEmpty
                    ? null
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final item in selected)
                            InputChip(
                              label: Text(labelOf(item)),
                              visualDensity: VisualDensity.compact,
                              onDeleted: () => onChanged([
                                for (final other in selected)
                                  if (other != item) other,
                              ]),
                            ),
                        ],
                      ),
              ),
          // Enter picks the first match.
          onSubmitted: (_) {
            final match = _matches(controller.text)
                .where((option) => !multiple || !selected.contains(option))
                .firstOrNull;
            if (match != null) {
              controller.clear();
              _pick(match);
              focusNode.requestFocus();
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, matches) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 240,
              maxWidth: constraints.maxWidth,
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in matches)
                  if (multiple)
                    // Bypasses onSelected, which would close the menu; ExcludeFocus
                    // keeps the text field focused so the menu stays open.
                    ExcludeFocus(
                      child: CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: selected.contains(option),
                        title: Text(labelOf(option)),
                        onChanged: (_) => _pick(option),
                      ),
                    )
                  else
                    ListTile(
                      dense: true,
                      selected: selected.contains(option),
                      title: Text(labelOf(option)),
                      onTap: () => onSelected(option),
                    ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
