import 'package:flutter/foundation.dart';
import 'package:reports/src/models/report_metadata.dart';

@immutable
class CleanedPartItem {
  const CleanedPartItem({this.id, this.name = '', this.status = ''});

  factory CleanedPartItem.fromJson(Map<String, dynamic> json) =>
      CleanedPartItem(
        id: json['Id'] as int?,
        name: json['Name'] as String? ?? '',
        status: json['Status'] as String? ?? '',
      );

  final int? id;
  final String name;
  final String status;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name, 'Status': status};
}

@immutable
class CleaningReportData {
  const CleaningReportData({
    this.vehicleNo = '',
    this.cleanedData = const <CleanedPartItem>[],
    this.createdBy = '',
    this.createdDate = '',
    this.createdTime = '',
    this.source = '',
    this.photos = const <String>[],
  });

  factory CleaningReportData.fromJson(Map<String, dynamic> json) =>
      CleaningReportData(
        vehicleNo: json['VehicleNo'] as String? ?? '',
        cleanedData:
            (json['CleanedData'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(CleanedPartItem.fromJson)
                .toList() ??
            const <CleanedPartItem>[],
        createdBy: json['CreatedBy'] as String? ?? '',
        createdDate: json['CreatedDate'] as String? ?? '',
        createdTime: json['CreatedTime'] as String? ?? '',
        source: json['Source'] as String? ?? '',
        photos:
            (json['Photos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
      );

  final List<CleanedPartItem> cleanedData;
  final String createdBy;
  final String createdDate;
  final String createdTime;
  final List<String> photos;
  final String source;
  final String vehicleNo;

  Map<String, dynamic> toJson() => {
    'VehicleNo': vehicleNo,
    'CleanedData': cleanedData.map((x) => x.toJson()).toList(),
    'CreatedBy': createdBy,
    'CreatedDate': createdDate,
    'Source': source,
    'CreatedTime': createdTime,
    'Photos': photos,
  };
}

@immutable
class CleaningReportResponse {
  const CleaningReportResponse({
    this.metadata = const ReportMetadata(),
    this.data = const <CleaningReportData>[],
    this.err = false,
    this.message = '',
  });

  factory CleaningReportResponse.fromJson(Map<String, dynamic> json) =>
      CleaningReportResponse(
        metadata: json['metadata'] is Map
            ? ReportMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
            : const ReportMetadata(),
        data:
            (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(CleaningReportData.fromJson)
                .toList() ??
            const <CleaningReportData>[],
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );

  final List<CleaningReportData> data;
  final bool err;
  final String message;
  final ReportMetadata metadata;

  Map<String, dynamic> toJson() => {
    'metadata': metadata.toJson(),
    'data': data.map((x) => x.toJson()).toList(),
    'err': err,
    'message': message,
  };
}
