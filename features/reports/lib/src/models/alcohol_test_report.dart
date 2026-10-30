import 'package:flutter/foundation.dart';
import 'package:reports/src/models/report_metadata.dart';

@immutable
class AlcoholTestRecord {
  const AlcoholTestRecord({
    this.id = 0,
    this.submittedDate = '',
    this.submittedTime = '',
    this.personType = 'DRIVER',
    this.personName = '',
    this.personMobile = '',
    this.alcoholTest = '',
    this.alcoholTestReading = 0.0,
    this.imageUrl = '',
    this.createdBy = '',
  });

  factory AlcoholTestRecord.fromJson(Map<String, dynamic> json) {
    String name = '';
    String mobile = '';
    if (json['PersonInfo'] is Map) {
      final p = json['PersonInfo'] as Map<dynamic, dynamic>;
      name = p['Name'] as String? ?? '';
      mobile = p['Mobile']?.toString() ?? '';
    } else {
      name = json['PersonName'] as String? ?? '';
      mobile = json['PersonMobile']?.toString() ?? '';
    }

    return AlcoholTestRecord(
      id: (json['Id'] as num?)?.toInt() ?? 0,
      submittedDate: json['SubmittedDate'] as String? ?? '',
      submittedTime: json['SubmittedTime'] as String? ?? '',
      personType: json['PersonType'] as String? ?? 'DRIVER',
      personName: name,
      personMobile: mobile,
      alcoholTest: json['AlcoholTest'] as String? ?? '',
      alcoholTestReading:
          (json['AlcoholTestReading'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['ImageUrl'] as String? ?? '',
      createdBy: json['CreatedBy'] as String? ?? '',
    );
  }

  final String alcoholTest;
  final double alcoholTestReading;
  final String createdBy;
  final int id;
  final String imageUrl;
  final String personMobile;
  final String personName;
  final String personType;
  final String submittedDate;
  final String submittedTime;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'SubmittedDate': submittedDate,
    'SubmittedTime': submittedTime,
    'PersonType': personType,
    'PersonInfo': {'Name': personName, 'Mobile': personMobile},
    'AlcoholTest': alcoholTest,
    'AlcoholTestReading': alcoholTestReading,
    'ImageUrl': imageUrl,
    'CreatedBy': createdBy,
  };
}

@immutable
class AlcoholReportResponse {
  const AlcoholReportResponse({
    this.metadata = const ReportMetadata(),
    this.data = const <AlcoholTestRecord>[],
    this.err = false,
    this.message = '',
  });

  factory AlcoholReportResponse.fromJson(Map<String, dynamic> json) =>
      AlcoholReportResponse(
        metadata: json['metadata'] is Map
            ? ReportMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
            : const ReportMetadata(),
        data:
            (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(AlcoholTestRecord.fromJson)
                .toList() ??
            const <AlcoholTestRecord>[],
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );

  final List<AlcoholTestRecord> data;
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
