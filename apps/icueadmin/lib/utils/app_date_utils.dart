import 'package:intl/intl.dart';

/// IST offset duration: UTC + 5 hours 30 minutes
const Duration istOffset = Duration(hours: 5, minutes: 30);

/// Helper utility for Indian date and time conversions.
class AppDateUtils {
  AppDateUtils._();

  /// Returns current DateTime in Indian Standard Time (IST).
  static DateTime nowIst() {
    return DateTime.now().toIst();
  }

  /// Converts any given [DateTime] to Indian Standard Time (UTC+05:30).
  static DateTime toIst(DateTime dateTime) {
    return dateTime.toIst();
  }
}

/// Extension on [DateTime?] providing a single source of truth for Indian date/time formatting in IST.
extension AppDateTimeExtension on DateTime? {
  /// Converts this [DateTime] to Indian Standard Time (UTC +05:30).
  DateTime? toIst() {
    if (this == null) return null;
    return this!.toUtc().add(istOffset);
  }

  DateTime _toIstInternal() {
    if (this == null) return DateTime.now();
    if (this!.isUtc) {
      return this!.add(istOffset);
    }
    // If it's a date-only constructed locally, keep date components as intended.
    if (this!.hour == 0 &&
        this!.minute == 0 &&
        this!.second == 0 &&
        this!.millisecond == 0) {
      return this!;
    }
    return this!.toUtc().add(istOffset);
  }

  /// Formats date in standard Indian format: `dd-MM-yyyy` (e.g. `02-09-2026`).
  String formattedDate({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('dd-MM-yyyy').format(ist);
  }

  /// Formats date in slash format: `dd/MM/yyyy` (e.g. `02/09/2026`).
  String formattedDateSlash({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('dd/MM/yyyy').format(ist);
  }

  /// Formats date with short month name: `dd-MMM-yyyy` (e.g. `02-Sep-2026`).
  String formattedFullDate({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('dd-MMM-yyyy').format(ist);
  }

  /// Formats date with day and month: `EEE, dd MMM yyyy` (e.g. `Wed, 02 Sep 2026`).
  String formattedDayDate({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('EEE, dd MMM yyyy').format(ist);
  }

  /// Formats time in 12-hour format with AM/PM in IST: `hh:mm a` (e.g. `01:45 PM`).
  String formattedTime({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('hh:mm a').format(ist);
  }

  /// Formats time with seconds in 12-hour format in IST: `hh:mm:ss a` (e.g. `01:45:30 PM`).
  String formattedTimeWithSecs({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('hh:mm:ss a').format(ist);
  }

  /// Formats 24-hour time in IST: `HH:mm` (e.g. `13:45`).
  String formattedAttendanceTime({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('HH:mm').format(ist);
  }

  /// Formats date and time in Indian format: `dd-MM-yyyy, hh:mm a` (e.g. `02-09-2026, 01:45 PM`).
  String formattedDateTime({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('dd-MM-yyyy, hh:mm a').format(ist);
  }

  /// Formats full date and time in Indian format: `dd-MMM-yyyy hh:mm a` (e.g. `02-Sep-2026 01:45 PM`).
  String formattedFullDateTime({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('dd-MMM-yyyy hh:mm a').format(ist);
  }

  /// Formats full date and time with seconds in Indian format: `dd-MMM-yyyy hh:mm:ss a`.
  String formattedFullDateTimeWithSecs({String fallback = '-'}) {
    if (this == null) return fallback;
    final ist = _toIstInternal();
    return DateFormat('dd-MMM-yyyy hh:mm:ss a').format(ist);
  }

  /// Legacy API format: `MM/dd/yyyy` (used for backend API payloads requiring MM/dd/yyyy).
  String? formattedGatePassDate() {
    if (this == null) return null;
    return DateFormat('MM/dd/yyyy').format(this!);
  }
}

/// Extension on [DateTime] providing non-nullable convenience methods.
extension NonNullableDateTimeExtension on DateTime {
  /// Converts this [DateTime] to Indian Standard Time (UTC +05:30).
  DateTime toIst() {
    return isUtc ? add(istOffset) : toUtc().add(istOffset);
  }
}

/// Extension on [String?] for resilient date-time parsing and formatting in Indian format / IST.
extension AppDateStringConverter on String? {
  /// Robustly parses any date/time string into a [DateTime] in IST.
  DateTime? toIstDateTime() {
    final dt = toDate();
    if (dt == null) return null;
    return dt.toIst();
  }

  /// Robustly parses any date/time string into a [DateTime].
  DateTime? toDate() {
    if (this == null || this!.trim().isEmpty) return null;
    final raw = this!.trim();

    // 1. Try ISO 8601 parsing first
    final parsedIso = DateTime.tryParse(raw);
    if (parsedIso != null) {
      return parsedIso;
    }

    // 2. Try common formats
    final dateFormats = [
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy HH:mm',
      'MM/dd/yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy',
      'dd-MMM-yyyy hh:mm a',
      'dd-MMM-yyyy, hh:mm a',
      'dd-MMM-yyyy HH:mm:ss',
      'dd-MMM-yyyy',
      'dd MMM yyyy',
      'MMM d, yyyy',
    ];

    for (final fmt in dateFormats) {
      try {
        return DateFormat(fmt).parseLoose(raw);
      } catch (_) {}
    }

    return null;
  }

  /// Robustly parses a date-time string into a [DateTime].
  DateTime? toDateTime() {
    return toDate();
  }

  /// Robustly parses a time string into a [DateTime].
  DateTime? toTime() {
    if (this == null || this!.trim().isEmpty) return null;
    final raw = this!.trim();

    final timeFormats = [
      'HH:mm:ss',
      'HH:mm',
      'hh:mm:ss a',
      'hh:mm a',
      'h:mm a',
      'h:mm:ss a',
    ];

    for (final fmt in timeFormats) {
      try {
        return DateFormat(fmt).parseLoose(raw);
      } catch (_) {}
    }

    // Fallback to general date parser
    return toDate();
  }

  /// Formats this date string directly as Indian date (`dd-MM-yyyy`).
  String formatAsIndianDate({String fallback = '-'}) {
    final parsed = toDate();
    if (parsed == null) {
      return (this != null && this!.isNotEmpty) ? this! : fallback;
    }
    return parsed.formattedDate(fallback: fallback);
  }

  /// Formats this date string directly as Indian full date (`dd-MMM-yyyy`).
  String formatAsIndianFullDate({String fallback = '-'}) {
    final parsed = toDate();
    if (parsed == null) {
      return (this != null && this!.isNotEmpty) ? this! : fallback;
    }
    return parsed.formattedFullDate(fallback: fallback);
  }

  /// Formats this time string directly as 12-hour Indian time (`hh:mm a`).
  String formatAsIndianTime({String fallback = '-'}) {
    final parsed = toTime();
    if (parsed == null) {
      return (this != null && this!.isNotEmpty) ? this! : fallback;
    }
    return parsed.formattedTime(fallback: fallback);
  }

  /// Formats this date-time string directly as Indian date-time (`dd-MM-yyyy, hh:mm a`).
  String formatAsIndianDateTime({String fallback = '-'}) {
    final parsed = toDate();
    if (parsed == null) {
      return (this != null && this!.isNotEmpty) ? this! : fallback;
    }
    return parsed.formattedDateTime(fallback: fallback);
  }

  /// Formats this date-time string directly as Indian full date-time (`dd-MMM-yyyy hh:mm a`).
  String formatAsIndianFullDateTime({String fallback = '-'}) {
    final parsed = toDate();
    if (parsed == null) {
      return (this != null && this!.isNotEmpty) ? this! : fallback;
    }
    return parsed.formattedFullDateTime(fallback: fallback);
  }
}
