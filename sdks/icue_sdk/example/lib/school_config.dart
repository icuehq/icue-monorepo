import 'package:flutter/foundation.dart';
import 'package:icue_sdk/icue_sdk.dart';

/// Pre-configured school details including credentials and student identification numbers.
class SchoolConfig {
  const SchoolConfig({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.apiUser,
    required this.studentIds,
    this.env = IcueEnvironment.dev,
  });

  final String apiKey;
  final String apiUser;
  final IcueEnvironment env;
  final String id;
  final String name;
  final List<String> studentIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SchoolConfig &&
        other.id == id &&
        other.name == name &&
        other.apiKey == apiKey &&
        other.apiUser == apiUser &&
        other.env == env &&
        listEquals(other.studentIds, studentIds);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, apiKey, apiUser, env, Object.hashAll(studentIds));

  IcueSdkConfig toSdkConfig({IcueFirebaseOptions? firebaseOptions}) {
    return IcueSdkConfig(
      apiKey: apiKey,
      apiUser: apiUser,
      env: env,
      notifications: firebaseOptions != null
          ? IcueNotifications.firebaseManaged(
              firebaseOptions: firebaseOptions,
              presentation: IcueNotificationPresentation.sdkBanner,
            )
          : const IcueNotifications.disabled(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'apiKey': apiKey,
      'apiUser': apiUser,
      'studentIds': studentIds,
      'env': env == IcueEnvironment.prod ? 'prod' : 'dev',
    };
  }

  factory SchoolConfig.fromJson(Map<String, dynamic> json) {
    return SchoolConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      apiUser: json['apiUser'] as String? ?? '',
      studentIds:
          (json['studentIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      env: json['env'] == 'prod' ? IcueEnvironment.prod : IcueEnvironment.dev,
    );
  }

  SchoolConfig copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? apiKey,
    String? apiUser,
    List<String>? studentIds,
    IcueEnvironment? env,
  }) {
    return SchoolConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      apiUser: apiUser ?? this.apiUser,
      studentIds: studentIds ?? this.studentIds,
      env: env ?? this.env,
    );
  }
}

/// Helper to get the initial list of pre-configured schools.
List<SchoolConfig> get defaultPreconfiguredSchools {
  // Read from environment if specified via --dart-define (e.g. .vscode/launch.json)
  const envApiKey = String.fromEnvironment('ICUE_API_KEY');
  const envApiUser = String.fromEnvironment('ICUE_API_USER');
  const envIdentificationNo = String.fromEnvironment('ICUE_IDENTIFICATION_NO');

  final envStudentIds = envIdentificationNo.isNotEmpty
      ? envIdentificationNo
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
      : <String>[];

  return [
    const SchoolConfig(
      id: 'parentsdkapp',
      name: 'iCue Internal Test School',
      apiKey: String.fromEnvironment('ICUE_API_KEY_PARENTSDKAPP'),
      apiUser: 'parentsdkapp',
      studentIds: ['UT1234000', 'BP1234586', 'UT1233654'],
      env: IcueEnvironment.dev,
    ),
    SchoolConfig(
      id: 'chirec_kp',
      name: 'CHIREC International School',
      apiKey: envApiKey.isNotEmpty
          ? envApiKey
          : const String.fromEnvironment('ICUE_API_KEY_CHIREC_KP'),
      apiUser: envApiUser.isNotEmpty ? envApiUser : 'chirec_kp',
      studentIds: envStudentIds.isNotEmpty
          ? envStudentIds
          : const ['7460', '7978'],
      env: IcueEnvironment.dev,
    ),
    const SchoolConfig(
      id: 'tsus_dev',
      name: 'The Shriram Universal School (TSUS)',
      apiKey: String.fromEnvironment('ICUE_API_KEY_TSUS_DEV'),
      apiUser: 'shriram_universal',
      studentIds: ['TSUS689', 'TSUS690'],
      env: IcueEnvironment.dev,
    ),
  ];
}
