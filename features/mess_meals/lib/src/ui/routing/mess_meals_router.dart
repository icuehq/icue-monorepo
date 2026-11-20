import 'package:go_router/go_router.dart';
import 'package:mess_meals/src/models/meal_order.dart';
import 'package:mess_meals/src/models/voucher_purchase.dart';
import 'package:mess_meals/src/ui/meal_menu_page.dart';
import 'package:mess_meals/src/ui/meal_payment_page.dart';
import 'package:mess_meals/src/ui/meal_purchase_summary_page.dart';
import 'package:mess_meals/src/ui/meal_vouchers_history_page.dart';
import 'package:mess_meals/src/ui/purchase_options_page.dart';
import 'package:mess_meals/src/ui/select_meal_vouchers_page.dart';
import 'package:mess_meals/src/ui/student_mess_details_page.dart';

class MessMealsRoutes {
  const MessMealsRoutes._();

  /// Hub route (a menu), child of `/`.
  static const String hub = 'layout.messmeals';
  static const String hubPath = '/layout.messmeals';

  /// Children of [hub].
  static const String mealMenu = 'layout.mealmenu';
  static const String instantPurchase = 'layout.instantmealpurchase';
  static const String _purchase =
      '/layout.messmeals/layout.instantmealpurchase';

  /// Children of [instantPurchase].
  static const String options = 'options';
  static const String optionsPath = '$_purchase/options';

  /// Children of [options].
  static const String selectVouchers = 'select-meal-vouchers';
  static const String history = 'meal-vouchers-history';
  static const String summary = 'meal-purchase-summary';
  static const String payment = 'meal-payment';
  static const String selectVouchersPath = '$optionsPath/$selectVouchers';
  static const String historyPath = '$optionsPath/$history';
  static const String summaryPath = '$optionsPath/$summary';
  static const String paymentPath = '$optionsPath/$payment';
}

/// Mount as children of the Mess & Meals hub route. [MealSelection] goes to
/// the summary and a [PaymentSession] to the payment page as `extra`.
List<RouteBase> messMealsHubRoutes() => [
  GoRoute(
    name: 'meal-menu-page',
    path: MessMealsRoutes.mealMenu,
    builder: (_, _) => const MealMenuPage(),
  ),
  GoRoute(
    name: 'instant-meal-purchase-page',
    path: MessMealsRoutes.instantPurchase,
    builder: (_, _) => const StudentMessDetailsPage(),
    routes: [
      GoRoute(
        name: 'Meal Purchase Options',
        path: MessMealsRoutes.options,
        builder: (_, _) => const PurchaseOptionsPage(),
        routes: [
          GoRoute(
            name: 'Select Meal Vourchers',
            path: MessMealsRoutes.selectVouchers,
            builder: (_, _) => const SelectMealVouchersPage(),
          ),
          GoRoute(
            name: 'Meal Vourchers History',
            path: MessMealsRoutes.history,
            builder: (_, _) => const MealVouchersHistoryPage(),
          ),
          GoRoute(
            name: 'Meal Purchase Summary',
            path: MessMealsRoutes.summary,
            builder: (_, state) => MealPurchaseSummaryPage(
              selection: state.extra! as MealSelection,
            ),
          ),
          GoRoute(
            name: 'Meal Payment',
            path: MessMealsRoutes.payment,
            builder: (_, state) =>
                MealPaymentPage(session: state.extra! as PaymentSession),
          ),
        ],
      ),
    ],
  ),
];
