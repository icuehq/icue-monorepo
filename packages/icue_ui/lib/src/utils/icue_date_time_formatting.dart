import 'package:intl/intl.dart';

const _indiaOffset = Duration(hours: 5, minutes: 30);

extension DateTimeFormatting on DateTime {
  /// `2025-03-05`: the API and Firestore day format.
  String toApiDate() => DateFormat('yyyy-MM-dd').format(this);

  /// `03/05/2025`: for APIs that take US-style dates.
  String toUsDate() => DateFormat('MM/dd/yyyy').format(this);

  /// `05/03/2025`.
  String toNumericDate() => DateFormat('dd/MM/yyyy').format(this);

  /// `05/03/2025, 02:30 PM`.
  String toNumericDateTime() => DateFormat('dd/MM/yyyy, hh:mm a').format(this);

  /// `05 Mar 2025`.
  String toDisplayDate() => DateFormat('dd MMM yyyy').format(this);

  /// `05 Mar 2025, 02:30 PM`.
  String toDisplayDateTime() => DateFormat('dd MMM yyyy, hh:mm a').format(this);

  /// `02:30 PM`.
  String toTime12() => DateFormat('hh:mm a').format(this);

  /// `14:30:05`.
  String toTime24() => DateFormat('HH:mm:ss').format(this);

  /// `9:05`: unpadded hour.
  String toHourMinute() => DateFormat('H:mm').format(this);

  /// Midnight at the start of this calendar day.
  DateTime get dateOnly => DateTime(year, month, day);

  /// India Standard Time wall-clock fields whatever the device zone: a UTC [DateTime] shifted by +5:30,
  /// so format it, never convert it back with `toLocal()`.
  DateTime toIndianTime() => toUtc().add(_indiaOffset);

  /// Indian financial year (April to March) holding this date: `2026-27`.
  String get financialYear {
    final startYear = month >= 4 ? year : year - 1;
    return '$startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';
  }

  /// "[title] will expire in 12 days", "… expires today" or "… expired 5 days ago";
  /// null when expiry is more than 30 days away.
  String? expiryStatus(String title) {
    final days = dateOnly.difference(DateTime.now().dateOnly).inDays;
    if (days > 30) return null;
    if (days > 0) return '$title will expire in $days days';
    if (days == 0) return '$title expires today';
    return '$title expired ${days.abs()} days ago';
  }
}

extension DateText on String? {
  /// Parses ISO 8601, `dd-MM-yyyy`, `dd/MM/yyyy` or `yyyy/MM/dd`; null when blank or unrecognised.
  DateTime? toDateOrNull() {
    final text = this?.trim();
    if (text == null || text.isEmpty) return null;
    final direct = DateTime.tryParse(text);
    if (direct != null) return direct;

    final parts = text.split(RegExp('[-/]')).map(int.tryParse).toList();
    if (parts.length != 3 || parts.contains(null)) return null;
    final [first!, second!, third!] = parts;
    if (third > 1000) {
      return second <= 12 && first <= 31
          ? DateTime(third, second, first)
          : null;
    }
    return first > 1000 ? DateTime(first, second, third) : null;
  }

  /// A stored date string (`2025-03-05`, `05-03-2025`…) shown the Indian way, `05/03/2025`;
  /// empty when blank, unchanged when unrecognised.
  String toDisplayDay() {
    final text = this?.trim() ?? '';
    return text.isEmpty
        ? text
        : text.toDateOrNull()?.toLocal().toNumericDate() ?? text;
  }

  /// A stored 24-hour time string (`14:30`, `14:30:05`) shown as `02:30 PM`; empty when blank,
  /// unchanged when unrecognised or already 12-hour.
  String toDisplayTime() {
    final text = this?.trim() ?? '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (match == null) return text;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return text;
    return DateTime(2000, 1, 1, hour, minute).toTime12();
  }
}

/// Today's calendar day in India Standard Time (`yyyy-MM-dd`), as the backend dates records.
String todayIST() => DateTime.now().toIndianTime().toApiDate();
