// To parse this JSON data, do
//
//     final cleaningTaskResponse = cleaningTaskResponseFromJson(jsonString);

import 'dart:convert';

import 'facility_task_status.dart';

CleaningTaskResponse cleaningTaskResponseFromJson(String str) =>
    CleaningTaskResponse.fromJson(json.decode(str));

String cleaningTaskResponseToJson(CleaningTaskResponse data) =>
    json.encode(data.toJson());

class CleaningTaskResponse {
  CleaningTaskResponse({this.err, this.message, this.data});

  factory CleaningTaskResponse.fromJson(Map<String, dynamic> json) =>
      CleaningTaskResponse(
        err: json['err'],
        message: json['message'],
        data: json['data'] == null ? null : CleaningTask.fromJson(json['data']),
      );

  final CleaningTask? data;
  final bool? err;
  final String? message;

  CleaningTaskResponse copyWith({
    bool? err,
    String? message,
    CleaningTask? data,
  }) => CleaningTaskResponse(
    err: err ?? this.err,
    message: message ?? this.message,
    data: data ?? this.data,
  );

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': data?.toJson(),
  };
}

class CleaningTask {
  CleaningTask({
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
    this.templateGroupId,
    this.assignedRole,
    this.assignedUserId,
    this.assignedUser,
    this.scheduledDate,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.checklistSnapshot,
    this.checklistResults,
    this.beforePhotos,
    this.afterPhotos,
    this.status,
    this.createdBy,
    this.createdDate,
    this.startedAt,
    this.startedBy,
    this.startedByUserId,
    this.updatedBy,
    this.updatedDate,
    this.failedAt,
    this.failedBy,
    this.failedByUserId,
    this.failureRemarks,
    this.completedAt,
    this.completedBy,
    this.completedByUserId,
    this.completionRemarks,
    this.skipRemarks,
    this.skippedAt,
    this.skippedBy,
    this.skippedByUserId,
  });

  factory CleaningTask.fromJson(Map<String, dynamic> json) => CleaningTask(
    id: json['Id'],
    organizationId: json['OrganizationId'],
    zoneId: json['ZoneId'],
    branchId: json['BranchId'],
    facilityId: json['FacilityId'],
    facilityTypeId: json['FacilityTypeId'],
    scheduleId: json['ScheduleId'],
    scheduleName: json['ScheduleName'],
    cleaningTemplateId: json['CleaningTemplateId'],
    templateVersion: json['TemplateVersion'],
    templateGroupId: json['TemplateGroupId'],
    assignedRole: json['AssignedRole'],
    assignedUserId: json['AssignedUserId'],
    assignedUser: json['AssignedUser'],
    scheduledDate: json['ScheduledDate'] == null
        ? null
        : DateTime.parse(json['ScheduledDate']),
    scheduledStartTime: json['ScheduledStartTime'],
    scheduledEndTime: json['ScheduledEndTime'],
    checklistSnapshot: json['ChecklistSnapshot'] == null
        ? []
        : List<ChecklistSnapshot>.from(
            json['ChecklistSnapshot']!.map(
              (x) => ChecklistSnapshot.fromJson(x),
            ),
          ),
    checklistResults: json['ChecklistResults'] == null
        ? []
        : List<dynamic>.from(json['ChecklistResults']!.map((x) => x)),
    beforePhotos: json['BeforePhotos'] == null
        ? []
        : List<dynamic>.from(json['BeforePhotos']!.map((x) => x)),
    afterPhotos: json['AfterPhotos'] == null
        ? []
        : List<dynamic>.from(json['AfterPhotos']!.map((x) => x)),
    status: json['Status'],
    createdBy: json['CreatedBy'],
    createdDate: json['CreatedDate'] == null
        ? null
        : DateTime.parse(json['CreatedDate']),
    startedAt: json['StartedAt'] == null
        ? null
        : DateTime.parse(json['StartedAt']),
    startedBy: json['StartedBy'],
    startedByUserId: json['StartedByUserId'],
    updatedBy: json['UpdatedBy'],
    updatedDate: json['UpdatedDate'] == null
        ? null
        : DateTime.parse(json['UpdatedDate']),
    failedAt: json['FailedAt'] == null
        ? null
        : DateTime.parse(json['FailedAt']),
    failedBy: json['FailedBy'],
    failedByUserId: json['FailedByUserId'],
    failureRemarks: json['FailureRemarks'],
    completedAt: json['CompletedAt'] == null
        ? null
        : DateTime.parse(json['CompletedAt']),
    completedBy: json['CompletedBy'],
    completedByUserId: json['CompletedByUserId'],
    completionRemarks: json['CompletionRemarks'],
    skipRemarks: json['SkipRemarks'],
    skippedAt: json['SkippedAt'] == null
        ? null
        : DateTime.parse(json['SkippedAt']),
    skippedBy: json['SkippedBy'],
    skippedByUserId: json['SkippedByUserId'],
  );

  FacilityTaskStatus get taskStatus => FacilityTaskStatus.fromString(status);

  final List<dynamic>? afterPhotos;
  final String? assignedRole;
  final String? assignedUser;
  final int? assignedUserId;
  final List<dynamic>? beforePhotos;
  final int? branchId;
  final List<dynamic>? checklistResults;
  final List<ChecklistSnapshot>? checklistSnapshot;
  final int? cleaningTemplateId;
  final DateTime? completedAt;
  final String? completedBy;
  final int? completedByUserId;
  final String? completionRemarks;
  final String? createdBy;
  final DateTime? createdDate;
  final int? facilityId;
  final int? facilityTypeId;
  final DateTime? failedAt;
  final String? failedBy;
  final int? failedByUserId;
  final String? failureRemarks;
  final int? id;
  final int? organizationId;
  final int? scheduleId;
  final String? scheduleName;
  final DateTime? scheduledDate;
  final String? scheduledEndTime;
  final String? scheduledStartTime;
  final String? skipRemarks;
  final DateTime? skippedAt;
  final String? skippedBy;
  final int? skippedByUserId;
  final DateTime? startedAt;
  final String? startedBy;
  final int? startedByUserId;
  final String? status;
  final String? templateGroupId;
  final int? templateVersion;
  final String? updatedBy;
  final DateTime? updatedDate;
  final int? zoneId;

  CleaningTask copyWith({
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
    String? templateGroupId,
    String? assignedRole,
    int? assignedUserId,
    String? assignedUser,
    DateTime? scheduledDate,
    String? scheduledStartTime,
    String? scheduledEndTime,
    List<ChecklistSnapshot>? checklistSnapshot,
    List<dynamic>? checklistResults,
    List<dynamic>? beforePhotos,
    List<dynamic>? afterPhotos,
    String? status,
    String? createdBy,
    DateTime? createdDate,
    DateTime? startedAt,
    String? startedBy,
    int? startedByUserId,
    String? updatedBy,
    DateTime? updatedDate,
    DateTime? failedAt,
    String? failedBy,
    int? failedByUserId,
    String? failureRemarks,
    DateTime? completedAt,
    String? completedBy,
    int? completedByUserId,
    String? completionRemarks,
    String? skipRemarks,
    DateTime? skippedAt,
    String? skippedBy,
    int? skippedByUserId,
  }) => CleaningTask(
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
    templateGroupId: templateGroupId ?? this.templateGroupId,
    assignedRole: assignedRole ?? this.assignedRole,
    assignedUserId: assignedUserId ?? this.assignedUserId,
    assignedUser: assignedUser ?? this.assignedUser,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
    scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
    checklistSnapshot: checklistSnapshot ?? this.checklistSnapshot,
    checklistResults: checklistResults ?? this.checklistResults,
    beforePhotos: beforePhotos ?? this.beforePhotos,
    afterPhotos: afterPhotos ?? this.afterPhotos,
    status: status ?? this.status,
    createdBy: createdBy ?? this.createdBy,
    createdDate: createdDate ?? this.createdDate,
    startedAt: startedAt ?? this.startedAt,
    startedBy: startedBy ?? this.startedBy,
    startedByUserId: startedByUserId ?? this.startedByUserId,
    updatedBy: updatedBy ?? this.updatedBy,
    updatedDate: updatedDate ?? this.updatedDate,
    failedAt: failedAt ?? this.failedAt,
    failedBy: failedBy ?? this.failedBy,
    failedByUserId: failedByUserId ?? this.failedByUserId,
    failureRemarks: failureRemarks ?? this.failureRemarks,
    completedAt: completedAt ?? this.completedAt,
    completedBy: completedBy ?? this.completedBy,
    completedByUserId: completedByUserId ?? this.completedByUserId,
    completionRemarks: completionRemarks ?? this.completionRemarks,
    skipRemarks: skipRemarks ?? this.skipRemarks,
    skippedAt: skippedAt ?? this.skippedAt,
    skippedBy: skippedBy ?? this.skippedBy,
    skippedByUserId: skippedByUserId ?? this.skippedByUserId,
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
    'TemplateGroupId': templateGroupId,
    'AssignedRole': assignedRole,
    'AssignedUserId': assignedUserId,
    'AssignedUser': assignedUser,
    'ScheduledDate': scheduledDate == null
        ? null
        : "${scheduledDate!.year.toString().padLeft(4, '0')}-${scheduledDate!.month.toString().padLeft(2, '0')}-${scheduledDate!.day.toString().padLeft(2, '0')}",
    'ScheduledStartTime': scheduledStartTime,
    'ScheduledEndTime': scheduledEndTime,
    'ChecklistSnapshot': checklistSnapshot == null
        ? []
        : List<dynamic>.from(checklistSnapshot!.map((x) => x.toJson())),
    'ChecklistResults': checklistResults == null
        ? []
        : List<dynamic>.from(checklistResults!.map((x) => x)),
    'BeforePhotos': beforePhotos == null
        ? []
        : List<dynamic>.from(beforePhotos!.map((x) => x)),
    'AfterPhotos': afterPhotos == null
        ? []
        : List<dynamic>.from(afterPhotos!.map((x) => x)),
    'Status': status,
    'CreatedBy': createdBy,
    'CreatedDate': createdDate?.toIso8601String(),
    'StartedAt': startedAt?.toIso8601String(),
    'StartedBy': startedBy,
    'StartedByUserId': startedByUserId,
    'UpdatedBy': updatedBy,
    'UpdatedDate': updatedDate?.toIso8601String(),
    'FailedAt': failedAt?.toIso8601String(),
    'FailedBy': failedBy,
    'FailedByUserId': failedByUserId,
    'FailureRemarks': failureRemarks,
    'CompletedAt': completedAt?.toIso8601String(),
    'CompletedBy': completedBy,
    'CompletedByUserId': completedByUserId,
    'CompletionRemarks': completionRemarks,
    'SkipRemarks': skipRemarks,
    'SkippedAt': skippedAt?.toIso8601String(),
    'SkippedBy': skippedBy,
    'SkippedByUserId': skippedByUserId,
  };
}

class ChecklistSnapshot {
  ChecklistSnapshot({
    this.itemId,
    this.name,
    this.description,
    this.required,
    this.sequence,
  });

  factory ChecklistSnapshot.fromJson(Map<String, dynamic> json) =>
      ChecklistSnapshot(
        itemId: json['ItemId'],
        name: json['Name'],
        description: json['Description'],
        required: json['Required'],
        sequence: json['Sequence'],
      );

  final String? description;
  final String? itemId;
  final String? name;
  final bool? required;
  final int? sequence;

  ChecklistSnapshot copyWith({
    String? itemId,
    String? name,
    String? description,
    bool? required,
    int? sequence,
  }) => ChecklistSnapshot(
    itemId: itemId ?? this.itemId,
    name: name ?? this.name,
    description: description ?? this.description,
    required: required ?? this.required,
    sequence: sequence ?? this.sequence,
  );

  Map<String, dynamic> toJson() => {
    'ItemId': itemId,
    'Name': name,
    'Description': description,
    'Required': required,
    'Sequence': sequence,
  };
}
