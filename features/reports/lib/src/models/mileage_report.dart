import 'package:flutter/foundation.dart';

@immutable
class MileageReportItem {
  const MileageReportItem({
    required this.vehicleNumber,
    required this.routeNo,
    this.actualTotalKmsDriven = 0,
    this.totalNoOfKmReadingsTaken = 0,
    this.speedometerDiff = '',
  });

  factory MileageReportItem.fromJson(Map<String, dynamic> json) =>
      MileageReportItem(
        vehicleNumber: json['VehicleNumber'] as String? ?? '',
        routeNo: json['RouteNo'] as String? ?? '',
        actualTotalKmsDriven: json['ActualTotalKmsDriven'] is num
            ? json['ActualTotalKmsDriven'] as num
            : num.tryParse(json['ActualTotalKmsDriven']?.toString() ?? '0') ?? 0,
        totalNoOfKmReadingsTaken:
            (json['TotalNoOfKMReadingsTaken'] as num?)?.toInt() ?? 0,
        speedometerDiff: json['SPEEDOMETERDIFF']?.toString() ?? '',
      );

  final num actualTotalKmsDriven;
  final String routeNo;
  final String speedometerDiff;
  final int totalNoOfKmReadingsTaken;
  final String vehicleNumber;

  Map<String, dynamic> toJson() => {
        'VehicleNumber': vehicleNumber,
        'RouteNo': routeNo,
        'ActualTotalKmsDriven': actualTotalKmsDriven,
        'TotalNoOfKMReadingsTaken': totalNoOfKmReadingsTaken,
        'SPEEDOMETERDIFF': speedometerDiff,
      };
}
