import 'package:icue_ui/icue_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('numbers', () {
    test('rupees use lakh grouping; amount text stays plain', () {
      expect(1234567.5.toRupees(), '₹12,34,567.50');
      expect(1234567.5.toAmountText(), '1234567.50');
    });

    test('quantities drop a trailing .0', () {
      expect(7.toQuantityText(), '7');
      expect(7.0.toQuantityText(), '7');
      expect(2.5.toQuantityText(), '2.5');
    });
  });

  group('date formats', () {
    final date = DateTime(2025, 3, 5, 14, 30, 5);

    test('cover every display and API shape', () {
      expect(date.toApiDate(), '2025-03-05');
      expect(date.toUsDate(), '03/05/2025');
      expect(date.toNumericDate(), '05/03/2025');
      expect(date.toNumericDateTime(), '05/03/2025, 02:30 PM');
      expect(date.toDisplayDate(), '05 Mar 2025');
      expect(date.toDisplayDateTime(), '05 Mar 2025, 02:30 PM');
      expect(date.toTime12(), '02:30 PM');
      expect(date.toTime24(), '14:30:05');
      expect(DateTime(2025, 1, 1, 9, 5).toHourMinute(), '9:05');
    });

    test('India time is UTC +5:30 whatever the device zone', () {
      final indian = DateTime.utc(2026, 3, 31, 20).toIndianTime();
      expect(indian.toApiDate(), '2026-04-01');
      expect(indian.toTime24(), '01:30:00');
    });

    test('financial year turns over in April', () {
      expect(DateTime(2026, 3, 31).financialYear, '2025-26');
      expect(DateTime(2026, 4).financialYear, '2026-27');
      expect(DateTime(2099, 12).financialYear, '2099-00');
    });

    test('expiry status within 30 days', () {
      final today = DateTime.now();
      String? status(int days) =>
          today.add(Duration(days: days)).expiryStatus('License');
      expect(status(-3), 'License expired 3 days ago');
      expect(status(0), 'License expires today');
      expect(status(15), 'License will expire in 15 days');
      expect(status(60), isNull);
    });
  });

  group('date parsing', () {
    test('reads ISO, day-first and year-first strings', () {
      expect('2025-05-20'.toDateOrNull(), DateTime(2025, 5, 20));
      expect('15-08-2024'.toDateOrNull(), DateTime(2024, 8, 15));
      expect('15/08/2024'.toDateOrNull(), DateTime(2024, 8, 15));
      expect('2024/08/15'.toDateOrNull(), DateTime(2024, 8, 15));
    });

    test('returns null for blank, invalid or impossible dates', () {
      expect(null.toDateOrNull(), isNull);
      expect('  '.toDateOrNull(), isNull);
      expect('invalid-date'.toDateOrNull(), isNull);
      expect('08-15-2024'.toDateOrNull(), isNull);
    });

    test('stored day and time strings display the Indian way', () {
      expect('2025-03-05'.toDisplayDay(), '05/03/2025');
      expect('05-03-2025'.toDisplayDay(), '05/03/2025');
      expect(null.toDisplayDay(), '');
      expect('soon'.toDisplayDay(), 'soon');
      expect('14:30'.toDisplayTime(), '02:30 PM');
      expect('09:05:59'.toDisplayTime(), '09:05 AM');
      expect('2:30 PM'.toDisplayTime(), '2:30 PM');
      expect(null.toDisplayTime(), '');
    });
  });
}
