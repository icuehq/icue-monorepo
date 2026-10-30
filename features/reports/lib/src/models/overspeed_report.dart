import 'package:flutter/foundation.dart';

@immutable
class OverSpeedDatum {
  const OverSpeedDatum({
    required this.speed,
    required this.gpsTime,
  });

  factory OverSpeedDatum.fromJson(Map<String, dynamic> json) => OverSpeedDatum(
        speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
        gpsTime: json['gpsTime'] is num
            ? (json['gpsTime'] as num).toInt()
            : int.tryParse(json['gpsTime']?.toString() ?? '0') ?? 0,
      );

  final double speed;
  final int gpsTime;

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'gpsTime': gpsTime,
      };
}

@immutable
class OverSpeedReportItem {
  const OverSpeedReportItem({
    required this.vehicleNumber,
    required this.mode,
    required this.routeNo,
    this.driverName = '',
    this.driverMobile = '',
    this.startPoint = '',
    this.endPoint = '',
    this.startTime = '',
    this.endTime = '',
    this.startDate = '',
    this.averageSpeed = 0.0,
    this.overSpeedData = const <OverSpeedDatum>[],
  });

  factory OverSpeedReportItem.fromJson(Map<String, dynamic> json) =>
      OverSpeedReportItem(
        vehicleNumber: json['VehicleNumber'] as String? ?? '',
        driverName: json['DriverName'] as String? ?? '',
        driverMobile: json['DriverMobile']?.toString() ?? '',
        mode: json['Mode'] as String? ?? '',
        routeNo: json['RouteNo'] as String? ?? '',
        startPoint: json['StartPoint'] as String? ?? '',
        endPoint: json['EndPoint'] as String? ?? '',
        startTime: json['StartTime'] as String? ?? '',
        endTime: json['EndTime'] as String? ?? '',
        startDate: json['StartDate'] as String? ?? '',
        averageSpeed: (json['AverageSpeed'] as num?)?.toDouble() ?? 0.0,
        overSpeedData: (json['OverSpeedData'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(OverSpeedDatum.fromJson)
                .toList() ??
            const <OverSpeedDatum>[],
      );

  final double averageSpeed;
  final String driverMobile;
  final String driverName;
  final String endPoint;
  final String endTime;
  final String mode;
  final List<OverSpeedDatum> overSpeedData;
  final String routeNo;
  final String startDate;
  final String startPoint;
  final String startTime;
  final String vehicleNumber;

  Map<String, dynamic> toJson() => {
        'VehicleNumber': vehicleNumber,
        'DriverName': driverName,
        'DriverMobile': driverMobile,
        'Mode': mode,
        'RouteNo': routeNo,
        'StartPoint': startPoint,
        'EndPoint': endPoint,
        'StartTime': startTime,
        'EndTime': endTime,
        'StartDate': startDate,
        'AverageSpeed': averageSpeed,
        'OverSpeedData': overSpeedData.map((x) => x.toJson()).toList(),
      };
}

/// Flattened overspeed violation record for presentation in lists.
@immutable
class OverSpeedRecord {
  const OverSpeedRecord({
    required this.vehicleNumber,
    required this.mode,
    required this.routeNo,
    required this.averageSpeed,
    required this.speed,
    required this.gpsTime,
    this.driverName = '',
    this.driverMobile = '',
  });

  final double averageSpeed;
  final String driverMobile;
  final String driverName;
  final DateTime gpsTime;
  final String mode;
  final String routeNo;
  final double speed;
  final String vehicleNumber;
}
