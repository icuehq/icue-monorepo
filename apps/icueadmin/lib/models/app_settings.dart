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
    this.fmsCnfg,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    err: json['err'] ?? false,
    message: json['message'] ?? '',
    vhCnfg: json['VhCnfg'] == null ? null : VhCnfg.fromJson(json['VhCnfg']),
    attendCnfg: json['AttendCnfg'] == null
        ? null
        : AttendCnfg.fromJson(json['AttendCnfg']),
    fmsCnfg: json['FmsCnfg'] == null ? null : FmsCnfg.fromJson(json['FmsCnfg']),
  );
  final bool err;
  final String message;
  final VhCnfg? vhCnfg;
  final AttendCnfg? attendCnfg;
  final FmsCnfg? fmsCnfg;

  AppSettings copyWith({
    bool? err,
    String? message,
    VhCnfg? vhCnfg,
    AttendCnfg? attendCnfg,
    FmsCnfg? fmsCnfg,
  }) => AppSettings(
    err: err ?? this.err,
    message: message ?? this.message,
    vhCnfg: vhCnfg ?? this.vhCnfg,
    attendCnfg: attendCnfg ?? this.attendCnfg,
    fmsCnfg: fmsCnfg ?? this.fmsCnfg,
  );

  Map<String, dynamic> toJson() => {
    'err': err,
    'message': message,
    'VhCnfg': vhCnfg?.toJson(),
    'AttendCnfg': attendCnfg?.toJson(),
    'FmsCnfg': fmsCnfg?.toJson(),
  };
}

class AttendCnfg {
  AttendCnfg({
    required this.attendanceMode,
    required this.uploadAttendImages,
    this.uploadStuImgWithEmb,
  });

  factory AttendCnfg.fromJson(Map<String, dynamic> json) => AttendCnfg(
    attendanceMode: json['AttendanceMode']?.toString(),
    uploadAttendImages: json['UploadAttendImages'] as bool? ?? false,
    uploadStuImgWithEmb: json['UploadStuImgWithEmb'],
  );
  final String? attendanceMode; // "FACIAL" | "MANUAL" | "BOTH"
  final bool uploadAttendImages;
  final bool? uploadStuImgWithEmb;

  AttendCnfg copyWith({
    String? attendanceMode,
    bool? uploadAttendImages,
    bool? uploadStuImgWithEmb,
  }) => AttendCnfg(
    attendanceMode: attendanceMode ?? this.attendanceMode,
    uploadAttendImages: uploadAttendImages ?? this.uploadAttendImages,
    uploadStuImgWithEmb: uploadStuImgWithEmb ?? this.uploadStuImgWithEmb,
  );

  Map<String, dynamic> toJson() => {
    'AttendanceMode': attendanceMode,
    'UploadAttendImages': uploadAttendImages,
    'UploadStuImgWithEmb': uploadStuImgWithEmb,
  };
}

class FmsCnfg {
  FmsCnfg({this.isBasicFacilityMgmt, this.maxCleaningImages});

  factory FmsCnfg.fromJson(Map<String, dynamic> json) => FmsCnfg(
    isBasicFacilityMgmt: json['IsBasicFacilityMgmt'],
    maxCleaningImages: json['MaxCleaningImages'],
  );
  final bool? isBasicFacilityMgmt;
  final int? maxCleaningImages;

  FmsCnfg copyWith({bool? isBasicFacilityMgmt, int? maxCleaningImages}) =>
      FmsCnfg(
        isBasicFacilityMgmt: isBasicFacilityMgmt ?? this.isBasicFacilityMgmt,
        maxCleaningImages: maxCleaningImages ?? this.maxCleaningImages,
      );

  Map<String, dynamic> toJson() => {
    'IsBasicFacilityMgmt': isBasicFacilityMgmt,
    'MaxCleaningImages': maxCleaningImages,
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

  VhCnfg copyWith({
    bool? isUploadCleaningImage,
    int? cleaningImageLimit,
    bool? isUploadComplaintImage,
    int? complaintImageLimit,
  }) => VhCnfg(
    isUploadCleaningImage: isUploadCleaningImage ?? this.isUploadCleaningImage,
    cleaningImageLimit: cleaningImageLimit ?? this.cleaningImageLimit,
    isUploadComplaintImage:
        isUploadComplaintImage ?? this.isUploadComplaintImage,
    complaintImageLimit: complaintImageLimit ?? this.complaintImageLimit,
  );

  Map<String, dynamic> toJson() => {
    'IsUploadCleaningImage': isUploadCleaningImage,
    'CleaningImageLimit': cleaningImageLimit,
    'IsUploadComplaintImage': isUploadComplaintImage,
    'ComplaintImageLimit': complaintImageLimit,
  };
}
