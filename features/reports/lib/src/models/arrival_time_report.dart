import 'package:flutter/foundation.dart';
import 'package:reports/src/models/report_metadata.dart';

@immutable
class ArrivalTimeItem {
  const ArrivalTimeItem({
    required this.vehicleNumber,
    required this.routeNo,
    required this.mode,
    required this.startDate,
    required this.startTime,
    this.endDate,
    this.endTime,
    this.arrivalTime,
  });

  factory ArrivalTimeItem.fromJson(Map<String, dynamic> json) =>
      ArrivalTimeItem(
        vehicleNumber: json['VehicleNumber'] as String? ?? '',
        routeNo: json['RouteNo'] as String? ?? '',
        mode: json['Mode'] as String? ?? '',
        startDate: json['StartDate'] as String? ?? '',
        startTime: json['StartTime'] as String? ?? '',
        endDate: json['EndDate'] as String?,
        endTime: json['EndTime'] as String?,
        arrivalTime: json['ArrivalTime'] as String?,
      );

  final String? arrivalTime;
  final String? endDate;
  final String? endTime;
  final String mode;
  final String routeNo;
  final String startDate;
  final String startTime;
  final String vehicleNumber;

  Map<String, dynamic> toJson() => {
        'VehicleNumber': vehicleNumber,
        'RouteNo': routeNo,
        'Mode': mode,
        'StartDate': startDate,
        'StartTime': startTime,
        'EndDate': endDate,
        'EndTime': endTime,
        'ArrivalTime': arrivalTime,
      };
}

@immutable
class ArrivalTimeReportResponse {
  const ArrivalTimeReportResponse({
    this.metadata = const ReportMetadata(),
    this.data = const <ArrivalTimeItem>[],
    this.err = false,
    this.message = '',
  });

  factory ArrivalTimeReportResponse.fromJson(Map<String, dynamic> json) {
    ReportMetadata metadata = const ReportMetadata();
    List<ArrivalTimeItem> items = const <ArrivalTimeItem>[];

    if (json['data'] is Map<String, dynamic>) {
      final innerData = json['data'] as Map<String, dynamic>;
      if (innerData['metadata'] is Map) {
        metadata = ReportMetadata.fromJson(
          innerData['metadata'] as Map<String, dynamic>,
        );
      }
      if (innerData['data'] is List) {
        items = (innerData['data'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(ArrivalTimeItem.fromJson)
            .toList();
      }
    }

    return ArrivalTimeReportResponse(
      metadata: metadata,
      data: items,
      err: json['err'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  final List<ArrivalTimeItem> data;
  final bool err;
  final String message;
  final ReportMetadata metadata;

  Map<String, dynamic> toJson() => {
        'err': err,
        'message': message,
        'data': {
          'metadata': metadata.toJson(),
          'data': data.map((x) => x.toJson()).toList(),
        },
      };
}
