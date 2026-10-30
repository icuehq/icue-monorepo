import 'package:flutter/foundation.dart';

@immutable
class CleaningPart {
  const CleaningPart({required this.id, required this.name});

  factory CleaningPart.fromJson(Map<String, dynamic> json) => CleaningPart(
    id: json['Id'] as int? ?? 0,
    name: json['Name'] as String? ?? '',
  );

  final int id;
  final String name;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CleaningPart &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class VehicleCleaningPartsResponse {
  const VehicleCleaningPartsResponse({
    this.err = false,
    this.message = '',
    this.data = const <CleaningPart>[],
  });

  factory VehicleCleaningPartsResponse.fromJson(Map<String, dynamic> json) =>
      VehicleCleaningPartsResponse(
        err: json['err'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data:
            (json['data'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(CleaningPart.fromJson)
                .toList() ??
            const <CleaningPart>[],
      );

  final bool err;
  final String message;
  final List<CleaningPart> data;
}

@immutable
class CleanedVehicleEntry {
  const CleanedVehicleEntry({required this.id, required this.vehicleNo});

  final int id;
  final String vehicleNo;

  Map<String, dynamic> toJson() => {'Id': id, 'VehicleNo': vehicleNo};
}

@immutable
class SubmitCleaningDataRequest {
  const SubmitCleaningDataRequest({
    required this.cleanedPartIds,
    required this.vehicles,
  });

  final List<int> cleanedPartIds;
  final List<CleanedVehicleEntry> vehicles;

  Map<String, dynamic> toJson() => {
    'CleanedPartIds': cleanedPartIds,
    'Vehicles': vehicles.map((v) => v.toJson()).toList(),
  };
}

@immutable
class CleaningSubmissionResult {
  const CleaningSubmissionResult({
    required this.success,
    this.failedCount = 0,
    this.failedMessages = const <String>[],
  });

  final bool success;
  final int failedCount;
  final List<String> failedMessages;
}
