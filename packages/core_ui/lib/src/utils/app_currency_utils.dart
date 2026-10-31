import 'package:intl/intl.dart';

abstract final class AppCurrencyUtils {
  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Formats as Indian rupees with lakh/crore grouping: ₹1,23,456.00.
  /// Accepts a num or numeric String; returns '-' for null/unparseable input.
  static String formatInr(Object? amount) {
    final n = amount is num ? amount : num.tryParse('${amount ?? ''}'.trim());
    return n == null ? '-' : _inr.format(n);
  }
}
