import 'package:flutter/foundation.dart';

@immutable
class FuelReading {
  const FuelReading({
    required this.date,
    required this.time,
    required this.dateTime,
    this.speedometer,
    this.fuelFilled,
    this.image,
    this.imgMode,
  });

  factory FuelReading.fromJson(Map<String, dynamic> json) => FuelReading(
    speedometer: json['Speedometer'] as num?,
    fuelFilled: json['FuelFilled'] as num?,
    image: json['Image'] as String?,
    date: json['Date'] as String? ?? '',
    time: json['Time'] as String? ?? '',
    imgMode: json['ImgMode'] as String?,
    dateTime: json['DateTime'] != null
        ? DateTime.tryParse(json['DateTime'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );

  final String date;
  final DateTime dateTime;
  final num? fuelFilled;
  final String? image;
  final String? imgMode;
  final num? speedometer;
  final String time;

  Map<String, dynamic> toJson() => {
    'Speedometer': speedometer,
    'FuelFilled': fuelFilled,
    'Image': image,
    'Date': date,
    'Time': time,
    'ImgMode': imgMode,
    'DateTime': dateTime.toIso8601String(),
  };
}

@immutable
class FuelReport {
  const FuelReport({
    this.id = '',
    this.zoneId = 0,
    this.branchId = 0,
    this.vehicleNumber = '',
    this.fuelReadings = const <FuelReading>[],
    this.totalNoOfFuelReadings = 0,
  });

  factory FuelReport.fromJson(Map<String, dynamic> json) => FuelReport(
    id: json['_id'] as String? ?? '',
    zoneId: (json['ZoneId'] as num?)?.toInt() ?? 0,
    branchId: (json['BranchId'] as num?)?.toInt() ?? 0,
    vehicleNumber: json['VehicleNumber'] as String? ?? '',
    fuelReadings:
        (json['FUELREADING'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(FuelReading.fromJson)
            .toList() ??
        const <FuelReading>[],
    totalNoOfFuelReadings:
        (json['TotalNoOfFuelReadings'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final int zoneId;
  final int branchId;
  final String vehicleNumber;
  final List<FuelReading> fuelReadings;
  final int totalNoOfFuelReadings;

  Map<String, dynamic> toJson() => {
    '_id': id,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'VehicleNumber': vehicleNumber,
    'FUELREADING': fuelReadings.map((x) => x.toJson()).toList(),
    'TotalNoOfFuelReadings': totalNoOfFuelReadings,
  };
}
