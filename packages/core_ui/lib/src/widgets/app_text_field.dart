import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _iconSize = 20.0;

/// The input decoration shared by [AppTextField] and `AppDropdown`: everything else comes from the app theme.
InputDecoration appInputDecoration({
  String? label,
  String? hintText,
  String? helperText,
  String? errorText,
  IconData? icon,
  Widget? suffixIcon,
  String? prefixText,
  String? suffixText,
  bool multiline = false,
}) => InputDecoration(
  alignLabelWithHint: multiline,
  counterText: '',
  errorMaxLines: 2,
  labelText: label,
  hintText: hintText,
  helperText: helperText,
  errorText: errorText,
  prefixText: prefixText,
  suffixText: suffixText,
  prefixIcon: icon == null ? null : Icon(icon, size: _iconSize),
  suffixIcon: suffixIcon,
);

/// The one text input of every form: label or hint, leading icon, validation and a password toggle.
///
/// Looks come from the app's `inputDecorationTheme`. Put a trailing `*` in [label] for required
/// fields and pass `requiredText` as [validator] to enforce it. Digit-only and decimal input is
/// opt-in through [inputFormatters].
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.icon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.onTap,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final IconData? icon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.obscureText;

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscure = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suffixIcon =
        widget.suffixIcon ??
        (widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: _iconSize,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null);
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _obscure,
      minLines: widget.minLines,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: appInputDecoration(
        label: widget.label,
        hintText: widget.hintText,
        helperText: widget.helperText,
        errorText: widget.errorText,
        icon: widget.icon,
        suffixIcon: suffixIcon,
        prefixText: widget.prefixText,
        suffixText: widget.suffixText,
        multiline: (widget.maxLines ?? 2) > 1,
      ),
    );
  }
}
