// To parse this JSON data, do
//
//     final examMarks = examMarksFromJson(jsonString);

import 'dart:convert';

List<ExamMarks> examMarksFromJson(String str) =>
    List<ExamMarks>.from(json.decode(str).map((x) => ExamMarks.fromJson(x)));

String examMarksToJson(List<ExamMarks> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class ExamMarks {
  ExamMarks({
    this.branchId,
    this.examId,
    this.organizationId,
    this.studentId,
    this.zoneId,
    this.createdBy,
    this.createdDate,
    this.isActive,
    this.marks,
    this.remarks,
    this.status,
    this.updatedBy,
    this.updatedDate,
    this.correction,
    this.history,
  });

  factory ExamMarks.fromJson(Map<String, dynamic> json) => ExamMarks(
    branchId: json['BranchId'] is int
        ? json['BranchId'] as int
        : int.tryParse(json['BranchId']?.toString() ?? ''),
    examId: json['ExamId'] is int
        ? json['ExamId'] as int
        : int.tryParse(json['ExamId']?.toString() ?? ''),
    organizationId: json['OrganizationId'] is int
        ? json['OrganizationId'] as int
        : int.tryParse(json['OrganizationId']?.toString() ?? ''),
    studentId: json['StudentId'] is int
        ? json['StudentId'] as int
        : int.tryParse(json['StudentId']?.toString() ?? ''),
    zoneId: json['ZoneId'] is int
        ? json['ZoneId'] as int
        : int.tryParse(json['ZoneId']?.toString() ?? ''),
    createdBy: json['CreatedBy']?.toString(),
    createdDate: json['CreatedDate'] == null
        ? null
        : DateTime.tryParse(json['CreatedDate'].toString()),
    isActive: json['IsActive'] is bool
        ? json['IsActive'] as bool
        : (json['IsActive']?.toString().toLowerCase() != 'false'),
    marks: json['Marks'] is num
        ? json['Marks'] as num
        : num.tryParse(json['Marks']?.toString() ?? ''),
    remarks: json['Remarks']?.toString(),
    status: json['Status']?.toString(),
    updatedBy: json['UpdatedBy']?.toString(),
    updatedDate: json['UpdatedDate'] == null
        ? null
        : DateTime.tryParse(json['UpdatedDate'].toString()),
    correction: json['Correction'] == null
        ? null
        : Correction.fromJson(json['Correction']),
    history: json['History'] == null
        ? []
        : List<History>.from(
            (json['History'] as List).map((x) => History.fromJson(x)),
          ),
  );

  final int? branchId;
  final Correction? correction;
  final String? createdBy;
  final DateTime? createdDate;
  final int? examId;
  final List<History>? history;
  final bool? isActive;
  final num? marks;
  final int? organizationId;
  final String? remarks;
  final String? status;
  final int? studentId;
  final String? updatedBy;
  final DateTime? updatedDate;
  final int? zoneId;

  Map<String, dynamic> toJson() => {
    'BranchId': branchId,
    'ExamId': examId,
    'OrganizationId': organizationId,
    'StudentId': studentId,
    'ZoneId': zoneId,
    'CreatedBy': createdBy,
    'CreatedDate': createdDate?.toIso8601String(),
    'IsActive': isActive,
    'Marks': marks,
    'Remarks': remarks,
    'Status': status,
    'UpdatedBy': updatedBy,
    'UpdatedDate': updatedDate?.toIso8601String(),
    'Correction': correction?.toJson(),
    'History': history == null
        ? []
        : List<dynamic>.from(history!.map((x) => x.toJson())),
  };
}

class Correction {
  Correction({
    this.status,
    this.statusAt,
    this.marks,
    this.markStatus,
    this.reason,
    this.requestedId,
    this.requestedBy,
    this.requestedDate,
    this.approvedBy,
    this.approvedDate,
  });

  factory Correction.fromJson(Map<String, dynamic> json) => Correction(
    status: json['Status']?.toString(),
    statusAt: json['StatusAt'] == null
        ? null
        : DateTime.tryParse(json['StatusAt'].toString()),
    marks: json['Marks'] is num
        ? json['Marks'] as num
        : num.tryParse(json['Marks']?.toString() ?? ''),
    markStatus: json['MarkStatus']?.toString(),
    reason: json['Reason']?.toString(),
    requestedId: json['RequestedId'] is int
        ? json['RequestedId'] as int
        : int.tryParse(json['RequestedId']?.toString() ?? ''),
    requestedBy: json['RequestedBy']?.toString(),
    requestedDate: json['RequestedDate'] == null
        ? null
        : DateTime.tryParse(json['RequestedDate'].toString()),
    approvedBy: json['ApprovedBy']?.toString(),
    approvedDate: json['ApprovedDate'] == null
        ? null
        : DateTime.tryParse(json['ApprovedDate'].toString()),
  );

  final String? approvedBy;
  final DateTime? approvedDate;
  final String? markStatus;
  final num? marks;
  final String? reason;
  final String? requestedBy;
  final DateTime? requestedDate;
  final int? requestedId;
  final String? status;
  final DateTime? statusAt;

  Map<String, dynamic> toJson() => {
    if (status != null) 'Status': status,
    if (statusAt != null) 'StatusAt': statusAt?.toIso8601String(),
    if (marks != null) 'Marks': marks,
    if (markStatus != null) 'MarkStatus': markStatus,
    if (reason != null) 'Reason': reason,
    if (requestedId != null) 'RequestedId': requestedId,
    if (requestedBy != null) 'RequestedBy': requestedBy,
    if (requestedDate != null)
      'RequestedDate': requestedDate?.toIso8601String(),
    if (approvedBy != null) 'ApprovedBy': approvedBy,
    if (approvedDate != null) 'ApprovedDate': approvedDate?.toIso8601String(),
  };
}

class History {
  History({
    this.oldMarks,
    this.oldStatus,
    this.correctionMarks,
    this.correctionMarkStatus,
    this.reason,
    this.requestedId,
    this.requestedBy,
    this.requestedDate,
    this.decision,
    this.approvedId,
    this.approvedBy,
    this.approvedDate,
    this.remarks,
  });

  factory History.fromJson(Map<String, dynamic> json) => History(
    oldMarks: json['OldMarks'] is num
        ? json['OldMarks'] as num
        : num.tryParse(json['OldMarks']?.toString() ?? ''),
    oldStatus: json['OldStatus']?.toString(),
    correctionMarks: json['CorrectionMarks'] is num
        ? json['CorrectionMarks'] as num
        : num.tryParse(json['CorrectionMarks']?.toString() ?? ''),
    correctionMarkStatus: json['CorrectionMarkStatus']?.toString(),
    reason: json['Reason']?.toString(),
    requestedId: json['RequestedId'] is int
        ? json['RequestedId'] as int
        : int.tryParse(json['RequestedId']?.toString() ?? ''),
    requestedBy: json['RequestedBy']?.toString(),
    requestedDate: json['RequestedDate'] == null
        ? null
        : DateTime.tryParse(json['RequestedDate'].toString()),
    decision: json['Decision']?.toString(),
    approvedId: json['ApprovedId'] is int
        ? json['ApprovedId'] as int
        : int.tryParse(json['ApprovedId']?.toString() ?? ''),
    approvedBy: json['ApprovedBy']?.toString(),
    approvedDate: json['ApprovedDate'] == null
        ? null
        : DateTime.tryParse(json['ApprovedDate'].toString()),
    remarks: json['Remarks']?.toString(),
  );

  final String? approvedBy;
  final DateTime? approvedDate;
  final int? approvedId;
  final String? correctionMarkStatus;
  final num? correctionMarks;
  final String? decision;
  final num? oldMarks;
  final String? oldStatus;
  final String? reason;
  final String? remarks;
  final String? requestedBy;
  final DateTime? requestedDate;
  final int? requestedId;

  Map<String, dynamic> toJson() => {
    'OldMarks': oldMarks,
    'OldStatus': oldStatus,
    'CorrectionMarks': correctionMarks,
    'CorrectionMarkStatus': correctionMarkStatus,
    'Reason': reason,
    'RequestedId': requestedId,
    'RequestedBy': requestedBy,
    'RequestedDate': requestedDate?.toIso8601String(),
    'Decision': decision,
    'ApprovedId': approvedId,
    'ApprovedBy': approvedBy,
    'ApprovedDate': approvedDate?.toIso8601String(),
    'Remarks': remarks,
  };
}
