import 'package:flutter/foundation.dart';

/// Per-branch admin app configuration from `/v1.0/getAdminAppSettings`.
@immutable
class AppSettings {
  const AppSettings({this.vehicle, this.attendance});

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    vehicle: json['VhCnfg'] is Map<String, dynamic>
        ? VehicleSettings.fromJson(json['VhCnfg'] as Map<String, dynamic>)
        : null,
    attendance: json['AttendCnfg'] is Map<String, dynamic>
        ? AttendanceSettings.fromJson(
            json['AttendCnfg'] as Map<String, dynamic>,
          )
        : null,
  );

  final VehicleSettings? vehicle;
  final AttendanceSettings? attendance;
}

/// How attendance may be taken and whether photos are required.
@immutable
class AttendanceSettings {
  const AttendanceSettings({this.mode, this.uploadImages = false});

  factory AttendanceSettings.fromJson(Map<String, dynamic> json) =>
      AttendanceSettings(
        mode: (json['AttendanceMode'] as String?)?.toUpperCase(),
        uploadImages: json['UploadAttendImages'] as bool? ?? false,
      );

  /// `MANUAL`, `FACIAL` or `BOTH`; null means everything is allowed.
  final String? mode;
  final bool uploadImages;

  bool get allowsManual => mode == null || mode == 'BOTH' || mode == 'MANUAL';
  bool get allowsFacial => mode == null || mode == 'BOTH' || mode == 'FACIAL';
}

@immutable
class VehicleSettings {
  const VehicleSettings({
    this.cleaningImageLimit = 1,
    this.complaintImageLimit = 1,
  });

  factory VehicleSettings.fromJson(Map<String, dynamic> json) =>
      VehicleSettings(
        cleaningImageLimit: (json['CleaningImageLimit'] as num?)?.toInt() ?? 1,
        complaintImageLimit:
            (json['ComplaintImageLimit'] as num?)?.toInt() ?? 1,
      );

  final int cleaningImageLimit;
  final int complaintImageLimit;
}
