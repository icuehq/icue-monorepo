import 'package:intl/intl.dart';
import 'package:mess_meals/src/models/meals_config.dart';

/// When a day's voucher can still be bought.
enum CutoffMode {
  /// The day itself, until [VoucherDateRules.cutoffTime].
  sameDay,

  /// The day before, until [VoucherDateRules.cutoffTime]; today is always closed.
  dayBefore,

  /// No cutoff.
  none,
}

/// Which days a parent may pick when buying one voucher. Pure: pass [now] so
/// the rules are testable.
class VoucherDateRules {
  VoucherDateRules({
    required MessConfig config,
    required List<MealHoliday> holidays,
    required List<PurchasedVoucher> purchased,
    required List<String> voucherTypes,
    required DateTime now,
    DateTime? effectiveDate,
  }) : _now = now,
       _saturdayHoliday = config.isSaturdayHoliday,
       minDate = _dateOnly(effectiveDate ?? now),
       maxDate = _dateOnly(effectiveDate ?? now)
           .add(Duration(days: config.daysForBuyVoucher)),
       mode = config.buyDayBefore && config.dayBeforeCutoffTime != null
           ? CutoffMode.dayBefore
           : (config.todayBuyBeforeTime.isNotEmpty
                 ? CutoffMode.sameDay
                 : CutoffMode.none),
       cutoffTime = config.buyDayBefore && config.dayBeforeCutoffTime != null
           ? _minutes(config.dayBeforeCutoffTime!)
           : (config.todayBuyBeforeTime.isNotEmpty
                 ? _minutes(config.todayBuyBeforeTime)
                 : null),
       holidays = {
         for (final h in holidays) _dateOnly(parseServerDate(h.date)),
       },
       purchasedDays = {
         for (final p in purchased)
           if (p.types.any(voucherTypes.contains))
             _dateOnly(parseServerDate(p.date)),
       };

  final DateTime _now;
  final bool _saturdayHoliday;
  final DateTime minDate;
  final DateTime maxDate;
  final CutoffMode mode;

  /// Minutes after midnight of the cutoff; null when there is none.
  final int? cutoffTime;
  final Set<DateTime> holidays;
  final Set<DateTime> purchasedDays;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  /// `MM/dd/yyyy`; an unreadable date counts as today so it is filtered by range.
  static DateTime parseServerDate(String text) {
    try {
      return DateFormat('MM/dd/yyyy').parse(text);
    } on FormatException {
      return DateTime.now();
    }
  }

  bool get _cutoffPassed {
    final cutoff = cutoffTime;
    return cutoff != null && _now.hour * 60 + _now.minute >= cutoff;
  }

  /// Same-day purchases closed for today.
  bool get isTodayClosed =>
      mode == CutoffMode.dayBefore ||
      (mode == CutoffMode.sameDay && _cutoffPassed);

  /// Day-before purchases for tomorrow closed for today.
  bool get isTomorrowClosed => mode == CutoffMode.dayBefore && _cutoffPassed;

  bool isSelectable(DateTime date) {
    final day = _dateOnly(date);
    final today = _dateOnly(_now);
    final tomorrow = today.add(const Duration(days: 1));
    if (day == today && isTodayClosed) return false;
    if (day == tomorrow && isTomorrowClosed) return false;
    if (day.isBefore(minDate) || day.isAfter(maxDate)) return false;
    if (day.weekday == DateTime.sunday) return false;
    if (_saturdayHoliday && day.weekday == DateTime.saturday) return false;
    return !holidays.contains(day) && !purchasedDays.contains(day);
  }

  /// Every pickable day in range, earliest first.
  List<DateTime> get availableDates => [
    for (
      var d = minDate;
      !d.isAfter(maxDate);
      d = d.add(const Duration(days: 1))
    )
      if (isSelectable(d)) d,
  ];
}
