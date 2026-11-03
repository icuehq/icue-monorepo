import 'package:expenses/src/models/expense_type.dart';
import 'package:flutter/foundation.dart';

@immutable
class SelfFillingStatusRequest {
  const SelfFillingStatusRequest({
    required this.fuelType,
    required this.gaugeMode,
    this.startReading,
    this.endReading,
    this.transDate,
    this.gaugeFileBytes,
    this.gaugeFileName,
    this.billFileBytes,
    this.billFileName,
  });

  final String fuelType;
  final String gaugeMode; // 'start' or 'end'
  final String? startReading;
  final String? endReading;
  final String? transDate;
  final List<int>? gaugeFileBytes;
  final String? gaugeFileName;
  final List<int>? billFileBytes;
  final String? billFileName;
}

@immutable
class StoreExpenseRequest {
  const StoreExpenseRequest({
    required this.vehicleNumber,
    required this.expenseType,
    required this.billDate,
    required this.billAmount,
    this.billNo,
    this.vendorName,
    this.status = 'UnBilled',
    this.description,
    this.mode,
    this.fuelType,
    this.speedometer,
    this.extraFields = const <String, dynamic>{},
    this.billFileBytes,
    this.billFileName,
    this.odometerFileBytes,
    this.odometerFileName,
  });

  final String vehicleNumber;
  final ExpenseType expenseType;
  final String billDate;
  final String billAmount;
  final String? billNo;
  final String? vendorName;
  final String status;
  final String? description;
  final String? mode;
  final String? fuelType;
  final String? speedometer;
  final Map<String, dynamic> extraFields;
  final List<int>? billFileBytes;
  final String? billFileName;
  final List<int>? odometerFileBytes;
  final String? odometerFileName;
}

@immutable
class ExpenseConfirmationData {
  const ExpenseConfirmationData({
    required this.expenseType,
    this.mode,
    this.fuelType,
    this.vehicleNumber,
    this.amount,
  });

  final ExpenseType expenseType;
  final String? mode;
  final String? fuelType;
  final String? vehicleNumber;
  final String? amount;
}
