import 'package:intl/intl.dart';

final _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

extension NumberFormatting on num {
  /// `₹1,23,456.00`: Indian rupees with lakh/crore grouping, for display.
  String toRupees() => _rupees.format(this);

  /// `1234.50`: two decimals with no symbol or grouping, for input fields, CSV and PDF cells.
  String toAmountText() => toStringAsFixed(2);

  /// `12` -> `12`, `12.5` -> `12.5`.
  String toQuantityText() => this == roundToDouble() ? '${toInt()}' : '$this';
}
