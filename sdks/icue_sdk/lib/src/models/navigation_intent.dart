import 'package:flutter/foundation.dart';
import 'package:icue_sdk/src/models/icue_notification.dart';

/// Represents an intent to navigate within the host application to a specific
/// student's live tracking experience or related iCue feature.
@immutable
class IcueNavigationIntent {
  const IcueNavigationIntent({
    required this.identificationNo,
    this.notification,
    this.action,
    this.extras = const <String, dynamic>{},
  });

  /// The target student identification number / admission number.
  final String identificationNo;

  /// The originating [IcueNotification], if navigation was triggered by a notification.
  final IcueNotification? notification;

  /// The action identifier associated with this navigation (e.g. `bus_tracking`, `live_tracking`).
  final String? action;

  /// Additional metadata or route arguments.
  final Map<String, dynamic> extras;

  @override
  String toString() =>
      'IcueNavigationIntent(identificationNo: $identificationNo, action: $action, notification: $notification)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueNavigationIntent &&
          runtimeType == other.runtimeType &&
          identificationNo == other.identificationNo &&
          action == other.action &&
          notification == other.notification;

  @override
  int get hashCode => Object.hash(identificationNo, action, notification);
}
