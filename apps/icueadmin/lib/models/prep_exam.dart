// To parse this JSON data, do
//
//     final prepExam = prepExamFromJson(jsonString);

import 'dart:convert';

List<PrepExam> prepExamFromJson(String str) =>
    List<PrepExam>.from(json.decode(str).map((x) => PrepExam.fromJson(x)));

String prepExamToJson(List<PrepExam> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class PrepExam {
  PrepExam({
    this.organizationId,
    this.zoneId,
    this.branchId,
    this.academicYear,
    this.examName,
    this.examType,
    this.maximumMarks,
    this.passingMarks,
    this.startDate,
    this.endDate,
    this.isActive,
    this.status,
    this.createdBy,
    this.createdDate,
    this.id,
    this.updatedBy,
    this.updatedDate,
  });

  factory PrepExam.fromJson(Map<String, dynamic> json) => PrepExam(
    organizationId: json['OrganizationId'],
    zoneId: json['ZoneId'],
    branchId: json['BranchId'],
    academicYear: json['AcademicYear'],
    examName: json['ExamName'],
    examType: json['ExamType'],
    maximumMarks: json['MaximumMarks'],
    passingMarks: json['PassingMarks'],
    startDate: json['StartDate'] == null
        ? null
        : DateTime.parse(json['StartDate']),
    endDate: json['EndDate'] == null ? null : DateTime.parse(json['EndDate']),
    isActive: json['IsActive'],
    status: json['Status'],
    createdBy: json['CreatedBy'],
    createdDate: json['CreatedDate'] == null
        ? null
        : DateTime.parse(json['CreatedDate']),
    id: json['Id'],
    updatedBy: json['UpdatedBy'],
    updatedDate: json['UpdatedDate'] == null
        ? null
        : DateTime.parse(json['UpdatedDate']),
  );

  final String? academicYear;
  final int? branchId;
  final String? createdBy;
  final DateTime? createdDate;
  final DateTime? endDate;
  final String? examName;
  final String? examType;
  final int? id;
  final bool? isActive;
  final int? maximumMarks;
  final int? organizationId;
  final int? passingMarks;
  final DateTime? startDate;
  final String? status;
  final String? updatedBy;
  final DateTime? updatedDate;
  final int? zoneId;

  Map<String, dynamic> toJson() => {
    'OrganizationId': organizationId,
    'ZoneId': zoneId,
    'BranchId': branchId,
    'AcademicYear': academicYear,
    'ExamName': examName,
    'ExamType': examType,
    'MaximumMarks': maximumMarks,
    'PassingMarks': passingMarks,
    'StartDate': startDate == null
        ? null
        : "${startDate!.year.toString().padLeft(4, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}",
    'EndDate': endDate == null
        ? null
        : "${endDate!.year.toString().padLeft(4, '0')}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}",
    'IsActive': isActive,
    'Status': status,
    'CreatedBy': createdBy,
    'CreatedDate': createdDate?.toIso8601String(),
    'Id': id,
    'UpdatedBy': updatedBy,
    'UpdatedDate': updatedDate?.toIso8601String(),
  };
}
