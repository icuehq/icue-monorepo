import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/utils/app_date_utils.dart';

void main() {
  group('AppDateTimeExtension & AppDateUtils Tests', () {
    test('toIst correctly converts UTC time to IST (UTC+5:30)', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8, 14, 30); // 08:14:30 UTC
      final istTime = utcTime.toIst();

      expect(istTime.year, equals(2026));
      expect(istTime.month, equals(9));
      expect(istTime.day, equals(2));
      expect(istTime.hour, equals(13)); // 8 + 5 = 13
      expect(istTime.minute, equals(44)); // 14 + 30 = 44
      expect(istTime.second, equals(30));
    });

    test('formattedDate formats date as dd-MM-yyyy in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8);
      expect(utcTime.formattedDate(), equals('02-09-2026'));

      DateTime? nullDate;
      expect(nullDate.formattedDate(), equals('-'));
      expect(nullDate.formattedDate(fallback: 'N/A'), equals('N/A'));
    });

    test('formattedDateSlash formats date as dd/MM/yyyy in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8);
      expect(utcTime.formattedDateSlash(), equals('02/09/2026'));
    });

    test('formattedFullDate formats date as dd-MMM-yyyy in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8);
      expect(utcTime.formattedFullDate(), equals('02-Sep-2026'));
    });

    test('formattedDayDate formats date as EEE, dd MMM yyyy in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8);
      expect(utcTime.formattedDayDate(), equals('Wed, 02 Sep 2026'));
    });

    test('formattedTime formats 12-hour time with AM/PM in IST', () {
      final morningUtc = DateTime.utc(2026, 9, 2, 4, 30); // 10:00 AM IST
      expect(morningUtc.formattedTime(), equals('10:00 AM'));

      final afternoonUtc = DateTime.utc(2026, 9, 2, 8, 15); // 01:45 PM IST
      expect(afternoonUtc.formattedTime(), equals('01:45 PM'));
    });

    test('formattedTimeWithSecs formats time with seconds in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8, 15, 45); // 01:45:45 PM IST
      expect(utcTime.formattedTimeWithSecs(), equals('01:45:45 PM'));
    });

    test('formattedAttendanceTime formats 24-hour time HH:mm in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8, 15); // 13:45 IST
      expect(utcTime.formattedAttendanceTime(), equals('13:45'));
    });

    test('formattedDateTime formats as dd-MM-yyyy, hh:mm a in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8, 15);
      expect(utcTime.formattedDateTime(), equals('02-09-2026, 01:45 PM'));
    });

    test('formattedFullDateTime formats as dd-MMM-yyyy hh:mm a in IST', () {
      final utcTime = DateTime.utc(2026, 9, 2, 8, 15);
      expect(utcTime.formattedFullDateTime(), equals('02-Sep-2026 01:45 PM'));
    });

    test('formattedGatePassDate preserves MM/dd/yyyy for API calls', () {
      final date = DateTime(2026, 9, 2);
      expect(date.formattedGatePassDate(), equals('09/02/2026'));
    });
  });

  group('AppDateStringConverter on String? Tests', () {
    test('toDate and toIstDateTime parses various string formats', () {
      expect(
        '2026-09-02T08:15:00Z'.toIstDateTime()?.hour,
        equals(13),
      ); // UTC to IST
      expect('2026-09-02T08:15:00Z'.toDate()?.isUtc, isTrue);
      expect('02-09-2026'.toDate()?.day, equals(2));
      expect('02-09-2026'.toDate()?.month, equals(9));
      expect('09/02/2026'.toDate()?.month, equals(9));
      expect('09/02/2026'.toDate()?.day, equals(2));
      expect('2026-09-02'.toDate()?.year, equals(2026));
      expect(''.toDate(), isNull);
      expect(null.toDate(), isNull);
    });

    test('formatAsIndianDate directly formats string to dd-MM-yyyy', () {
      expect('2026-09-02T08:15:00Z'.formatAsIndianDate(), equals('02-09-2026'));
      expect('09/02/2026'.formatAsIndianDate(), equals('02-09-2026'));
      expect('2026-09-02'.formatAsIndianDate(), equals('02-09-2026'));
      expect(''.formatAsIndianDate(), equals('-'));
      expect(null.formatAsIndianDate(), equals('-'));
      expect(null.formatAsIndianDate(fallback: 'N/A'), equals('N/A'));
    });

    test('formatAsIndianTime directly formats string to 12-hour hh:mm a', () {
      expect('13:45:00'.formatAsIndianTime(), equals('01:45 PM'));
      expect('13:45'.formatAsIndianTime(), equals('01:45 PM'));
      expect('09:30:00'.formatAsIndianTime(), equals('09:30 AM'));
      expect(''.formatAsIndianTime(), equals('-'));
      expect(null.formatAsIndianTime(), equals('-'));
      expect(null.formatAsIndianTime(fallback: 'N/A'), equals('N/A'));
    });

    test('formatAsIndianDateTime formats string to dd-MM-yyyy, hh:mm a', () {
      expect(
        '2026-09-02T08:15:00Z'.formatAsIndianDateTime(),
        equals('02-09-2026, 01:45 PM'),
      );
      expect(''.formatAsIndianDateTime(), equals('-'));
      expect(null.formatAsIndianDateTime(), equals('-'));
      expect(null.formatAsIndianDateTime(fallback: 'N/A'), equals('N/A'));
    });

    test(
      'formatAsIndianFullDateTime formats string to dd-MMM-yyyy hh:mm a',
      () {
        expect(
          '2026-09-02T08:15:00Z'.formatAsIndianFullDateTime(),
          equals('02-Sep-2026 01:45 PM'),
        );
        expect(
          '02-09-2026 13:45:00'.formatAsIndianFullDateTime(),
          equals('02-Sep-2026 01:45 PM'),
        );
      },
    );

    test('formatAsIndianFullDate formats string to dd-MMM-yyyy', () {
      expect('02-09-2026'.formatAsIndianFullDate(), equals('02-Sep-2026'));
      expect('2026-09-02'.formatAsIndianFullDate(), equals('02-Sep-2026'));
      expect('09/02/2026'.formatAsIndianFullDate(), equals('02-Sep-2026'));
    });
  });
}
