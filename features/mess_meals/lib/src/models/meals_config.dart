/// A voucher the school sells. `types` are the meals it covers (`Lunch`, ...).
class MealVoucher {
  const MealVoucher({
    required this.id,
    required this.displayName,
    required this.price,
    required this.types,
  });

  factory MealVoucher.fromJson(Map<String, dynamic> json) => MealVoucher(
    id: '${json['Id']}',
    displayName: json['DisplayName'] as String? ?? '',
    price: json['Price'] as num? ?? 0,
    types: (json['Type'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => '$e')
        .toList(),
  );

  final String id;
  final String displayName;

  /// Price per day.
  final num price;
  final List<String> types;
}

class MessConfig {
  const MessConfig({
    required this.vouchers,
    required this.daysForBuyVoucher,
    required this.voucherEligibleDays,
    required this.todayBuyBeforeTime,
    required this.isSaturdayHoliday,
    required this.includeHolidays,
    required this.buyDayBefore,
    this.dayBeforeCutoffTime,
  });

  factory MessConfig.fromJson(Map<String, dynamic> json) => MessConfig(
    vouchers: (json['Vouchers'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => MealVoucher.fromJson(e as Map<String, dynamic>))
        .toList(),
    daysForBuyVoucher: (json['DaysForBuyVoucher'] as num?)?.toInt() ?? 0,
    voucherEligibleDays: (json['VoucherEligibleDays'] as num?)?.toInt() ?? 0,
    todayBuyBeforeTime: json['TodayVoucherBuyBeforeTime'] as String? ?? '',
    isSaturdayHoliday: json['IsSatHoliday'] as bool? ?? false,
    includeHolidays: json['IsIncludeHolidays'] as bool? ?? false,
    buyDayBefore: json['IsVoucherBuyTimeDayBefore'] as bool? ?? false,
    dayBeforeCutoffTime: json['VoucherCutoffTimeDayBefore'] as String?,
  );

  final List<MealVoucher> vouchers;

  /// How many days ahead a voucher can be bought.
  final int daysForBuyVoucher;

  /// Working days a bought voucher stays valid.
  final int voucherEligibleDays;

  /// `HH:mm`; same-day purchases close at this time. Empty = no cutoff.
  final String todayBuyBeforeTime;
  final bool isSaturdayHoliday;

  /// When true, holidays and weekends count as normal days.
  final bool includeHolidays;

  /// When true, a day's voucher must be bought the day before.
  final bool buyDayBefore;

  /// `HH:mm` cutoff of the day before, when [buyDayBefore].
  final String? dayBeforeCutoffTime;
}

class MealHoliday {
  const MealHoliday({required this.name, required this.date});

  factory MealHoliday.fromJson(Map<String, dynamic> json) => MealHoliday(
    name: json['Name'] as String? ?? '',
    date: json['Date'] as String? ?? '',
  );

  final String name;

  /// `MM/dd/yyyy`.
  final String date;
}

class PurchaseRule {
  const PurchaseRule({required this.name, required this.position});

  factory PurchaseRule.fromJson(Map<String, dynamic> json) => PurchaseRule(
    name: json['Name'] as String? ?? '',
    position: (json['Position'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final int position;
}

/// `/v2.0/getMealCnfgForApp`.
class MealsConfig {
  const MealsConfig({
    required this.messConfig,
    required this.rules,
    required this.holidays,
    required this.convenienceFeeEnabled,
  });

  factory MealsConfig.fromJson(Map<String, dynamic> json) => MealsConfig(
    messConfig: MessConfig.fromJson(json['MessConfig'] as Map<String, dynamic>),
    rules: (json['Rules'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => PurchaseRule.fromJson(e as Map<String, dynamic>))
        .toList(),
    holidays: (json['Holidays'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => MealHoliday.fromJson(e as Map<String, dynamic>))
        .toList(),
    convenienceFeeEnabled:
        (json['MealPgCharges']
                as Map<String, dynamic>?)?['EnabledConvenienceFee']
            as bool? ??
        false,
  );

  final MessConfig messConfig;
  final List<PurchaseRule> rules;
  final List<MealHoliday> holidays;
  final bool convenienceFeeEnabled;
}

/// `/v2.0/getStuMessCnfg`: what the student already has.
class StudentMessConfig {
  const StudentMessConfig({
    required this.isAnnualMessOpted,
    required this.messTypes,
  });

  factory StudentMessConfig.fromJson(Map<String, dynamic> json) =>
      StudentMessConfig(
        isAnnualMessOpted: json['IsAnnualMessOpt'] as bool? ?? false,
        messTypes: (json['MessTypeConfig'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => '$e')
            .toList(),
      );

  final bool isAnnualMessOpted;

  /// Meal types already covered by an annual subscription.
  final List<String> messTypes;

  /// Vouchers whose meals the student does not already have.
  List<MealVoucher> buyable(List<MealVoucher> all) =>
      all.where((v) => !v.types.any(messTypes.contains)).toList();
}

/// A day the student already holds a voucher for (`/v2.0/getStuPurchasedDates`).
class PurchasedVoucher {
  const PurchasedVoucher({required this.date, required this.types});

  factory PurchasedVoucher.fromJson(Map<String, dynamic> json) =>
      PurchasedVoucher(
        date: json['Date'] as String? ?? '',
        types: (json['Types'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => '$e')
            .toList(),
      );

  /// `MM/dd/yyyy`.
  final String date;
  final List<String> types;
}
