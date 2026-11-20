import 'package:mess_meals/src/models/meal_order.dart';

/// Price breakdown the server computes for an order (`/v2.0/calcMealVoucherCharges`).
class MealCharges {
  const MealCharges({
    required this.amount,
    required this.convenienceFee,
    required this.showConvenienceFee,
    required this.vendorAmount,
    required this.total,
  });

  factory MealCharges.fromJson(Map<String, dynamic> json) => MealCharges(
    amount: json['Amount'] as num? ?? 0,
    convenienceFee: json['ConvFee'] as num? ?? 0,
    showConvenienceFee: json['IsShowConvCharges'] as bool? ?? false,
    vendorAmount: json['VndrAmount'] as num? ?? 0,
    total: json['TotalAmt'] as num? ?? 0,
  );

  final num amount;
  final num convenienceFee;
  final bool showConvenienceFee;
  final num vendorAmount;
  final num total;

  /// Fields of the checkout body; `ConvFee` is sent as `ConvenienceFee`.
  Map<String, dynamic> toCheckoutJson() => <String, dynamic>{
    'Amount': amount,
    'IsShowConvCharges': showConvenienceFee,
    'VndrAmount': vendorAmount,
    'ConvenienceFee': convenienceFee,
    'TotalAmt': total,
  };
}

/// A past purchase (`/v2.0/getMealVouchers`).
class VoucherPurchase {
  const VoucherPurchase({
    required this.id,
    required this.personName,
    required this.status,
    required this.amount,
    required this.convenienceFee,
    required this.paymentMode,
    required this.paymentDate,
    required this.paymentTime,
    required this.lines,
  });

  factory VoucherPurchase.fromJson(Map<String, dynamic> json) =>
      VoucherPurchase(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        personName: json['PersonName'] as String? ?? '',
        status: json['PaymentStatus'] as String? ?? '',
        amount: json['Amount'] as num? ?? 0,
        convenienceFee: json['ConvenienceFee'] as num? ?? 0,
        paymentMode: json['PaymentMode'] as String? ?? '',
        paymentDate: json['PaymentDate'] as String? ?? '',
        paymentTime: json['PaymentTime'] as String? ?? '',
        lines: (json['DaysEligible'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => DaysEligible.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String personName;

  /// `Completed`, `Failed` or `Initiated`.
  final String status;
  final num amount;
  final num convenienceFee;
  final String paymentMode;
  final String paymentDate;
  final String paymentTime;
  final List<DaysEligible> lines;

  bool get isCompleted => status == 'Completed';
}

/// One day of a purchased voucher (`/v2.0/getMealVoucherDetails`).
class VoucherDay {
  const VoucherDay({
    required this.type,
    required this.isUsed,
    required this.isExpired,
    this.displayDate,
    this.expiryDate,
  });

  factory VoucherDay.fromJson(Map<String, dynamic> json) => VoucherDay(
    type: json['Type'] as String? ?? '',
    isUsed: json['IsUsed'] as bool? ?? false,
    isExpired: json['IsExpired'] as bool? ?? false,
    displayDate: json['DisplayDate'] as String?,
    expiryDate: json['ExpiryDate'] as String?,
  );

  final String type;
  final bool isUsed;
  final bool isExpired;
  final String? displayDate;
  final String? expiryDate;
}

/// What the payment gateway needs to open a checkout.
class PaymentSession {
  const PaymentSession({required this.orderId, required this.sessionId});

  final String orderId;
  final String sessionId;
}
