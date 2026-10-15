// To parse this JSON data, do
//
//     final appSettings = appSettingsFromJson(jsonString);

import 'dart:convert';

AppSettings appSettingsFromJson(String str) =>
    AppSettings.fromJson(json.decode(str));

String appSettingsToJson(AppSettings data) => json.encode(data.toJson());

class AppSettings {
  AppSettings({
    required this.err,
    required this.message,
    this.vhCnfg,
    this.attendCnfg,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    err: json['err'] ?? false,
    message: json['message'] ?? '',
    vhCnfg: json['VhCnfg'] == null ? null : VhCnfg.fromJson(json['VhCnfg']),
    attendCnfg: json['AttendCnfg'] == null
        ? null
        : AttendCnfg.fromJson(json['AttendCnfg']),
  );

  final bool err;
  final String message;
  final VhCnfg? vhCnfg;
  final AttendCnfg? attendCnfg;

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'VhCnfg': vhCnfg?.toJson(),
    'AttendCnfg': attendCnfg?.toJson(),
  };
}

class AttendCnfg {
  AttendCnfg({required this.attendanceMode, required this.uploadAttendImages});

  factory AttendCnfg.fromJson(Map<String, dynamic> json) => AttendCnfg(
    attendanceMode: json['AttendanceMode']?.toString(),
    uploadAttendImages: json['UploadAttendImages'] as bool? ?? false,
  );

  final String? attendanceMode; // "FACIAL" | "MANUAL" | "BOTH"
  final bool uploadAttendImages;

  Map<String, dynamic> toJson() => {
    'AttendanceMode': attendanceMode,
    'UploadAttendImages': uploadAttendImages,
  };
}

class VhCnfg {
  VhCnfg({
    required this.isUploadCleaningImage,
    required this.cleaningImageLimit,
    required this.isUploadComplaintImage,
    required this.complaintImageLimit,
  });

  factory VhCnfg.fromJson(Map<String, dynamic> json) => VhCnfg(
    isUploadCleaningImage: json['IsUploadCleaningImage'],
    cleaningImageLimit: json['CleaningImageLimit'],
    isUploadComplaintImage: json['IsUploadComplaintImage'],
    complaintImageLimit: json['ComplaintImageLimit'],
  );

  final int cleaningImageLimit;
  final int complaintImageLimit;
  final bool isUploadCleaningImage;
  final bool isUploadComplaintImage;

  Map<String, dynamic> toJson() => {
    'IsUploadCleaningImage': isUploadCleaningImage,
    'CleaningImageLimit': cleaningImageLimit,
    'IsUploadComplaintImage': isUploadComplaintImage,
    'ComplaintImageLimit': complaintImageLimit,
  };
}
