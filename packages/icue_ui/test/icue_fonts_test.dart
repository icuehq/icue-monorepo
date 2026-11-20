import 'package:icue_ui/icue_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IcueFonts', () {
    test('constants are configured', () {
      expect(IcueFonts.montserrat, equals('Montserrat'));
      expect(IcueFonts.package, equals('icue_ui'));
    });

    test('textStyle includes package and font family', () {
      final style = IcueFonts.textStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
      expect(style.fontFamily, equals('packages/icue_ui/Montserrat'));
      expect(style.fontSize, equals(14));
      expect(style.fontWeight, equals(FontWeight.w600));
    });

    test('createTextTheme creates complete TextTheme', () {
      final textTheme = IcueFonts.createTextTheme(textColor: Colors.black);
      expect(
        textTheme.titleLarge?.fontFamily,
        equals('packages/icue_ui/Montserrat'),
      );
    });
  });

  group('IcueFilterResult business logic', () {
    test('byDate formats label as DD/MM/YYYY', () {
      final date = DateTime(2025, 4, 15);
      final result = IcueFilterResult.byDate(date);
      expect(result.mode, equals(IcueFilterMode.byDate));
      expect(result.displayLabel, equals('15/04/2025'));
    });

    test('byMonth formats label as Month Year', () {
      final result = IcueFilterResult.byMonth(month: 'September', year: '2025');
      expect(result.mode, equals(IcueFilterMode.byMonth));
      expect(result.displayLabel, equals('September 2025'));
    });

    test('byRange formats label as Start - End date', () {
      final start = DateTime(2025);
      final end = DateTime(2025, 1, 31);
      final result = IcueFilterResult.byRange(
        DateTimeRange(start: start, end: end),
      );
      expect(result.mode, equals(IcueFilterMode.byRange));
      expect(result.displayLabel, equals('01/01/2025 - 31/01/2025'));
    });
  });

  group('IcueDocumentItemData status calculation', () {
    test('isUploaded is true when fileUrl is present and non-empty', () {
      const doc = IcueDocumentItemData(
        docType: 'License',
        title: 'Driver License',
        fileUrl: 'https://example.com/license.pdf',
      );
      expect(doc.isUploaded, isTrue);
    });

    test('isUploaded is false when fileUrl is empty or null', () {
      const doc = IcueDocumentItemData(
        docType: 'License',
        title: 'Driver License',
      );
      expect(doc.isUploaded, isFalse);
    });

    test('calculates expiration message correctly', () {
      final now = DateTime.now();
      final expiredDate = now.subtract(const Duration(days: 5));
      final docExpired = IcueDocumentItemData(
        docType: 'Insurance',
        title: 'Vehicle Insurance',
        expiryDate: expiredDate,
      );
      expect(docExpired.expiryStatusMessage, contains('Expired'));

      final expiringSoonDate = now.add(const Duration(days: 10));
      final docExpiring = IcueDocumentItemData(
        docType: 'Insurance',
        title: 'Vehicle Insurance',
        expiryDate: expiringSoonDate,
      );
      expect(docExpiring.expiryStatusMessage, contains('Expires in'));
    });
  });
}
