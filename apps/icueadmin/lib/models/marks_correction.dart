import 'dart:convert';

import 'marks.dart';

export 'marks.dart' show Correction, History;

RequestMarksCorrectionResponse requestMarksCorrectionResponseFromJson(
  String str,
) => RequestMarksCorrectionResponse.fromJson(json.decode(str));

String requestMarksCorrectionResponseToJson(
  RequestMarksCorrectionResponse data,
) => json.encode(data.toJson());

GetMarksCorrectionRequestsResponse getMarksCorrectionRequestsResponseFromJson(
  String str,
) => GetMarksCorrectionRequestsResponse.fromJson(json.decode(str));

String getMarksCorrectionRequestsResponseToJson(
  GetMarksCorrectionRequestsResponse data,
) => json.encode(data.toJson());

ApproveMarksCorrectionResponse approveMarksCorrectionResponseFromJson(
  String str,
) => ApproveMarksCorrectionResponse.fromJson(json.decode(str));

String approveMarksCorrectionResponseToJson(
  ApproveMarksCorrectionResponse data,
) => json.encode(data.toJson());

/// Response model for `requestMarksCorrection` API.
class RequestMarksCorrectionResponse {
  RequestMarksCorrectionResponse({
    required this.success,
    required this.err,
    required this.message,
    this.examId,
    this.studentId,
    this.currentMarks,
    this.currentStatus,
    this.requestedMarks,
    this.requestedStatus,
    this.correctionStatus,
    this.correctionStatusAt,
  });

  factory RequestMarksCorrectionResponse.fromJson(Map<String, dynamic> json) {
    final hasErr = json['err'] == true;
    final isExplicitSuccess = json['success'] == true;
    final success =
        isExplicitSuccess ||
        (!hasErr && json['err'] != null) ||
        (json['err'] == null && json['CorrectionStatus'] != null);
    final err = hasErr || (json['success'] == false);

    return RequestMarksCorrectionResponse(
      success: success,
      err: err,
      message: json['message']?.toString() ?? '',
      examId: json['ExamId'] is int
          ? json['ExamId'] as int
          : int.tryParse(json['ExamId']?.toString() ?? ''),
      studentId: json['StudentId'] is int
          ? json['StudentId'] as int
          : int.tryParse(json['StudentId']?.toString() ?? ''),
      currentMarks: json['CurrentMarks'] is num
          ? json['CurrentMarks'] as num
          : num.tryParse(json['CurrentMarks']?.toString() ?? ''),
      currentStatus: json['CurrentStatus']?.toString(),
      requestedMarks: json['RequestedMarks'] is num
          ? json['RequestedMarks'] as num
          : num.tryParse(json['RequestedMarks']?.toString() ?? ''),
      requestedStatus: json['RequestedStatus']?.toString(),
      correctionStatus: json['CorrectionStatus']?.toString(),
      correctionStatusAt: json['CorrectionStatusAt'] == null
          ? null
          : DateTime.tryParse(json['CorrectionStatusAt'].toString()),
    );
  }

  factory RequestMarksCorrectionResponse.error(String message) =>
      RequestMarksCorrectionResponse(
        success: false,
        err: true,
        message: message,
      );

  final String? correctionStatus;
  final DateTime? correctionStatusAt;
  final num? currentMarks;
  final String? currentStatus;
  final bool err;
  final int? examId;
  final String message;
  final num? requestedMarks;
  final String? requestedStatus;
  final int? studentId;
  final bool success;

  Map<String, dynamic> toJson() => {
    'success': success,
    'err': err,
    'message': message,
    if (examId != null) 'ExamId': examId,
    if (studentId != null) 'StudentId': studentId,
    'CurrentMarks': currentMarks,
    if (currentStatus != null) 'CurrentStatus': currentStatus,
    if (requestedMarks != null) 'RequestedMarks': requestedMarks,
    if (requestedStatus != null) 'RequestedStatus': requestedStatus,
    if (correctionStatus != null) 'CorrectionStatus': correctionStatus,
    if (correctionStatusAt != null)
      'CorrectionStatusAt': correctionStatusAt?.toIso8601String(),
  };
}

/// Response wrapper for `getMarksCorrectionRequests` API.
class GetMarksCorrectionRequestsResponse {
  GetMarksCorrectionRequestsResponse({
    required this.err,
    required this.message,
    required this.data,
  });

  factory GetMarksCorrectionRequestsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawData = json['data'];
    return GetMarksCorrectionRequestsResponse(
      err: json['err'] == true,
      message: json['message']?.toString() ?? '',
      data: rawData is List
          ? rawData
                .whereType<Map>()
                .map(
                  (x) => MarksCorrectionItem.fromJson(
                    Map<String, dynamic>.from(x),
                  ),
                )
                .toList()
          : [],
    );
  }

  final List<MarksCorrectionItem> data;
  final bool err;
  final String message;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'data': List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

/// A single mark correction request item returned by `getMarksCorrectionRequests`.
class MarksCorrectionItem {
  MarksCorrectionItem({
    required this.examId,
    required this.studentId,
    this.studentName,
    this.rollNo,
    this.admissionNumber,
    this.section,
    this.classId,
    this.standard,
    this.examName,
    this.subject,
    this.maximumMarks,
    this.passingMarks,
    this.currentMarks,
    this.currentStatus,
    this.correction,
    this.history = const [],
  });

  factory MarksCorrectionItem.fromJson(
    Map<String, dynamic> json,
  ) => MarksCorrectionItem(
    examId: json['ExamId'] is int
        ? json['ExamId'] as int
        : int.tryParse(json['ExamId']?.toString() ?? '') ?? 0,
    studentId: json['StudentId'] is int
        ? json['StudentId'] as int
        : int.tryParse(json['StudentId']?.toString() ?? '') ?? 0,
    studentName: json['StudentName']?.toString() ?? json['Name']?.toString(),
    rollNo: json['RollNo']?.toString(),
    admissionNumber:
        json['AdmissionNumber']?.toString() ?? json['AdmissionNo']?.toString(),
    section: json['Section']?.toString(),
    classId: json['ClassId'] is int
        ? json['ClassId'] as int
        : int.tryParse(json['ClassId']?.toString() ?? ''),
    standard: json['Standard']?.toString(),
    examName: json['ExamName']?.toString(),
    subject: json['Subject']?.toString(),
    maximumMarks: json['MaximumMarks'] is num
        ? json['MaximumMarks'] as num
        : num.tryParse(json['MaximumMarks']?.toString() ?? ''),
    passingMarks: json['PassingMarks'] is num
        ? json['PassingMarks'] as num
        : num.tryParse(json['PassingMarks']?.toString() ?? ''),
    currentMarks: json['CurrentMarks'] is num
        ? json['CurrentMarks'] as num
        : num.tryParse(json['CurrentMarks']?.toString() ?? ''),
    currentStatus: json['CurrentStatus']?.toString(),
    correction: json['Correction'] is Map
        ? Correction.fromJson(
            Map<String, dynamic>.from(json['Correction'] as Map),
          )
        : null,
    history: json['History'] is List
        ? (json['History'] as List)
              .whereType<Map>()
              .map((x) => History.fromJson(Map<String, dynamic>.from(x)))
              .toList()
        : [],
  );

  final String? admissionNumber;
  final int? classId;
  final Correction? correction;
  final num? currentMarks;
  final String? currentStatus;
  final int examId;
  final String? examName;
  final List<History> history;
  final num? maximumMarks;
  final num? passingMarks;
  final String? rollNo;
  final String? section;
  final String? standard;
  final int studentId;
  final String? studentName;
  final String? subject;

  MarksCorrectionItem copyWith({
    int? examId,
    int? studentId,
    String? studentName,
    String? rollNo,
    String? admissionNumber,
    String? section,
    int? classId,
    String? standard,
    String? examName,
    String? subject,
    num? maximumMarks,
    num? passingMarks,
    num? currentMarks,
    String? currentStatus,
    Correction? correction,
    List<History>? history,
  }) => MarksCorrectionItem(
    examId: examId ?? this.examId,
    studentId: studentId ?? this.studentId,
    studentName: studentName ?? this.studentName,
    rollNo: rollNo ?? this.rollNo,
    admissionNumber: admissionNumber ?? this.admissionNumber,
    section: section ?? this.section,
    classId: classId ?? this.classId,
    standard: standard ?? this.standard,
    examName: examName ?? this.examName,
    subject: subject ?? this.subject,
    maximumMarks: maximumMarks ?? this.maximumMarks,
    passingMarks: passingMarks ?? this.passingMarks,
    currentMarks: currentMarks ?? this.currentMarks,
    currentStatus: currentStatus ?? this.currentStatus,
    correction: correction ?? this.correction,
    history: history ?? this.history,
  );

  Map<String, dynamic> toJson() => {
    'ExamId': examId,
    'StudentId': studentId,
    if (studentName != null) 'StudentName': studentName,
    if (rollNo != null) 'RollNo': rollNo,
    if (admissionNumber != null) 'AdmissionNumber': admissionNumber,
    if (section != null) 'Section': section,
    if (classId != null) 'ClassId': classId,
    if (standard != null) 'Standard': standard,
    if (examName != null) 'ExamName': examName,
    if (subject != null) 'Subject': subject,
    if (maximumMarks != null) 'MaximumMarks': maximumMarks,
    if (passingMarks != null) 'PassingMarks': passingMarks,
    'CurrentMarks': currentMarks,
    if (currentStatus != null) 'CurrentStatus': currentStatus,
    if (correction != null) 'Correction': correction!.toJson(),
    'History': history.map((x) => x.toJson()).toList(),
  };
}

/// Response model for `approveMarksCorrection` API.
class ApproveMarksCorrectionResponse {
  ApproveMarksCorrectionResponse({
    required this.success,
    required this.err,
    required this.message,
    this.examId,
    this.studentId,
    this.decision,
    this.marks,
    this.status,
    this.approvedBy,
    this.approvedDate,
  });

  factory ApproveMarksCorrectionResponse.fromJson(Map<String, dynamic> json) {
    final hasErr = json['err'] == true;
    final isExplicitSuccess = json['success'] == true;
    final success =
        isExplicitSuccess ||
        (!hasErr && json['err'] != null) ||
        (json['err'] == null && json['Decision'] != null);
    final err = hasErr || (json['success'] == false);

    return ApproveMarksCorrectionResponse(
      success: success,
      err: err,
      message: json['message']?.toString() ?? '',
      examId: json['ExamId'] is int
          ? json['ExamId'] as int
          : int.tryParse(json['ExamId']?.toString() ?? ''),
      studentId: json['StudentId'] is int
          ? json['StudentId'] as int
          : int.tryParse(json['StudentId']?.toString() ?? ''),
      decision: json['Decision']?.toString(),
      marks: json['Marks'] is num
          ? json['Marks'] as num
          : num.tryParse(json['Marks']?.toString() ?? ''),
      status: json['Status']?.toString(),
      approvedBy: json['ApprovedBy']?.toString(),
      approvedDate: json['ApprovedDate'] == null
          ? null
          : DateTime.tryParse(json['ApprovedDate'].toString()),
    );
  }

  factory ApproveMarksCorrectionResponse.error(String message) =>
      ApproveMarksCorrectionResponse(
        success: false,
        err: true,
        message: message,
      );

  final String? approvedBy;
  final DateTime? approvedDate;
  final String? decision;
  final bool err;
  final int? examId;
  final num? marks;
  final String message;
  final String? status;
  final int? studentId;
  final bool success;

  Map<String, dynamic> toJson() => {
    'success': success,
    'err': err,
    'message': message,
    if (examId != null) 'ExamId': examId,
    if (studentId != null) 'StudentId': studentId,
    if (decision != null) 'Decision': decision,
    if (marks != null) 'Marks': marks,
    if (status != null) 'Status': status,
    if (approvedBy != null) 'ApprovedBy': approvedBy,
    if (approvedDate != null) 'ApprovedDate': approvedDate?.toIso8601String(),
  };
}
