import 'dart:convert';

CreateAttendanceResponse createAttendanceResponseFromJson(String str) =>
    CreateAttendanceResponse.fromJson(json.decode(str));

String createAttendanceResponseToJson(CreateAttendanceResponse data) =>
    json.encode(data.toJson());

class CreateAttendanceResponse {
  CreateAttendanceResponse({
    this.id,
    this.standard,
    this.section,
    this.period,
    this.presenties,
    this.absenties,
    this.attendanceMode,
    this.attendanceDate,
    this.attendanceTime,
    this.attendedBy,
    required this.err,
    required this.message,
  });

  factory CreateAttendanceResponse.fromJson(Map<String, dynamic> json) =>
      CreateAttendanceResponse(
        id: json['Id'] is int
            ? json['Id'] as int
            : (json['Id'] != null ? int.tryParse(json['Id'].toString()) : null),
        standard: json['Standard']?.toString(),
        section: json['Section']?.toString(),
        period: json['Period']?.toString(),
        presenties: json['Presenties'] is int
            ? json['Presenties'] as int
            : (json['Presenties'] != null
                  ? int.tryParse(json['Presenties'].toString())
                  : null),
        absenties: json['Absenties'] is int
            ? json['Absenties'] as int
            : (json['Absenties'] != null
                  ? int.tryParse(json['Absenties'].toString())
                  : null),
        attendanceMode: json['AttendanceMode']?.toString(),
        attendanceDate: json['AttendanceDate']?.toString(),
        attendanceTime: json['AttendanceTime']?.toString(),
        attendedBy: json['AttendedBy']?.toString(),
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );

  final int? id;
  final String? standard;
  final String? section;
  final String? period;
  final int? presenties;
  final int? absenties;
  final String? attendanceMode;
  final String? attendanceDate;
  final String? attendanceTime;
  final String? attendedBy;
  final bool err;
  final String message;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Standard': standard,
    'Section': section,
    'Period': period,
    'Presenties': presenties,
    'Absenties': absenties,
    'AttendanceMode': attendanceMode,
    'AttendanceDate': attendanceDate,
    'AttendanceTime': attendanceTime,
    'AttendedBy': attendedBy,
    'err': err,
    'message': message,
  };
}
