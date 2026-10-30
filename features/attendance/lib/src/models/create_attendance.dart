enum AttendanceModeOption {
  manual,
  sdkLive,
  sdkPhoto,
}

class AttendanceStudent {
  const AttendanceStudent({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.admissionNumber,
    required this.isPresent,
    this.uid,
    this.attendanceMode,
  });

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) =>
      AttendanceStudent(
        id: json['Id'] as int? ?? 0,
        name: json['Name'] as String? ?? '',
        rollNo: json['RollNo'] as String? ?? '',
        admissionNumber: json['AdmissionNumber'] as String? ?? '',
        isPresent: json['IsPresent'] as bool? ?? false,
        uid: json['UID'] as String?,
        attendanceMode: json['AttendanceMode'] as String?,
      );

  final int id;
  final String name;
  final String rollNo;
  final String admissionNumber;
  final bool isPresent;
  final String? uid;
  final String? attendanceMode;

  Map<String, dynamic> toJson() => {
        'Id': id,
        'Name': name,
        'RollNo': rollNo,
        'AdmissionNumber': admissionNumber,
        'IsPresent': isPresent,
        'UID': ?uid,
        'AttendanceMode': ?attendanceMode,
      };

  AttendanceStudent copyWith({
    int? id,
    String? name,
    String? rollNo,
    String? admissionNumber,
    bool? isPresent,
    String? uid,
    String? attendanceMode,
  }) {
    return AttendanceStudent(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      isPresent: isPresent ?? this.isPresent,
      uid: uid ?? this.uid,
      attendanceMode: attendanceMode ?? this.attendanceMode,
    );
  }
}

class CreateAttendance {
  const CreateAttendance({
    required this.source,
    required this.students,
    required this.classId,
    required this.section,
    required this.standard,
    required this.attendanceDate,
    required this.attendanceTime,
    required this.month,
    required this.year,
    required this.period,
    this.attendanceMode,
    this.images,
  });

  factory CreateAttendance.fromJson(Map<String, dynamic> json) {
    final studentsRaw = json['Students'];
    final imagesRaw = json['Images'];

    return CreateAttendance(
      source: json['Source'] as String? ?? 'adminapp',
      students: studentsRaw is List
          ? studentsRaw
              .whereType<Map<String, dynamic>>()
              .map(AttendanceStudent.fromJson)
              .toList()
          : const <AttendanceStudent>[],
      classId: json['ClassId'] as int? ?? 0,
      section: json['Section'] as String? ?? '',
      standard: json['Standard'] as String? ?? '',
      attendanceDate: json['AttendanceDate'] as String? ?? '',
      attendanceTime: json['AttendanceTime'] as String? ?? '',
      month: json['Month'] as int? ?? 1,
      year: json['Year'] as int? ?? DateTime.now().year,
      period: json['Period'] as String? ?? '1',
      attendanceMode: json['AttendanceMode'] as String?,
      images: imagesRaw is List
          ? imagesRaw.whereType<String>().toList()
          : null,
    );
  }

  final String source;
  final List<AttendanceStudent> students;
  final int classId;
  final String section;
  final String standard;
  final String attendanceDate;
  final String attendanceTime;
  final int month;
  final int year;
  final String period;
  final String? attendanceMode;
  final List<String>? images;

  Map<String, dynamic> toJson() => {
        'Source': source,
        'Students': students.map((x) => x.toJson()).toList(),
        'ClassId': classId,
        'Section': section,
        'Standard': standard,
        'AttendanceDate': attendanceDate,
        'AttendanceTime': attendanceTime,
        'Month': month,
        'Year': year,
        'Period': period,
        'AttendanceMode': ?attendanceMode,
        'Images': ?images,
      };

  CreateAttendance copyWith({
    String? source,
    List<AttendanceStudent>? students,
    int? classId,
    String? section,
    String? standard,
    String? attendanceDate,
    String? attendanceTime,
    int? month,
    int? year,
    String? period,
    String? attendanceMode,
    List<String>? images,
  }) {
    return CreateAttendance(
      source: source ?? this.source,
      students: students ?? this.students,
      classId: classId ?? this.classId,
      section: section ?? this.section,
      standard: standard ?? this.standard,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      attendanceTime: attendanceTime ?? this.attendanceTime,
      month: month ?? this.month,
      year: year ?? this.year,
      period: period ?? this.period,
      attendanceMode: attendanceMode ?? this.attendanceMode,
      images: images ?? this.images,
    );
  }
}
