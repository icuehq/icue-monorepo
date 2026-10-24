// To parse this JSON data, do
//
//     final qrCleaningTaskResponse = qrCleaningTaskResponseFromJson(jsonString);

import 'dart:convert';

import 'facility_task.dart';

QrCleaningTaskResponse qrCleaningTaskResponseFromJson(String str) =>
    QrCleaningTaskResponse.fromJson(json.decode(str));

String qrCleaningTaskResponseToJson(QrCleaningTaskResponse data) =>
    json.encode(data.toJson());

class QrCleaningTaskResponse {
  QrCleaningTaskResponse({
    required this.err,
    required this.message,
    required this.data,
  });

  factory QrCleaningTaskResponse.fromJson(Map<String, dynamic> json) =>
      QrCleaningTaskResponse(
        err: json['err'],
        message: json['message'],
        data: Data.fromJson(json['data']),
      );

  final Data data;
  final bool err;
  final String message;

  QrCleaningTaskResponse copyWith({bool? err, String? message, Data? data}) =>
      QrCleaningTaskResponse(
        err: err ?? this.err,
        message: message ?? this.message,
        data: data ?? this.data,
      );

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': data.toJson(),
  };
}

class Data {
  Data({
    this.facility,
    this.tasks = const [],
    this.scheduledDate,
    this.assignedUserId,
    this.pagination,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    facility: json['facility'] is Map<String, dynamic>
        ? Facility.fromJson(json['facility'] as Map<String, dynamic>)
        : (json['Facility'] is Map<String, dynamic>
              ? Facility.fromJson(json['Facility'] as Map<String, dynamic>)
              : null),
    tasks: json['tasks'] is List
        ? List<FacilityTask>.from(
            (json['tasks'] as List).map(
              (x) => FacilityTask.fromJson(x as Map<String, dynamic>),
            ),
          )
        : (json['Tasks'] is List
              ? List<FacilityTask>.from(
                  (json['Tasks'] as List).map(
                    (x) => FacilityTask.fromJson(x as Map<String, dynamic>),
                  ),
                )
              : []),
    scheduledDate: json['ScheduledDate'] == null
        ? null
        : DateTime.tryParse(json['ScheduledDate'].toString()),
    assignedUserId: json['AssignedUserId'] is int
        ? json['AssignedUserId']
        : int.tryParse(json['AssignedUserId']?.toString() ?? ''),
    pagination: json['pagination'] is Map<String, dynamic>
        ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
        : (json['Pagination'] is Map<String, dynamic>
              ? Pagination.fromJson(json['Pagination'] as Map<String, dynamic>)
              : null),
  );

  final int? assignedUserId;
  final Facility? facility;
  final Pagination? pagination;
  final DateTime? scheduledDate;
  final List<FacilityTask> tasks;

  Data copyWith({
    Facility? facility,
    List<FacilityTask>? tasks,
    DateTime? scheduledDate,
    int? assignedUserId,
    Pagination? pagination,
  }) => Data(
    facility: facility ?? this.facility,
    tasks: tasks ?? this.tasks,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    assignedUserId: assignedUserId ?? this.assignedUserId,
    pagination: pagination ?? this.pagination,
  );

  Map<String, dynamic> toJson() => {
    'facility': facility?.toJson(),
    'tasks': List<dynamic>.from(tasks.map((x) => x.toJson())),
    'ScheduledDate': scheduledDate == null
        ? null
        : "${scheduledDate!.year.toString().padLeft(4, '0')}-${scheduledDate!.month.toString().padLeft(2, '0')}-${scheduledDate!.day.toString().padLeft(2, '0')}",
    'AssignedUserId': assignedUserId,
    'pagination': pagination?.toJson(),
  };
}

class Facility {
  Facility({
    this.id,
    this.organizationId,
    this.zoneId,
    this.branchId,
    this.facilityTypeId,
    this.parentFacilityId,
    this.name = '',
    this.code = '',
    this.description = '',
    this.facilityPath,
    this.location = '',
    this.area,
    this.quantity,
    this.qrCode = '',
    this.isActive = true,
    this.createdBy,
    this.createdDate,
  });

  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
    id: json['Id'] is int
        ? json['Id']
        : int.tryParse(json['Id']?.toString() ?? ''),
    organizationId: json['OrganizationId'] is int
        ? json['OrganizationId']
        : int.tryParse(json['OrganizationId']?.toString() ?? ''),
    zoneId: json['ZoneId'] is int
        ? json['ZoneId']
        : int.tryParse(json['ZoneId']?.toString() ?? ''),
    branchId: json['BranchId'] is int
        ? json['BranchId']
        : int.tryParse(json['BranchId']?.toString() ?? ''),
    facilityTypeId: json['FacilityTypeId'] is int
        ? json['FacilityTypeId']
        : int.tryParse(json['FacilityTypeId']?.toString() ?? ''),
    parentFacilityId: json['ParentFacilityId'] is int
        ? json['ParentFacilityId']
        : int.tryParse(json['ParentFacilityId']?.toString() ?? ''),
    name: json['Name']?.toString() ?? '',
    code: json['Code']?.toString() ?? '',
    description: json['Description']?.toString() ?? '',
    facilityPath:
        json['FacilityPath']?.toString() ??
        json['facilityPath']?.toString() ??
        '',
    location: json['Location']?.toString() ?? '',
    area: json['Area'],
    quantity: json['Quantity'],
    qrCode: json['QrCode']?.toString() ?? '',
    isActive: json['IsActive'] == true || json['IsActive'] == 1,
    createdBy: json['CreatedBy']?.toString(),
    createdDate: json['CreatedDate'] == null
        ? null
        : DateTime.tryParse(json['CreatedDate'].toString()),
  );

  final dynamic area;
  final int? branchId;
  final String code;
  final String? createdBy;
  final DateTime? createdDate;
  final String description;
  final String? facilityPath;
  final int? facilityTypeId;
  final int? id;
  final bool isActive;
  final String location;
  final String name;
  final int? organizationId;
  final int? parentFacilityId;
  final String qrCode;
  final dynamic quantity;
  final int? zoneId;

  Facility copyWith({
    int? id,
    int? organizationId,
    int? zoneId,
    int? branchId,
    int? facilityTypeId,
    int? parentFacilityId,
    String? name,
    String? code,
    String? description,
    String? facilityPath,
    String? location,
    dynamic area,
    dynamic quantity,
    String? qrCode,
    bool? isActive,
    String? createdBy,
    DateTime? createdDate,
  }) => Facility(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    zoneId: zoneId ?? this.zoneId,
    branchId: branchId ?? this.branchId,
    facilityTypeId: facilityTypeId ?? this.facilityTypeId,
    parentFacilityId: parentFacilityId ?? this.parentFacilityId,
    name: name ?? this.name,
    code: code ?? this.code,
    description: description ?? this.description,
    facilityPath: facilityPath ?? this.facilityPath,
    location: location ?? this.location,
    area: area ?? this.area,
    quantity: quantity ?? this.quantity,
    qrCode: qrCode ?? this.qrCode,
    isActive: isActive ?? this.isActive,
    createdBy: createdBy ?? this.createdBy,
    createdDate: createdDate ?? this.createdDate,
  );

  Map<String, dynamic> toJson() => {
    'Id': id,
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'FacilityTypeId': facilityTypeId,
    'ParentFacilityId': parentFacilityId,
    'Name': name,
    'Code': code,
    'Description': description,
    'FacilityPath': facilityPath,
    'Location': location,
    'Area': area,
    'Quantity': quantity,
    'QrCode': qrCode,
    'IsActive': isActive,
    'CreatedBy': createdBy,
    'CreatedDate': createdDate?.toIso8601String(),
  };
}
