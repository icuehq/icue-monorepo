import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:mess_meals/src/models/meal_order.dart';
import 'package:mess_meals/src/models/meals_config.dart';
import 'package:mess_meals/src/models/voucher_date_rules.dart';
import 'package:mess_meals/src/models/voucher_purchase.dart';
import 'package:mess_meals/src/services/mess_meals_service.dart';

/// State of the voucher purchase flow of the selected student.
@lazySingleton
class MealsProvider extends ChangeNotifier {
  MealsProvider(this._service, this._auth) {
    _studentIdSeen = _auth.selectedStudent?.id;
    _auth.addListener(_onAuthChanged);
  }

  final MessMealsService _service;
  final ParentAuthProvider _auth;

  MealsConfig? config;
  StudentMessConfig? studentConfig;
  DateTime? effectiveDate;
  List<PurchasedVoucher> purchased = <PurchasedVoucher>[];
  MealCharges? charges;
  bool loading = false;

  List<VoucherPurchase> history = <VoucherPurchase>[];
  bool historyHasMore = true;
  bool loadingMore = false;
  int _historyPage = 1;

  List<VoucherDay> voucherDays = <VoucherDay>[];

  int? _studentIdSeen;

  ParentStudent? get student => _auth.selectedStudent;

  /// Vouchers the student can still buy.
  List<MealVoucher> get buyableVouchers {
    final all = config?.messConfig.vouchers ?? <MealVoucher>[];
    return studentConfig?.buyable(all) ?? all;
  }

  void _onAuthChanged() {
    final id = _auth.selectedStudent?.id;
    if (id == _studentIdSeen) return;
    _studentIdSeen = id;
    reset();
  }

  void reset() {
    config = null;
    studentConfig = null;
    effectiveDate = null;
    purchased = <PurchasedVoucher>[];
    charges = null;
    history = <VoucherPurchase>[];
    historyHasMore = true;
    voucherDays = <VoucherDay>[];
    notifyListeners();
  }

  Future<T?> _guard<T>(Future<T?> Function(ParentStudent s) call) async {
    final s = student;
    if (s == null) return null;
    try {
      return await call(s);
    } on ApiException {
      return null; // ApiClient showed the message.
    }
  }

  /// Loads everything the purchase pages need.
  Future<void> loadPurchaseData() async {
    reset();
    loading = true;
    notifyListeners();
    final results = await Future.wait([
      _guard(_service.getMealsConfig),
      _guard(_service.getEffectiveDate),
      _guard(_service.getPurchasedDates),
      _guard(_service.getStudentMessConfig),
    ]);
    config = results[0] as MealsConfig?;
    effectiveDate = results[1] as DateTime?;
    purchased = (results[2] as List<PurchasedVoucher>?) ?? <PurchasedVoucher>[];
    studentConfig = results[3] as StudentMessConfig?;
    loading = false;
    notifyListeners();
  }

  /// Date rules for [voucher]; null before the config is loaded.
  VoucherDateRules? rulesFor(MealVoucher voucher) {
    final c = config;
    if (c == null) return null;
    return VoucherDateRules(
      config: c.messConfig,
      holidays: c.holidays,
      purchased: purchased,
      voucherTypes: voucher.types,
      now: DateTime.now(),
      effectiveDate: effectiveDate,
    );
  }

  /// Asks the server for the price breakdown of [amount]; the fee is skipped
  /// when the school does not charge one.
  Future<void> calculateCharges(num amount) async {
    if (config?.convenienceFeeEnabled == false) {
      charges = null;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    charges = await _guard((s) => _service.calculateCharges(s, amount));
    loading = false;
    notifyListeners();
  }

  /// The order for [selection] with validity ends worked out from the school's calendar.
  MealOrder? buildOrder(MealSelection selection) {
    final c = config;
    if (c == null) return null;
    return MealOrder.build(
      selection: selection,
      config: c.messConfig,
      holidays: {
        for (final h in c.holidays)
          _only(VoucherDateRules.parseServerDate(h.date)),
      },
      purchased: {
        for (final p in purchased)
          _only(VoucherDateRules.parseServerDate(p.date)),
      },
    );
  }

  static DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Creates the order; null when the server refused.
  Future<PaymentSession?> checkOut(MealSelection selection, num amount) async {
    final order = buildOrder(selection);
    final c = config;
    if (order == null || c == null) return null;
    loading = true;
    notifyListeners();
    final session = await _guard(
      (s) => _service.checkOut(
        student: s,
        order: order,
        amount: amount,
        convenienceFeeEnabled: c.convenienceFeeEnabled,
        charges: charges,
      ),
    );
    loading = false;
    notifyListeners();
    return session;
  }

  Future<void> orderPaid(String orderId) async {
    await _guard((s) async {
      await _service.refreshOrderStatus(s, orderId);
      return true;
    });
  }

  Future<void> loadHistory() async {
    history = <VoucherPurchase>[];
    historyHasMore = true;
    _historyPage = 1;
    loading = true;
    notifyListeners();
    await _fetchHistoryPage();
    loading = false;
    notifyListeners();
  }

  Future<void> loadMoreHistory() async {
    if (loading || loadingMore || !historyHasMore) return;
    loadingMore = true;
    _historyPage++;
    notifyListeners();
    await _fetchHistoryPage();
    loadingMore = false;
    notifyListeners();
  }

  Future<void> _fetchHistoryPage() async {
    final page = await _guard(
      (s) => _service.getPurchases(s, page: _historyPage),
    );
    if (page == null) {
      historyHasMore = false;
      return;
    }
    history = [...history, ...page.items];
    historyHasMore = page.hasMore;
  }

  Future<void> loadVoucherDays(int voucherId) async {
    voucherDays = <VoucherDay>[];
    loading = true;
    notifyListeners();
    voucherDays =
        await _guard((s) => _service.getVoucherDays(s, voucherId)) ??
        <VoucherDay>[];
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
