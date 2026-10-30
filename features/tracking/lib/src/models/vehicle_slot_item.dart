import 'package:flutter/foundation.dart';

@immutable
class VehicleSlotItem {
  const VehicleSlotItem({
    required this.vehicleNumber,
    required this.driverName,
    required this.driverNumber,
    required this.mode,
    required this.routeNo,
    required this.routeDetailsId,
    required this.routeStartTime,
  });

  factory VehicleSlotItem.fromJson(Map<String, dynamic> json) => VehicleSlotItem(
        vehicleNumber: json['VehicleNumber'] as String? ?? '',
        driverName: json['DriverName'] as String? ?? '',
        driverNumber: json['DriverNumber']?.toString() ?? '',
        mode: json['Mode'] as String? ?? 'Pickup',
        routeNo: json['RouteNo'] as String? ?? '',
        routeDetailsId: (json['RouteDetailsId'] as num?)?.toInt() ?? 0,
        routeStartTime: json['RouteStartTime'] as String? ?? '',
      );

  final String driverName;
  final String driverNumber;
  final String mode;
  final int routeDetailsId;
  final String routeNo;
  final String routeStartTime;
  final String vehicleNumber;

  Map<String, dynamic> toJson() => {
        'VehicleNumber': vehicleNumber,
        'DriverName': driverName,
        'DriverNumber': driverNumber,
        'Mode': mode,
        'RouteNo': routeNo,
        'RouteDetailsId': routeDetailsId,
        'RouteStartTime': routeStartTime,
      };
}
