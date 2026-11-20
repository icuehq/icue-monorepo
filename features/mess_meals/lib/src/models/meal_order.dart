import 'package:intl/intl.dart';
import 'package:mess_meals/src/models/meals_config.dart';

/// One bought voucher line in the checkout (`DaysEligible`).
class DaysEligible {
  const DaysEligible({
    required this.id,
    required this.name,
    required this.types,
    required this.days,
    required this.effectiveDate,
    required this.price,
    required this.amount,
    this.expiryDays,
    this.discount,
  });

  factory DaysEligible.fromJson(Map<String, dynamic> json) => DaysEligible(
    id: json['Id'] as String? ?? '',
    name: json['Name'] as String? ?? '',
    types: (json['Type'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => '$e')
        .toList(),
    days: (json['Days'] as num?)?.toInt() ?? 0,
    expiryDays: (json['ExpiryDays'] as num?)?.toInt(),
    effectiveDate: json['EffectiveDate'] as String? ?? '',
    price: json['Price'] as num? ?? 0,
    discount: json['Discount'] as num?,
    amount: json['Amount'] as num? ?? 0,
  );

  final String id;
  final String name;
  final List<String> types;
  final int days;
  final int? expiryDays;

  /// `MM/dd/yyyy`.
  final String effectiveDate;
  final num price;
  final num? discount;
  final num amount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'Id': id,
    'Name': name,
    'Type': types,
    'Days': days,
    'ExpiryDays': expiryDays,
    'EffectiveDate': effectiveDate,
    'Price': price,
    'Discount': discount,
    'Amount': amount,
  };
}

/// A meal type valid from [date] to [endDate] (`MM/dd/yyyy`), sent at checkout.
Map<String, dynamic> appliedDates(String type, DateTime date, DateTime end) {
  final format = DateFormat('MM/dd/yyyy');
  return <String, dynamic>{
    'Type': type,
    'Date': format.format(date),
    'EndDate': format.format(end),
  };
}

/// What the parent picked: the dates per voucher id.
class MealSelection {
  const MealSelection(this.datesByVoucher);

  final Map<String, List<DateTime>> datesByVoucher;

  bool get isEmpty => datesByVoucher.isEmpty;

  num totalFor(List<MealVoucher> vouchers) => datesByVoucher.entries.fold<num>(
    0,
    (sum, e) =>
        sum +
        (vouchers.where((v) => v.id == e.key).firstOrNull?.price ?? 0) *
            e.value.length,
  );
}

/// Checkout lines built from a [MealSelection].
class MealOrder {
  const MealOrder({required this.daysEligible, required this.datesApplied});

  final List<DaysEligible> daysEligible;
  final List<Map<String, dynamic>> datesApplied;

  /// Builds the order the server expects. Each date's voucher runs for
  /// [MessConfig.voucherEligibleDays] working days; holidays, weekends (unless
  /// the school counts them) and days already bought push its end date out.
  static MealOrder build({
    required MealSelection selection,
    required MessConfig config,
    required Set<DateTime> holidays,
    required Set<DateTime> purchased,
  }) {
    final format = DateFormat('MM/dd/yyyy');
    final lines = <DaysEligible>[];
    final dates = <Map<String, dynamic>>[];
    for (final entry in selection.datesByVoucher.entries) {
      final voucher = config.vouchers.firstWhere((v) => v.id == entry.key);
      final days = List<DateTime>.of(entry.value)..sort();
      lines.add(
        DaysEligible(
          id: voucher.id,
          name: voucher.displayName,
          types: voucher.types,
          days: days.length,
          expiryDays: config.voucherEligibleDays,
          effectiveDate: format.format(days.first),
          price: voucher.price,
          discount: 0,
          amount: days.length * voucher.price,
        ),
      );
      for (final day in days) {
        final skipped = skippedDays(
          start: day,
          config: config,
          holidays: holidays,
          purchased: purchased,
        );
        final end = day.add(
          Duration(days: config.voucherEligibleDays - 1 + skipped),
        );
        for (final type in voucher.types) {
          dates.add(appliedDates(type, day, end));
        }
      }
    }
    return MealOrder(daysEligible: lines, datesApplied: dates);
  }

  /// Days to add to a voucher's validity: counting forward from the day after
  /// [start] until [MessConfig.voucherEligibleDays] usable days are found,
  /// how many of the days passed were purchased, holidays or weekends.
  static int skippedDays({
    required DateTime start,
    required MessConfig config,
    required Set<DateTime> holidays,
    required Set<DateTime> purchased,
  }) {
    if (config.voucherEligibleDays <= 0) return 0;
    var skipped = 0;
    var found = 0;
    var elapsed = 0;
    while (found < config.voucherEligibleDays) {
      elapsed++;
      final day = start.add(Duration(days: elapsed));
      final only = DateTime(day.year, day.month, day.day);
      final closed =
          !config.includeHolidays &&
          (holidays.contains(only) ||
              day.weekday == DateTime.sunday ||
              (config.isSaturdayHoliday && day.weekday == DateTime.saturday));
      if (purchased.contains(only) || closed) {
        skipped++;
      } else {
        found++;
      }
    }
    return skipped;
  }
}
