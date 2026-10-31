import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFonts', () {
    test('constants are configured', () {
      expect(AppFonts.montserrat, equals('Montserrat'));
      expect(AppFonts.package, equals('core_ui'));
    });

    test('textStyle includes package and font family', () {
      final style = AppFonts.textStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
      expect(style.fontFamily, equals('packages/core_ui/Montserrat'));
      expect(style.fontSize, equals(14));
      expect(style.fontWeight, equals(FontWeight.w600));
    });

    test('createTextTheme creates complete TextTheme', () {
      final textTheme = AppFonts.createTextTheme(textColor: Colors.black);
      expect(
        textTheme.titleLarge?.fontFamily,
        equals('packages/core_ui/Montserrat'),
      );
    });
  });

  group('AppFilterResult business logic', () {
    test('byDate formats label as DD/MM/YYYY', () {
      final date = DateTime(2025, 4, 15);
      final result = AppFilterResult.byDate(date);
      expect(result.mode, equals(AppFilterMode.byDate));
      expect(result.displayLabel, equals('15/04/2025'));
    });

    test('byMonth formats label as Month Year', () {
      final result = AppFilterResult.byMonth(month: 'September', year: '2025');
      expect(result.mode, equals(AppFilterMode.byMonth));
      expect(result.displayLabel, equals('September 2025'));
    });

    test('byRange formats label as Start - End date', () {
      final start = DateTime(2025);
      final end = DateTime(2025, 1, 31);
      final result = AppFilterResult.byRange(
        DateTimeRange(start: start, end: end),
      );
      expect(result.mode, equals(AppFilterMode.byRange));
      expect(result.displayLabel, equals('1/1/2025 - 31/1/2025'));
    });
  });

  group('DocumentItemData status calculation', () {
    test('isUploaded is true when fileUrl is present and non-empty', () {
      const doc = DocumentItemData(
        docType: 'License',
        title: 'Driver License',
        fileUrl: 'https://example.com/license.pdf',
      );
      expect(doc.isUploaded, isTrue);
    });

    test('isUploaded is false when fileUrl is empty or null', () {
      const doc = DocumentItemData(docType: 'License', title: 'Driver License');
      expect(doc.isUploaded, isFalse);
    });

    test('calculates expiration message correctly', () {
      final now = DateTime.now();
      final expiredDate = now.subtract(const Duration(days: 5));
      final docExpired = DocumentItemData(
        docType: 'Insurance',
        title: 'Vehicle Insurance',
        expiryDate: expiredDate,
      );
      expect(docExpired.expiryStatusMessage, contains('Expired'));

      final expiringSoonDate = now.add(const Duration(days: 10));
      final docExpiring = DocumentItemData(
        docType: 'Insurance',
        title: 'Vehicle Insurance',
        expiryDate: expiringSoonDate,
      );
      expect(docExpiring.expiryStatusMessage, contains('Expires in'));
    });
  });

  group('AppDateUtils', () {
    test('parses ISO8601 string', () {
      final parsed = AppDateUtils.tryParseDate('2025-05-20');
      expect(parsed, isNotNull);
      expect(parsed!.year, equals(2025));
      expect(parsed.month, equals(5));
      expect(parsed.day, equals(20));
    });

    test('parses DD-MM-YYYY string', () {
      final parsed = AppDateUtils.tryParseDate('15-08-2024');
      expect(parsed, isNotNull);
      expect(parsed!.year, equals(2024));
      expect(parsed.month, equals(8));
      expect(parsed.day, equals(15));
    });

    test('returns null for invalid or empty string', () {
      expect(AppDateUtils.tryParseDate(''), isNull);
      expect(AppDateUtils.tryParseDate(null), isNull);
      expect(AppDateUtils.tryParseDate('invalid-date'), isNull);
    });

    test('formats date as dd/MM/yyyy', () {
      final formatted = AppDateUtils.formatDate(DateTime(2025, 3, 7));
      expect(formatted, equals('07/03/2025'));
      expect(AppDateUtils.formatDate(null), equals('-'));
    });

    test('calculates checkExpiryStatus correctly', () {
      final now = DateTime.now();
      final expired = AppDateUtils.checkExpiryStatus(
        'License',
        now.subtract(const Duration(days: 3)),
      );
      expect(expired, contains('expired 3 days ago'));

      final today = AppDateUtils.checkExpiryStatus('License', now);
      expect(today, contains('expires today'));

      final soon = AppDateUtils.checkExpiryStatus(
        'License',
        now.add(const Duration(days: 15)),
      );
      expect(soon, contains('will expire in 15 days'));

      final safe = AppDateUtils.checkExpiryStatus(
        'License',
        now.add(const Duration(days: 60)),
      );
      expect(safe, isNull);
    });
  });

  group('AppCurrencyUtils', () {
    test('formats INR with lakh grouping', () {
      expect(AppCurrencyUtils.formatInr(1234567.5), '₹12,34,567.50');
      expect(AppCurrencyUtils.formatInr('500'), '₹500.00');
      expect(AppCurrencyUtils.formatInr(null), '-');
      expect(AppCurrencyUtils.formatInr('abc'), '-');
    });
  });
}
