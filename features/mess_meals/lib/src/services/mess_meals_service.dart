import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:mess_meals/src/models/meal_order.dart';
import 'package:mess_meals/src/models/meals_config.dart';
import 'package:mess_meals/src/models/voucher_purchase.dart';

/// Page of past purchases with whether the server may have more.
class VoucherPurchasePage {
  const VoucherPurchasePage({required this.items, required this.hasMore});

  final List<VoucherPurchase> items;
  final bool hasMore;
}

/// Endpoints of Mess & Meals (all `/v2.0`). Besides 4xx/5xx (shown by
/// `ApiClient`), the server answers some refusals with a 2xx other than 200
/// and a `message`; those are shown the same way and yield null.
@lazySingleton
class MessMealsService {
  const MessMealsService(this._apiClient);

  final ApiClient _apiClient;

  /// Body fields every mess endpoint wants for the student.
  static Map<String, dynamic> _scope(ParentStudent s) => <String, dynamic>{
    'OrganizationId': s.organizationId,
    'ZoneId': s.zoneId,
    'BranchId': s.branchId,
    'StudentId': s.id,
  };

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> data, {
    bool quietRefusal = false,
  }) async {
    final response = await _apiClient.post<dynamic>(path, data: data);
    return _apiClient.parse(response, (body) {
      if (response.statusCode == 200 && body is Map<String, dynamic>) {
        return body;
      }
      if (!quietRefusal) {
        final message = body is Map<String, dynamic>
            ? body['message'] as String?
            : null;
        _apiClient.onShowErrorMessage?.call(
          message ?? 'Something went wrong. Please try again later.',
        );
      }
      return null;
    });
  }

  Future<StudentMessConfig?> getStudentMessConfig(ParentStudent s) async {
    // "Mess config details not found" just means the student has none yet.
    final body = await _post(
      '/v2.0/getStuMessCnfg',
      _scope(s),
      quietRefusal: true,
    );
    return body == null ? null : StudentMessConfig.fromJson(body);
  }

  Future<MealsConfig?> getMealsConfig(ParentStudent s) async {
    final body = await _post('/v2.0/getMealCnfgForApp', _scope(s));
    return body == null ? null : MealsConfig.fromJson(body);
  }

  /// First day a voucher can start from; null when the server sends none.
  Future<DateTime?> getEffectiveDate(ParentStudent s) async {
    final body = await _post('/v2.0/getMealVoucherEffectiveDate', _scope(s));
    final date = body?['EffectiveDate'] as String?;
    return date == null ? null : DateFormat('yyyy-MM-dd').parse(date);
  }

  Future<List<PurchasedVoucher>?> getPurchasedDates(ParentStudent s) async {
    final body = await _post('/v2.0/getStuPurchasedDates', <String, dynamic>{
      ..._scope(s),
      'DelPastDts': true,
    });
    return (body?['Vouchers'] as List<dynamic>?)
        ?.map((e) => PurchasedVoucher.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MealCharges?> calculateCharges(ParentStudent s, num amount) async {
    final body = await _post('/v2.0/calcMealVoucherCharges', <String, dynamic>{
      ..._scope(s),
      'Amount': amount,
    });
    return body == null ? null : MealCharges.fromJson(body);
  }

  /// Creates the order and the gateway session. [charges] is null when the
  /// school charges no convenience fee.
  Future<PaymentSession?> checkOut({
    required ParentStudent student,
    required MealOrder order,
    required num amount,
    required bool convenienceFeeEnabled,
    required MealCharges? charges,
  }) async {
    final body = await _post('/v2.0/messPaymentCheckOut', <String, dynamic>{
      ..._scope(student),
      'FeeType': 'Mess Voucher',
      'AdmissionNumber': student.admissionNumber,
      'EnabledConvenienceFee': convenienceFeeEnabled,
      if (charges != null)
        ...charges.toCheckoutJson()
      else ...<String, dynamic>{
        'Amount': amount,
        'IsShowConvCharges': false,
        'VndrAmount': 0,
        'ConvenienceFee': 0,
      },
      'OrderAmount': charges?.total ?? amount,
      'PaymentMode': 'Online',
      'DaysEligible': order.daysEligible.map((e) => e.toJson()).toList(),
      'DatesAppl': order.datesApplied,
      'SubDomain': 'phoenix-purchases.itraxpro.com',
      'StandardType': 'STUDENT',
    });
    if (body == null) return null;
    return PaymentSession(
      orderId: '${body['OrderId']}',
      sessionId: '${body['paymentSessionId']}',
    );
  }

  /// Tells the server to refresh the order's payment status after the gateway
  /// reported success.
  Future<void> refreshOrderStatus(ParentStudent s, String orderId) => _post(
    '/v2.0/messOrderStatus',
    <String, dynamic>{'StudentId': s.id, 'order_id': orderId},
  );

  Future<VoucherPurchasePage?> getPurchases(
    ParentStudent s, {
    required int page,
    int pageSize = 10,
  }) async {
    final body = await _post('/v2.0/getMealVouchers', <String, dynamic>{
      'PageNumber': page,
      'PageSize': pageSize,
      ..._scope(s),
    });
    if (body == null) return null;
    final items = (body['data'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => VoucherPurchase.fromJson(e as Map<String, dynamic>))
        .toList();
    // The server does not say how many there are: a full page means maybe more.
    return VoucherPurchasePage(items: items, hasMore: items.length >= pageSize);
  }

  Future<List<VoucherDay>?> getVoucherDays(
    ParentStudent s,
    int voucherId,
  ) async {
    final body = await _post('/v2.0/getMealVoucherDetails', <String, dynamic>{
      ..._scope(s),
      'VoucherId': voucherId,
    });
    return (body?['DatesAppl'] as List<dynamic>?)
        ?.map((e) => VoucherDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
