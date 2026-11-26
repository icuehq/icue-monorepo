import 'package:flutter/material.dart';
import 'package:icue_ui/src/widgets/icue_text_field.dart';

/// Pick items by typing: chosen ones show as removable chips, the rest are
/// suggested (all of them while the box is empty), built on [RawAutocomplete].
/// With `multiple: false` picking an item replaces the current one; with
/// `showChips: false` the caller shows the picked items itself.
class IcueMultiAutocomplete<T extends Object> extends StatefulWidget {
  const IcueMultiAutocomplete({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.multiple = true,
    this.showChips = true,
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
  final bool showChips;
  final String? label;
  final String? hintText;
  final String? helperText;
  final IconData? icon;

  @override
  State<IcueMultiAutocomplete<T>> createState() =>
      _IcueMultiAutocompleteState<T>();
}

class _IcueMultiAutocompleteState<T extends Object>
    extends State<IcueMultiAutocomplete<T>> {
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _triggerOptions();
    }
  }

  void _triggerOptions() {
    _controller.value = TextEditingValue(
      text: _controller.text,
      selection: _controller.selection,
    );
  }

  @override
  void didUpdateWidget(IcueMultiAutocomplete<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options ||
        oldWidget.options.length != widget.options.length) {
      if (_focusNode.hasFocus) {
        _triggerOptions();
      }
    }
  }

  Iterable<T> _matches(String text) {
    final query = text.trim().toLowerCase();
    return widget.options.where(
      (option) => widget.labelOf(option).toLowerCase().contains(query),
    );
  }

  void _pick(T option) {
    widget.onChanged(
      !widget.multiple
          ? [option]
          : widget.selected.contains(option)
          ? [
              for (final other in widget.selected)
                if (other != option) other,
            ]
          : [...widget.selected, option],
    );
    if (_focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RawAutocomplete<T>(
      key: ValueKey(widget.options.length),
      focusNode: _focusNode,
      textEditingController: _controller,
      // Empty so a picked item leaves the box clear; the chip shows it.
      displayStringForOption: (_) => '',
      optionsBuilder: (value) => _matches(value.text),
      onSelected: _pick,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              onTap: _triggerOptions,
              decoration: icueInputDecoration(
                label: widget.label,
                hintText: widget.hintText,
                helperText: widget.helperText,
                icon: widget.icon,
                suffixIcon: IconButton(
                  tooltip: 'Show options',
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  onPressed: () {
                    focusNode.requestFocus();
                    _triggerOptions();
                  },
                ),
              ),
              // Enter picks the first match.
              onSubmitted: (_) {
                final match = _matches(controller.text)
                    .where(
                      (option) =>
                          !widget.multiple || !widget.selected.contains(option),
                    )
                    .firstOrNull;
                if (match != null) {
                  controller.clear();
                  _pick(match);
                  focusNode.requestFocus();
                }
              },
            ),
            if (widget.showChips && widget.selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final item in widget.selected)
                      InputChip(
                        label: Text(widget.labelOf(item)),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => widget.onChanged([
                          for (final other in widget.selected)
                            if (other != item) other,
                        ]),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
      optionsViewBuilder: (context, onSelected, matches) => Align(
        alignment: Alignment.topLeft,
        // Taps in the menu count as inside the field, so web/desktop's
        // tap-outside unfocus does not close the menu on every pick.
        child: TextFieldTapRegion(
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
                    if (widget.multiple)
                      // Bypasses onSelected, which would close the menu; ExcludeFocus
                      // keeps the text field focused so the menu stays open.
                      ExcludeFocus(
                        child: CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: widget.selected.contains(option),
                          title: Text(widget.labelOf(option)),
                          onChanged: (_) => _pick(option),
                        ),
                      )
                    else
                      ListTile(
                        dense: true,
                        selected: widget.selected.contains(option),
                        title: Text(widget.labelOf(option)),
                        onTap: () => onSelected(option),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
