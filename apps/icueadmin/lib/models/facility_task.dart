// To parse this JSON data, do
//
//     final facilityTasksResponse = facilityTasksResponseFromJson(jsonString);

import 'dart:convert';

import 'facility_task_status.dart';

FacilityTasksResponse facilityTasksResponseFromJson(String str) =>
    FacilityTasksResponse.fromJson(json.decode(str));

String facilityTasksResponseToJson(FacilityTasksResponse data) =>
    json.encode(data.toJson());

class FacilityTasksResponse {
  FacilityTasksResponse({
    required this.err,
    required this.message,
    required this.data,
    this.pagination,
  });

  factory FacilityTasksResponse.fromJson(Map<String, dynamic> json) =>
      FacilityTasksResponse(
        err: json['err'] == true,
        message: json['message']?.toString() ?? '',
        data: json['data'] == null || json['data'] is! List
            ? []
            : List<FacilityTask>.from(
                (json['data'] as List).map(
                  (x) => FacilityTask.fromJson(x as Map<String, dynamic>),
                ),
              ),
        pagination:
            json['pagination'] != null &&
                json['pagination'] is Map<String, dynamic>
            ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
            : null,
      );

  final List<FacilityTask> data;
  final bool err;
  final String message;
  final Pagination? pagination;

  FacilityTasksResponse copyWith({
    bool? err,
    String? message,
    List<FacilityTask>? data,
    Pagination? pagination,
  }) => FacilityTasksResponse(
    err: err ?? this.err,
    message: message ?? this.message,
    data: data ?? this.data,
    pagination: pagination ?? this.pagination,
  );

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': List<dynamic>.from(data.map((x) => x.toJson())),
    'pagination': pagination?.toJson(),
  };
}

class FacilityTask {
  FacilityTask({
    this.id,
    this.organizationId,
    this.zoneId,
    this.branchId,
    this.facilityId,
    this.facilityTypeId,
    this.scheduleId,
    this.scheduleName,
    this.cleaningTemplateId,
    this.templateVersion,
    this.assignedRole,
    this.assignedUserId,
    this.assignedUser,
    this.scheduledDate,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.status = '',
    this.facilityPath,
    this.createdBy,
    this.createdDate,
    this.updatedBy,
    this.updatedDate,
    this.startedAt,
    this.startedBy,
  });

  factory FacilityTask.fromJson(Map<String, dynamic> json) => FacilityTask(
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
    facilityId: json['FacilityId'] is int
        ? json['FacilityId']
        : int.tryParse(json['FacilityId']?.toString() ?? ''),
    facilityTypeId: json['FacilityTypeId'] is int
        ? json['FacilityTypeId']
        : int.tryParse(json['FacilityTypeId']?.toString() ?? ''),
    scheduleId: json['ScheduleId'] is int
        ? json['ScheduleId']
        : int.tryParse(json['ScheduleId']?.toString() ?? ''),
    scheduleName: json['ScheduleName']?.toString(),
    cleaningTemplateId: json['CleaningTemplateId'] is int
        ? json['CleaningTemplateId']
        : int.tryParse(json['CleaningTemplateId']?.toString() ?? ''),
    templateVersion: json['TemplateVersion'] is int
        ? json['TemplateVersion']
        : int.tryParse(json['TemplateVersion']?.toString() ?? ''),
    assignedRole: json['AssignedRole']?.toString(),
    assignedUserId: json['AssignedUserId'] is int
        ? json['AssignedUserId']
        : int.tryParse(json['AssignedUserId']?.toString() ?? ''),
    assignedUser: json['AssignedUser']?.toString(),
    scheduledDate: json['ScheduledDate'] == null
        ? null
        : DateTime.tryParse(json['ScheduledDate'].toString()),
    scheduledStartTime: json['ScheduledStartTime']?.toString(),
    scheduledEndTime: json['ScheduledEndTime']?.toString(),
    status: json['Status']?.toString() ?? '',
    facilityPath:
        json['FacilityPath']?.toString() ?? json['facilityPath']?.toString(),
    createdBy: json['CreatedBy']?.toString(),
    createdDate: json['CreatedDate'] == null
        ? null
        : DateTime.tryParse(json['CreatedDate'].toString()),
    updatedBy: json['UpdatedBy']?.toString(),
    updatedDate: json['UpdatedDate'] == null
        ? null
        : DateTime.tryParse(json['UpdatedDate'].toString()),
    startedAt: json['StartedAt'] == null
        ? null
        : DateTime.tryParse(json['StartedAt'].toString()),
    startedBy: json['StartedBy']?.toString(),
  );

  FacilityTaskStatus get taskStatus => FacilityTaskStatus.fromString(status);

  final String? assignedRole;
  final String? assignedUser;
  final int? assignedUserId;
  final int? branchId;
  final int? cleaningTemplateId;
  final String? createdBy;
  final DateTime? createdDate;
  final int? facilityId;
  final int? facilityTypeId;
  final int? id;
  final int? organizationId;
  final int? scheduleId;
  final String? scheduleName;
  final DateTime? scheduledDate;
  final String? scheduledEndTime;
  final String? scheduledStartTime;
  final DateTime? startedAt;
  final String? startedBy;
  final String? facilityPath;
  final String status;
  final int? templateVersion;
  final String? updatedBy;
  final DateTime? updatedDate;
  final int? zoneId;

  FacilityTask copyWith({
    int? id,
    int? organizationId,
    int? zoneId,
    int? branchId,
    int? facilityId,
    int? facilityTypeId,
    int? scheduleId,
    String? scheduleName,
    int? cleaningTemplateId,
    int? templateVersion,
    String? assignedRole,
    int? assignedUserId,
    String? assignedUser,
    DateTime? scheduledDate,
    String? scheduledStartTime,
    String? scheduledEndTime,
    String? status,
    String? facilityPath,
    String? createdBy,
    DateTime? createdDate,
    String? updatedBy,
    DateTime? updatedDate,
    DateTime? startedAt,
    String? startedBy,
  }) => FacilityTask(
    id: id ?? this.id,
    organizationId: organizationId ?? this.organizationId,
    zoneId: zoneId ?? this.zoneId,
    branchId: branchId ?? this.branchId,
    facilityId: facilityId ?? this.facilityId,
    facilityTypeId: facilityTypeId ?? this.facilityTypeId,
    scheduleId: scheduleId ?? this.scheduleId,
    scheduleName: scheduleName ?? this.scheduleName,
    cleaningTemplateId: cleaningTemplateId ?? this.cleaningTemplateId,
    templateVersion: templateVersion ?? this.templateVersion,
    assignedRole: assignedRole ?? this.assignedRole,
    assignedUserId: assignedUserId ?? this.assignedUserId,
    assignedUser: assignedUser ?? this.assignedUser,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
    scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
    status: status ?? this.status,
    facilityPath: facilityPath ?? this.facilityPath,
    createdBy: createdBy ?? this.createdBy,
    createdDate: createdDate ?? this.createdDate,
    updatedBy: updatedBy ?? this.updatedBy,
    updatedDate: updatedDate ?? this.updatedDate,
    startedAt: startedAt ?? this.startedAt,
    startedBy: startedBy ?? this.startedBy,
  );

  Map<String, dynamic> toJson() => {
    'Id': id,
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'FacilityId': facilityId,
    'FacilityTypeId': facilityTypeId,
    'ScheduleId': scheduleId,
    'ScheduleName': scheduleName,
    'CleaningTemplateId': cleaningTemplateId,
    'TemplateVersion': templateVersion,
    'AssignedRole': assignedRole,
    'AssignedUserId': assignedUserId,
    'AssignedUser': assignedUser,
    'ScheduledDate': scheduledDate == null
        ? null
        : "${scheduledDate!.year.toString().padLeft(4, '0')}-${scheduledDate!.month.toString().padLeft(2, '0')}-${scheduledDate!.day.toString().padLeft(2, '0')}",
    'ScheduledStartTime': scheduledStartTime,
    'ScheduledEndTime': scheduledEndTime,
    'Status': status,
    'FacilityPath': facilityPath,
    'CreatedBy': createdBy,
    'CreatedDate': createdDate?.toIso8601String(),
    'UpdatedBy': updatedBy,
    'UpdatedDate': updatedDate?.toIso8601String(),
    'StartedAt': startedAt?.toIso8601String(),
    'StartedBy': startedBy,
  };
}

class Pagination {
  Pagination({
    required this.totalCount,
    required this.pageNumber,
    required this.pageSize,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    totalCount: json['totalCount'] is int
        ? json['totalCount']
        : int.tryParse(json['totalCount']?.toString() ?? '') ?? 0,
    pageNumber: json['pageNumber'] is int
        ? json['pageNumber']
        : int.tryParse(json['pageNumber']?.toString() ?? '') ?? 1,
    pageSize: json['pageSize'] is int
        ? json['pageSize']
        : int.tryParse(json['pageSize']?.toString() ?? '') ?? 20,
    totalPages: json['totalPages'] is int
        ? json['totalPages']
        : int.tryParse(json['totalPages']?.toString() ?? '') ?? 1,
  );

  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  Pagination copyWith({
    int? totalCount,
    int? pageNumber,
    int? pageSize,
    int? totalPages,
  }) => Pagination(
    totalCount: totalCount ?? this.totalCount,
    pageNumber: pageNumber ?? this.pageNumber,
    pageSize: pageSize ?? this.pageSize,
    totalPages: totalPages ?? this.totalPages,
  );

  Map<String, dynamic> toJson() => {
    'totalCount': totalCount,
    'pageNumber': pageNumber,
    'pageSize': pageSize,
    'totalPages': totalPages,
  };
}
