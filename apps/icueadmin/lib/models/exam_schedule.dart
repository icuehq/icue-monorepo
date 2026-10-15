class ExamSchedule {
  ExamSchedule({
    required this.id,
    required this.academicYear,
    required this.examName,
    required this.classId,
    required this.section,
    required this.subjectId,
    required this.subject,
    required this.examType,
    required this.examDate,
    required this.maximumMarks,
    required this.passingMarks,
    this.standard,
    this.organizationId,
    this.zoneId,
    this.branchId,
    this.isPublished = false,
    this.status,
    this.isActive = true,
    this.createdBy,
    this.createdDate,
    this.publishedBy,
    this.publishedDate,
    this.updatedBy,
    this.updatedDate,
  });

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    final statusStr = json['Status']?.toString();
    final isPub =
        statusStr?.toLowerCase() == 'published' ||
        json['IsPublished'] == true ||
        json['IsPublished']?.toString().toLowerCase() == 'true';

    return ExamSchedule(
      id: json['Id'] is int
          ? json['Id']
          : int.tryParse(json['Id']?.toString() ?? '') ?? 0,
      academicYear: json['AcademicYear']?.toString() ?? '',
      examName: json['ExamName']?.toString() ?? '',
      classId: json['ClassId'] is int
          ? json['ClassId']
          : int.tryParse(json['ClassId']?.toString() ?? '') ?? 0,
      section: json['Section']?.toString() ?? '',
      subjectId: json['SubjectId'] is int
          ? json['SubjectId']
          : int.tryParse(json['SubjectId']?.toString() ?? '') ?? 0,
      subject: json['Subject']?.toString() ?? '',
      standard: json['Standard']?.toString(),
      examType: json['ExamType']?.toString() ?? '',
      examDate: json['ExamDate']?.toString() ?? '',
      maximumMarks: json['MaximumMarks'] is num
          ? json['MaximumMarks']
          : num.tryParse(json['MaximumMarks']?.toString() ?? '') ?? 100,
      passingMarks: json['PassingMarks'] is num
          ? json['PassingMarks']
          : num.tryParse(json['PassingMarks']?.toString() ?? '') ?? 35,
      organizationId: json['OrganizationId'] is int
          ? json['OrganizationId']
          : int.tryParse(json['OrganizationId']?.toString() ?? ''),
      zoneId: json['ZoneId'] is int
          ? json['ZoneId']
          : int.tryParse(json['ZoneId']?.toString() ?? ''),
      branchId: json['BranchId'] is int
          ? json['BranchId']
          : int.tryParse(json['BranchId']?.toString() ?? ''),
      isPublished: isPub,
      status: statusStr,
      isActive: json['IsActive'] is bool
          ? json['IsActive'] as bool
          : (json['IsActive']?.toString().toLowerCase() != 'false'),
      createdBy: json['CreatedBy']?.toString(),
      createdDate: json['CreatedDate']?.toString(),
      publishedBy: json['PublishedBy']?.toString(),
      publishedDate: json['PublishedDate']?.toString(),
      updatedBy: json['UpdatedBy']?.toString(),
      updatedDate: json['UpdatedDate']?.toString(),
    );
  }

  final int id;
  final String academicYear;
  final String examName;
  final int classId;
  final String section;
  final int subjectId;
  final String subject;
  final String? standard;
  final String examType;
  final String examDate;
  final num maximumMarks;
  final num passingMarks;
  final int? organizationId;
  final int? zoneId;
  final int? branchId;
  final bool isPublished;
  final String? status;
  final bool isActive;
  final String? createdBy;
  final String? createdDate;
  final String? publishedBy;
  final String? publishedDate;
  final String? updatedBy;
  final String? updatedDate;

  ExamSchedule copyWith({
    int? id,
    String? academicYear,
    String? examName,
    int? classId,
    String? section,
    int? subjectId,
    String? subject,
    String? standard,
    String? examType,
    String? examDate,
    num? maximumMarks,
    num? passingMarks,
    int? organizationId,
    int? zoneId,
    int? branchId,
    bool? isPublished,
    String? status,
    bool? isActive,
    String? createdBy,
    String? createdDate,
    String? publishedBy,
    String? publishedDate,
    String? updatedBy,
    String? updatedDate,
  }) => ExamSchedule(
    id: id ?? this.id,
    academicYear: academicYear ?? this.academicYear,
    examName: examName ?? this.examName,
    classId: classId ?? this.classId,
    section: section ?? this.section,
    subjectId: subjectId ?? this.subjectId,
    subject: subject ?? this.subject,
    standard: standard ?? this.standard,
    examType: examType ?? this.examType,
    examDate: examDate ?? this.examDate,
    maximumMarks: maximumMarks ?? this.maximumMarks,
    passingMarks: passingMarks ?? this.passingMarks,
    organizationId: organizationId ?? this.organizationId,
    zoneId: zoneId ?? this.zoneId,
    branchId: branchId ?? this.branchId,
    isPublished: isPublished ?? this.isPublished,
    status: status ?? this.status,
    isActive: isActive ?? this.isActive,
    createdBy: createdBy ?? this.createdBy,
    createdDate: createdDate ?? this.createdDate,
    publishedBy: publishedBy ?? this.publishedBy,
    publishedDate: publishedDate ?? this.publishedDate,
    updatedBy: updatedBy ?? this.updatedBy,
    updatedDate: updatedDate ?? this.updatedDate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamSchedule &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'AcademicYear': academicYear,
    'ExamName': examName,
    'ClassId': classId,
    'Section': section,
    'SubjectId': subjectId,
    'Subject': subject,
    if (standard != null) 'Standard': standard,
    'ExamType': examType,
    'ExamDate': examDate,
    'MaximumMarks': maximumMarks,
    'PassingMarks': passingMarks,
    if (organizationId != null) 'OrganizationId': organizationId,
    if (zoneId != null) 'ZoneId': zoneId,
    if (branchId != null) 'BranchId': branchId,
    'IsPublished': isPublished,
    if (status != null) 'Status': status,
    'IsActive': isActive,
    if (createdBy != null) 'CreatedBy': createdBy,
    if (createdDate != null) 'CreatedDate': createdDate,
    if (publishedBy != null) 'PublishedBy': publishedBy,
    if (publishedDate != null) 'PublishedDate': publishedDate,
    if (updatedBy != null) 'UpdatedBy': updatedBy,
    if (updatedDate != null) 'UpdatedDate': updatedDate,
  };
}
