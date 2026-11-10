import 'package:flutter/services.dart';

/// Quantities: up to 9 digits and 3 decimals.
final quantityFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,3})?$')),
];

/// Money amounts: up to 9 digits and 2 decimals.
final amountFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?$')),
];

/// Required quantity, greater than zero.
String? validateQuantity(String? text) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return 'Enter a quantity';
  final number = double.tryParse(value);
  if (number == null) return 'Enter a valid number';
  if (number <= 0) return 'Must be greater than 0';
  return null;
}

/// Optional amount, zero or more.
String? validateAmount(String? text) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return null;
  final number = double.tryParse(value);
  if (number == null) return 'Enter a valid amount';
  if (number < 0) return 'Cannot be negative';
  return null;
}

/// Required free text up to [max] characters.
String? validateRequiredText(String? text, {int max = 50}) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return 'Required';
  if (value.length > max) return 'At most $max characters';
  return null;
}
