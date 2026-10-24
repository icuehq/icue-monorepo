import 'meta_data.dart';

class ClassAttendanceDetailResponse {
  const ClassAttendanceDetailResponse({
    this.metadata,
    this.data = const [],
    this.err = false,
    this.message = '',
  });

  factory ClassAttendanceDetailResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawMetadata = json['metadata'];

    return ClassAttendanceDetailResponse(
      metadata: rawMetadata is Map<String, dynamic>
          ? Metadata.fromJson(rawMetadata)
          : null,
      data: rawData is List
          ? rawData
                .whereType<Map<String, dynamic>>()
                .map(ClassAttendanceStudentItem.fromJson)
                .toList()
          : const [],
      err: json['err'] == true,
      message: json['message']?.toString() ?? '',
    );
  }

  final List<ClassAttendanceStudentItem> data;
  final bool err;
  final String message;
  final Metadata? metadata;

  Map<String, dynamic> toJson() => {
    if (metadata != null) 'metadata': metadata!.toJson(),
    'data': data.map((e) => e.toJson()).toList(),
    'err': err,
    'message': message,
  };
}

class ClassAttendanceStudentItem {
  const ClassAttendanceStudentItem({
    required this.section,
    required this.studentId,
    required this.admissionNumber,
    required this.standard,
    required this.studentName,
    required this.period,
    required this.date,
    required this.time,
    required this.status,
    this.source = '',
    this.attendedBy = '',
    this.attdMode = '',
  });

  factory ClassAttendanceStudentItem.fromJson(Map<String, dynamic> json) {
    return ClassAttendanceStudentItem(
      section: json['Section']?.toString() ?? '',
      studentId: (json['StudentId'] as num?)?.toInt() ?? 0,
      admissionNumber: json['AdmissionNumber']?.toString() ?? '',
      standard: json['Standard']?.toString() ?? '',
      studentName: json['StudentName']?.toString() ?? '',
      period: json['Period']?.toString() ?? '',
      date: json['Date']?.toString() ?? '',
      time: json['Time']?.toString() ?? '',
      status: json['Status']?.toString() ?? '',
      source: json['Source']?.toString() ?? '',
      attendedBy: json['AttendedBy']?.toString() ?? '',
      attdMode: json['AttdMode']?.toString() ?? '',
    );
  }

  final String admissionNumber;
  final String attdMode;
  final String attendedBy;
  final String date;
  final String period;
  final String section;
  final String source;
  final String standard;
  final String status;
  final int studentId;
  final String studentName;
  final String time;

  bool get isPresent => status.toUpperCase() == 'P';

  bool get isAbsent => status.toUpperCase() == 'A';

  ClassAttendanceStudentItem copyWith({
    String? section,
    int? studentId,
    String? admissionNumber,
    String? standard,
    String? studentName,
    String? period,
    String? date,
    String? time,
    String? status,
    String? source,
    String? attendedBy,
    String? attdMode,
  }) {
    return ClassAttendanceStudentItem(
      section: section ?? this.section,
      studentId: studentId ?? this.studentId,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      standard: standard ?? this.standard,
      studentName: studentName ?? this.studentName,
      period: period ?? this.period,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      source: source ?? this.source,
      attendedBy: attendedBy ?? this.attendedBy,
      attdMode: attdMode ?? this.attdMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'Section': section,
    'StudentId': studentId,
    'AdmissionNumber': admissionNumber,
    'Standard': standard,
    'StudentName': studentName,
    'Period': period,
    'Date': date,
    'Time': time,
    'Status': status,
    'Source': source,
    'AttendedBy': attendedBy,
    'AttdMode': attdMode,
  };
}
