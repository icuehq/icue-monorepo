import 'package:intl/intl.dart';

/// Where an event is relative to today.
enum EventPhase { upcoming, happeningNow, ended, unknown }

/// Reads the server's `dd-MMM-yyyy`; null when blank or unreadable.
DateTime? parseEventDate(String? text) {
  if (text == null || text.isEmpty) return null;
  try {
    return DateFormat('dd-MMM-yyyy').parse(text);
  } on FormatException {
    return null;
  }
}

/// Phase of an event on [today] (a calendar day, time ignored) and, for
/// upcoming ones, the days left.
({EventPhase phase, int daysToGo}) eventPhase(
  DateTime? start,
  DateTime? end,
  DateTime today,
) {
  if (start == null) return (phase: EventPhase.unknown, daysToGo: 0);
  final day = DateTime(today.year, today.month, today.day);
  final startDay = DateTime(start.year, start.month, start.day);
  if (startDay.isAfter(day)) {
    return (
      phase: EventPhase.upcoming,
      daysToGo: startDay.difference(day).inDays,
    );
  }
  if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) {
    return (phase: EventPhase.ended, daysToGo: 0);
  }
  return (phase: EventPhase.happeningNow, daysToGo: 0);
}

/// Days an event runs, counting both the first and last day.
int? eventDurationDays(DateTime? start, DateTime? end) =>
    start == null || end == null ? null : end.difference(start).inDays + 1;

/// Payment date and time as the server sends them: `MM/dd/yyyy` or
/// `dd-MM-yyyy`, then `HH:mm`. Null when neither fits.
DateTime? parsePaymentDateTime(String date, String time) {
  final text = '$date $time'.trim();
  for (final pattern in const ['MM/dd/yyyy HH:mm', 'dd-MM-yyyy HH:mm']) {
    try {
      return DateFormat(pattern).parseStrict(text);
    } on FormatException {
      continue;
    }
  }
  return null;
}
