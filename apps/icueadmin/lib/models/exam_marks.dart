import 'marks.dart';

class ExamStudent {
  ExamStudent({
    required this.studentId,
    required this.name,
    this.classId,
    this.rollNo,
    this.section,
    this.admissionNumber,
    this.marks,
    this.status = 'PRESENT',
    this.remarks,
    this.isSaved = false,
    this.hasExistingMarks = false,
    this.isCorrectionPending = false,
    this.correction,
  });

  factory ExamStudent.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['Status']?.toString().trim().toUpperCase();
    final effectiveStatus = (rawStatus == 'ABSENT' || rawStatus == 'NA')
        ? rawStatus!
        : 'PRESENT';

    final parsedMarks = json['Marks'] is num
        ? json['Marks'] as num
        : num.tryParse(json['Marks']?.toString() ?? '');

    final hasMarks = parsedMarks != null;
    final isExplicitAttendance = rawStatus == 'ABSENT' || rawStatus == 'NA';
    final isExplicitSaved =
        json['IsSaved'] == true ||
        json['IsSaved'] == 1 ||
        json['IsSaved']?.toString().toLowerCase() == 'true';
    final hasExistingMarks =
        json['HasExistingMarks'] == true ||
        hasMarks ||
        isExplicitAttendance ||
        isExplicitSaved;

    Correction? correction;
    if (json['Correction'] is Map) {
      correction = Correction.fromJson(
        Map<String, dynamic>.from(json['Correction'] as Map),
      );
    }
    final isCorrectionPending =
        json['IsCorrectionPending'] == true ||
        correction?.status?.trim().toLowerCase() == 'pending';

    return ExamStudent(
      studentId: json['StudentId'] is int
          ? json['StudentId'] as int
          : json['Id'] is int
          ? json['Id'] as int
          : int.tryParse(
                  json['StudentId']?.toString() ?? json['Id']?.toString() ?? '',
                ) ??
                0,
      classId: json['ClassId'] is int
          ? json['ClassId'] as int
          : int.tryParse(json['ClassId']?.toString() ?? ''),
      name: json['Name']?.toString() ?? json['StudentName']?.toString() ?? '',
      rollNo: json['RollNo']?.toString(),
      section: json['Section']?.toString(),
      admissionNumber:
          json['AdmissionNumber']?.toString() ??
          json['AdmissionNo']?.toString(),
      marks: parsedMarks,
      status: effectiveStatus,
      remarks: json['Remarks']?.toString(),
      isSaved: isExplicitSaved || hasMarks || isExplicitAttendance,
      hasExistingMarks: hasExistingMarks,
      isCorrectionPending: isCorrectionPending,
      correction: correction,
    );
  }

  final int studentId;
  final int? classId;
  final String name;
  final String? rollNo;
  final String? section;
  final String? admissionNumber;
  num? marks;
  String status; // 'PRESENT', 'ABSENT', 'NA'
  String? remarks;
  bool isSaved;
  bool hasExistingMarks;
  bool isCorrectionPending;
  Correction? correction;

  ExamStudent copyWith({
    int? studentId,
    int? classId,
    String? name,
    String? rollNo,
    String? section,
    String? admissionNumber,
    num? marks,
    String? status,
    String? remarks,
    bool? isSaved,
    bool? hasExistingMarks,
    bool? isCorrectionPending,
    Correction? correction,
  }) => ExamStudent(
    studentId: studentId ?? this.studentId,
    classId: classId ?? this.classId,
    name: name ?? this.name,
    rollNo: rollNo ?? this.rollNo,
    section: section ?? this.section,
    admissionNumber: admissionNumber ?? this.admissionNumber,
    marks: marks ?? this.marks,
    status: status ?? this.status,
    remarks: remarks ?? this.remarks,
    isSaved: isSaved ?? this.isSaved,
    hasExistingMarks: hasExistingMarks ?? this.hasExistingMarks,
    isCorrectionPending: isCorrectionPending ?? this.isCorrectionPending,
    correction: correction ?? this.correction,
  );

  Map<String, dynamic> toJson() => {
    'StudentId': studentId,
    if (classId != null) 'ClassId': classId,
    'Name': name,
    if (rollNo != null) 'RollNo': rollNo,
    if (section != null) 'Section': section,
    if (admissionNumber != null) 'AdmissionNumber': admissionNumber,
    if (marks != null) 'Marks': marks,
    'Status': status,
    if (remarks != null) 'Remarks': remarks,
    if (isCorrectionPending) 'IsCorrectionPending': isCorrectionPending,
    if (correction != null) 'Correction': correction!.toJson(),
  };
}

class ExamMarksEntry {
  ExamMarksEntry({required this.studentId, this.marks, this.status});

  factory ExamMarksEntry.fromJson(Map<String, dynamic> json) => ExamMarksEntry(
    studentId: json['StudentId'] is int
        ? json['StudentId']
        : int.tryParse(json['StudentId']?.toString() ?? '') ?? 0,
    marks: json['Marks'] is num
        ? json['Marks']
        : num.tryParse(json['Marks']?.toString() ?? ''),
    status: json['Status']?.toString(),
  );

  final int studentId;
  final num? marks;
  final String? status; // 'PRESENT', 'ABSENT', 'NA'

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'StudentId': studentId};
    if (status != null && status != 'PRESENT') {
      map['Status'] = status;
    } else if (marks != null) {
      map['Marks'] = marks;
    } else if (status != null) {
      map['Status'] = status;
    }
    return map;
  }
}
