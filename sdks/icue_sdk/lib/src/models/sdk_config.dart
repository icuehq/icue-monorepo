import 'package:flutter/foundation.dart';
import 'package:icue_sdk/src/config/env.dart';
import 'package:icue_sdk/src/models/notification_config.dart';

/// Immutable configuration used to initialize the iCue SDK.
///
/// Provide your API credentials and target environment.
/// Push notifications are completely disabled by default ([IcueNotifications.disabled]).
/// Enable them explicitly via [notifications] when needed.
@immutable
class IcueSdkConfig {
  const IcueSdkConfig({
    required this.apiKey,
    required this.apiUser,
    this.identificationNo,
    this.env = IcueEnvironment.prod,
    this.restoreSession = false,
    this.notifications = const IcueNotifications.disabled(),
  });

  /// The API key issued for your iCue integration.
  final String apiKey;

  /// The API user or client identifier associated with [apiKey].
  final String apiUser;

  /// Optional student identification number (e.g. Admission Number).
  final String? identificationNo;

  /// The environment to target for all SDK operations.
  final IcueEnvironment env;

  /// Whether the SDK should automatically restore the last saved student session
  /// on cold start. Defaults to `false` (explicit student selection recommended).
  final bool restoreSession;

  /// The push notification contract for the SDK.
  /// Defaults to [IcueNotifications.disabled()].
  final IcueNotifications notifications;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueSdkConfig &&
          runtimeType == other.runtimeType &&
          apiKey == other.apiKey &&
          apiUser == other.apiUser &&
          identificationNo == other.identificationNo &&
          env == other.env &&
          restoreSession == other.restoreSession &&
          notifications == other.notifications;

  @override
  int get hashCode => Object.hash(
        apiKey,
        apiUser,
        identificationNo,
        env,
        restoreSession,
        notifications,
      );
}
