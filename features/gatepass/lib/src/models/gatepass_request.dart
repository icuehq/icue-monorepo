import 'package:flutter/foundation.dart';

@immutable
class GatePassRequest {
  const GatePassRequest({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.zoneId,
    required this.personType,
    required this.gatePassType,
    required this.datumClass,
    required this.section,
    required this.admissionNumber,
    required this.name,
    required this.personId,
    required this.isHostelite,
    required this.hostelType,
    required this.requestDate,
    required this.requestTime,
    required this.requestDt,
  });

  factory GatePassRequest.fromJson(Map<String, dynamic> json) =>
      GatePassRequest(
        id: (json['Id'] as num?)?.toInt() ?? 0,
        organizationId: (json['OrganizationId'] as num?)?.toInt() ?? 0,
        branchId: (json['BranchId'] as num?)?.toInt() ?? 0,
        zoneId: (json['ZoneId'] as num?)?.toInt() ?? 0,
        personType: json['PersonType'] as String? ?? '',
        gatePassType: json['GatePassType'] as String? ?? '',
        datumClass: json['Class'] as String? ?? '',
        section: json['Section'] as String? ?? '',
        admissionNumber: json['AdmissionNumber'] as String? ?? '',
        name: json['Name'] as String? ?? '',
        personId: (json['PersonId'] as num?)?.toInt() ?? 0,
        isHostelite: json['IsHostelite'] as bool? ?? false,
        hostelType: json['HostelType'] as String? ?? '',
        requestDate: json['RequestDate'] as String? ?? '',
        requestTime: json['RequestTime'] as String? ?? '',
        requestDt: json['RequestDt'] as String? ?? '',
      );

  final String admissionNumber;
  final int branchId;
  final String datumClass;
  final String gatePassType;
  final String hostelType;
  final int id;
  final bool isHostelite;
  final String name;
  final int organizationId;
  final int personId;
  final String personType;
  final String requestDate;
  final String requestDt;
  final String requestTime;
  final String section;
  final int zoneId;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'OrganizationId': organizationId,
    'BranchId': branchId,
    'ZoneId': zoneId,
    'PersonType': personType,
    'GatePassType': gatePassType,
    'Class': datumClass,
    'Section': section,
    'AdmissionNumber': admissionNumber,
    'Name': name,
    'PersonId': personId,
    'IsHostelite': isHostelite,
    'HostelType': hostelType,
    'RequestDate': requestDate,
    'RequestTime': requestTime,
    'RequestDt': requestDt,
  };
}

@immutable
class GatePassRequestsResponse {
  const GatePassRequestsResponse({
    this.err = false,
    this.message = '',
    this.data = const <GatePassRequest>[],
  });

  factory GatePassRequestsResponse.fromJson(Map<String, dynamic> json) =>
      GatePassRequestsResponse(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data:
            (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(GatePassRequest.fromJson)
                .toList() ??
            const <GatePassRequest>[],
      );

  final List<GatePassRequest> data;
  final bool err;
  final String message;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': data.map((x) => x.toJson()).toList(),
  };
}
