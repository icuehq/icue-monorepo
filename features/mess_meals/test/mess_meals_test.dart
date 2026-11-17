import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_meals/src/models/meal_order.dart';
import 'package:mess_meals/src/models/meals_config.dart';
import 'package:mess_meals/src/models/voucher_date_rules.dart';
import 'package:mess_meals/src/models/voucher_purchase.dart';
import 'package:mess_meals/src/services/mess_meals_service.dart';

MessConfig _config({
  int eligible = 2,
  int buyDays = 14,
  bool satHoliday = false,
  bool includeHolidays = false,
  String sameDayCutoff = '',
  bool dayBefore = false,
  String? dayBeforeCutoff,
}) => MessConfig(
  vouchers: const [
    MealVoucher(id: 'L', displayName: 'Lunch', price: 50, types: ['Lunch']),
    MealVoucher(
      id: 'LS',
      displayName: 'Lunch+Snack',
      price: 80,
      types: ['Lunch', 'Snack'],
    ),
  ],
  daysForBuyVoucher: buyDays,
  voucherEligibleDays: eligible,
  todayBuyBeforeTime: sameDayCutoff,
  isSaturdayHoliday: satHoliday,
  includeHolidays: includeHolidays,
  buyDayBefore: dayBefore,
  dayBeforeCutoffTime: dayBeforeCutoff,
);

class _FakeApiClient extends Fake implements ApiClient {
  int status = 200;
  dynamic body;
  String? lastPath;
  Map<String, dynamic>? lastData;
  final shown = <String>[];

  @override
  void Function(String message)? get onShowErrorMessage => shown.add;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastPath = path;
    lastData = data as Map<String, dynamic>?;
    return Response<T>(
      data: body as T,
      statusCode: status,
      requestOptions: RequestOptions(path: path),
    );
  }
}

ParentStudent _student() => ParentStudent.fromJson({
  'OrganizationId': 1,
  'BranchId': 2,
  'ZoneId': 3,
  'Id': 4,
  'Name': 'Asha',
  'AdmissionNumber': 'A-9',
  'ClassId': 1,
  'Gender': 'F',
  'ParentAppFeature': {'Id': 1, 'Name': 'x'},
});

void main() {
  group('MealOrder.skippedDays', () {
    // 2026-03-02 is a Monday.
    final monday = DateTime(2026, 3, 2);

    test('no skips on plain weekdays', () {
      expect(
        MealOrder.skippedDays(
          start: monday,
          config: _config(),
          holidays: {},
          purchased: {},
        ),
        0,
      );
    });

    test('Sunday and a holiday are skipped, Saturday only when a holiday', () {
      // Friday start, 2 eligible days: Sat (kept), Sun (skip), Mon (kept).
      final friday = DateTime(2026, 3, 6);
      expect(
        MealOrder.skippedDays(
          start: friday,
          config: _config(),
          holidays: {},
          purchased: {},
        ),
        1,
      );
      // With Saturday a holiday: Sat skip, Sun skip, Mon, Tue.
      expect(
        MealOrder.skippedDays(
          start: friday,
          config: _config(satHoliday: true),
          holidays: {},
          purchased: {},
        ),
        2,
      );
      // Monday holiday on top of a plain weekend.
      expect(
        MealOrder.skippedDays(
          start: friday,
          config: _config(),
          holidays: {DateTime(2026, 3, 9)},
          purchased: {},
        ),
        2,
      );
    });

    test('purchased days skip even when holidays are included', () {
      expect(
        MealOrder.skippedDays(
          start: monday,
          config: _config(includeHolidays: true),
          holidays: {},
          purchased: {DateTime(2026, 3, 3)},
        ),
        1,
      );
    });
  });

  test(
    'MealOrder.build makes one line per voucher and an end date per type',
    () {
      final order = MealOrder.build(
        selection: MealSelection({
          'LS': [DateTime(2026, 3, 3), DateTime(2026, 3, 2)],
        }),
        config: _config(),
        holidays: {},
        purchased: {},
      );
      final line = order.daysEligible.single;
      expect(line.days, 2);
      expect(line.amount, 160);
      expect(line.effectiveDate, '03/02/2026');
      expect(line.toJson()['Type'], ['Lunch', 'Snack']);
      // 2 dates x 2 types, each valid for 2 working days.
      expect(order.datesApplied, hasLength(4));
      expect(order.datesApplied.first, {
        'Type': 'Lunch',
        'Date': '03/02/2026',
        'EndDate': '03/03/2026',
      });
    },
  );

  group('VoucherDateRules', () {
    final holiday = [const MealHoliday(name: 'Fest', date: '03/05/2026')];
    final bought = [
      const PurchasedVoucher(date: '03/04/2026', types: ['Lunch']),
      const PurchasedVoucher(date: '03/06/2026', types: ['Snack']),
    ];

    VoucherDateRules rules(MessConfig config, DateTime now) => VoucherDateRules(
      config: config,
      holidays: holiday,
      purchased: bought,
      voucherTypes: const ['Lunch'],
      now: now,
    );

    test('filters weekends, holidays and days bought for the same type', () {
      final r = rules(_config(buyDays: 7), DateTime(2026, 3, 2, 9));
      expect(r.isSelectable(DateTime(2026, 3, 3)), isTrue);
      expect(r.isSelectable(DateTime(2026, 3, 4)), isFalse); // bought (Lunch)
      expect(r.isSelectable(DateTime(2026, 3, 5)), isFalse); // holiday
      expect(r.isSelectable(DateTime(2026, 3, 6)), isTrue); // bought Snack only
      expect(r.isSelectable(DateTime(2026, 3, 8)), isFalse); // Sunday
      expect(r.isSelectable(DateTime(2026, 3, 10)), isFalse); // out of range
    });

    test('same-day cutoff closes today after the time', () {
      final config = _config(sameDayCutoff: '10:00');
      expect(
        rules(
          config,
          DateTime(2026, 3, 2, 9, 59),
        ).isSelectable(DateTime(2026, 3, 2)),
        isTrue,
      );
      expect(
        rules(
          config,
          DateTime(2026, 3, 2, 10),
        ).isSelectable(DateTime(2026, 3, 2)),
        isFalse,
      );
    });

    test('day-before mode closes today, and tomorrow after the cutoff', () {
      final config = _config(dayBefore: true, dayBeforeCutoff: '18:00');
      final early = rules(config, DateTime(2026, 3, 2, 12));
      expect(early.isSelectable(DateTime(2026, 3, 2)), isFalse);
      expect(early.isSelectable(DateTime(2026, 3, 3)), isTrue);
      final late = rules(config, DateTime(2026, 3, 2, 18, 30));
      expect(late.isSelectable(DateTime(2026, 3, 3)), isFalse);
      expect(late.mode, CutoffMode.dayBefore);
    });

    test('availableDates lists every pickable day in order', () {
      final r = rules(_config(buyDays: 4), DateTime(2026, 3, 2, 9));
      expect(r.availableDates, [
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 3),
        DateTime(2026, 3, 6),
      ]);
    });
  });

  test(
    'StudentMessConfig hides vouchers whose meals the student already has',
    () {
      const student = StudentMessConfig(
        isAnnualMessOpted: true,
        messTypes: ['Lunch'],
      );
      expect(student.buyable(_config().vouchers), isEmpty);
      const other = StudentMessConfig(isAnnualMessOpted: false, messTypes: []);
      expect(other.buyable(_config().vouchers), hasLength(2));
    },
  );

  group('MessMealsService', () {
    test(
      'checkOut maps ConvFee to ConvenienceFee and keeps fixed fields',
      () async {
        final api = _FakeApiClient()
          ..body = {'OrderId': 'o1', 'paymentSessionId': 's1'};
        final session = await MessMealsService(api).checkOut(
          student: _student(),
          order: const MealOrder(daysEligible: [], datesApplied: []),
          amount: 100,
          convenienceFeeEnabled: true,
          charges: const MealCharges(
            amount: 100,
            convenienceFee: 3,
            showConvenienceFee: true,
            vendorAmount: 2,
            total: 103,
          ),
        );
        expect(session?.orderId, 'o1');
        expect(session?.sessionId, 's1');
        final body = api.lastData!;
        expect(body['ConvenienceFee'], 3);
        expect(body.containsKey('ConvFee'), isFalse);
        expect(body['OrderAmount'], 103);
        expect(body['FeeType'], 'Mess Voucher');
        expect(body['StandardType'], 'STUDENT');
        expect(body['StudentId'], 4);
        expect(body['AdmissionNumber'], 'A-9');
      },
    );

    test('checkOut without charges sends the plain amount', () async {
      final api = _FakeApiClient()
        ..body = {'OrderId': 'o', 'paymentSessionId': 's'};
      await MessMealsService(api).checkOut(
        student: _student(),
        order: const MealOrder(daysEligible: [], datesApplied: []),
        amount: 100,
        convenienceFeeEnabled: false,
        charges: null,
      );
      expect(api.lastData!['Amount'], 100);
      expect(api.lastData!['OrderAmount'], 100);
      expect(api.lastData!['IsShowConvCharges'], isFalse);
      expect(api.lastData!['ConvenienceFee'], 0);
    });

    test('a non-200 answer shows its message and yields null', () async {
      final api = _FakeApiClient()
        ..status = 202
        ..body = {'message': 'Closed today'};
      final config = await MessMealsService(api).getMealsConfig(_student());
      expect(config, isNull);
      expect(api.shown, ['Closed today']);
    });

    test('mess config refusal is silent', () async {
      final api = _FakeApiClient()
        ..status = 202
        ..body = {'message': 'Mess config details not found'};
      expect(
        await MessMealsService(api).getStudentMessConfig(_student()),
        isNull,
      );
      expect(api.shown, isEmpty);
    });

    test('getPurchases reports more pages only for a full page', () async {
      final api = _FakeApiClient()
        ..body = {
          'data': [
            {'Id': 1, 'PaymentStatus': 'Completed'},
            {'Id': 2, 'PaymentStatus': 'Failed'},
          ],
        };
      final service = MessMealsService(api);
      expect(
        (await service.getPurchases(_student(), page: 1, pageSize: 2))?.hasMore,
        isTrue,
      );
      expect(
        (await service.getPurchases(_student(), page: 2, pageSize: 3))?.hasMore,
        isFalse,
      );
    });
  });
}
