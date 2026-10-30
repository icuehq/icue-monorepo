import 'package:flutter/foundation.dart';

@immutable
class AlcoholTestItem {
  const AlcoholTestItem({
    required this.id,
    this.submittedDate = '',
    this.submittedTime = '',
    this.personType = 'DRIVER',
    this.personName = '',
    this.personMobile = '',
    this.alcoholTest = 'PASSED',
    this.alcoholTestReading = 0.0,
    this.imageUrl,
    this.createdBy = '',
  });

  factory AlcoholTestItem.fromJson(Map<String, dynamic> json) {
    String name = '';
    String mobile = '';
    if (json['PersonInfo'] is Map) {
      final personInfo = json['PersonInfo'] as Map<dynamic, dynamic>;
      name = personInfo['Name'] as String? ?? '';
      mobile = personInfo['Mobile']?.toString() ?? '';
    } else {
      name = json['PrsnName'] as String? ?? '';
      mobile = json['PrsnMobile']?.toString() ?? '';
    }

    return AlcoholTestItem(
      id: json['Id'] as int? ?? 0,
      submittedDate: json['SubmittedDate'] as String? ?? '',
      submittedTime: json['SubmittedTime'] as String? ?? '',
      personType: json['PersonType'] as String? ?? 'DRIVER',
      personName: name,
      personMobile: mobile,
      alcoholTest: json['AlcoholTest'] as String? ?? 'PASSED',
      alcoholTestReading:
          (json['AlcoholTestReading'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['ImageUrl'] as String?,
      createdBy: json['CreatedBy'] as String? ?? '',
    );
  }

  final int id;
  final String submittedDate;
  final String submittedTime;
  final String personType;
  final String personName;
  final String personMobile;
  final String alcoholTest;
  final double alcoholTestReading;
  final String? imageUrl;
  final String createdBy;

  Map<String, dynamic> toJson() => {
        'Id': id,
        'SubmittedDate': submittedDate,
        'SubmittedTime': submittedTime,
        'PersonType': personType,
        'PersonName': personName,
        'PersonMobile': personMobile,
        'AlcoholTest': alcoholTest,
        'AlcoholTestReading': alcoholTestReading,
        'ImageUrl': ?imageUrl,
        'CreatedBy': createdBy,
      };
}

@immutable
class AlcoholTestResponse {
  const AlcoholTestResponse({
    this.err = false,
    this.message = '',
    this.total = 0,
    this.data = const <AlcoholTestItem>[],
  });

  factory AlcoholTestResponse.fromJson(Map<String, dynamic> json) {
    int totalCount = 0;
    if (json['metadata'] is Map) {
      final meta = json['metadata'] as Map<dynamic, dynamic>;
      totalCount = (meta['total'] as num?)?.toInt() ?? 0;
    }

    return AlcoholTestResponse(
      err: json['err'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      total: totalCount,
      data: (json['data'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AlcoholTestItem.fromJson)
              .toList() ??
          const <AlcoholTestItem>[],
    );
  }

  final bool err;
  final String message;
  final int total;
  final List<AlcoholTestItem> data;
}

@immutable
class AlcoholTestSubmissionRequest {
  const AlcoholTestSubmissionRequest({
    required this.personId,
    required this.personName,
    required this.personMobile,
    required this.reading,
    required this.status, // 'PASSED' or 'FAILED'
    this.fileBytes,
    this.fileName,
  });

  final int personId;
  final String personName;
  final String personMobile;
  final double reading;
  final String status;
  final List<int>? fileBytes;
  final String? fileName;
}
