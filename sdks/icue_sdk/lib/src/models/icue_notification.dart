import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Pure-Dart representation of an iCue notification.
///
/// Decouples host applications from Firebase Cloud Messaging (`RemoteMessage`)
/// so that notification handlers, streams, and UI widgets can be used without
/// direct dependencies on Firebase packages.
/// Payload keys that carry the student's admission number, in priority order.
const List<String> icueAdmissionKeys = <String>[
  'AdmissionNo',
  'admissionNo',
  'admission_no',
  'StudentId',
];

/// Reads the admission number from [map] using [icueAdmissionKeys].
String? icueAdmissionNoFrom(Map<dynamic, dynamic>? map) {
  if (map == null) return null;
  for (final key in icueAdmissionKeys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

@immutable
class IcueNotification {
  const IcueNotification({
    this.title,
    this.body,
    this.data = const <String, dynamic>{},
    this.admissionNo,
    this.action,
    this.messageId,
    this.sentTime,
    this.rawPayload,
  });

  /// Creates an [IcueNotification] from a raw JSON/Map payload.
  factory IcueNotification.fromMap(Map<String, dynamic> map) {
    final nestedData = map['data'];
    final nestedMap = nestedData is Map ? nestedData : null;

    final admissionNo =
        icueAdmissionNoFrom(map) ?? icueAdmissionNoFrom(nestedMap);
    final action =
        (map['action'] ?? nestedMap?['action'] ?? map['click_action'])
            ?.toString();

    final title = map['title']?.toString() ??
        (map['notification'] is Map
            ? (map['notification'] as Map)['title']?.toString()
            : null) ??
        nestedMap?['title']?.toString();
    final body = map['body']?.toString() ??
        (map['notification'] is Map
            ? (map['notification'] as Map)['body']?.toString()
            : null) ??
        nestedMap?['body']?.toString();

    DateTime? sentTime;
    if (map['sentTime'] is int) {
      sentTime = DateTime.fromMillisecondsSinceEpoch(map['sentTime'] as int);
    } else if (map['sentTime'] is String) {
      sentTime = DateTime.tryParse(map['sentTime'] as String);
    }

    return IcueNotification(
      title: title,
      body: body,
      data: Map<String, dynamic>.unmodifiable(map),
      admissionNo: admissionNo != null && admissionNo.trim().isNotEmpty
          ? admissionNo.trim()
          : null,
      action: action,
      messageId: map['messageId']?.toString() ?? map['id']?.toString(),
      sentTime: sentTime,
      rawPayload: map,
    );
  }

  /// Creates an [IcueNotification] from a Firebase Cloud Messaging [RemoteMessage].
  factory IcueNotification.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final nestedData = data['data'];
    final nestedMap = nestedData is Map ? nestedData : null;

    final admissionNo =
        (data['AdmissionNo'] ?? nestedMap?['AdmissionNo'])?.toString();
    final action =
        (data['action'] ?? nestedMap?['action'] ?? data['click_action'])
            ?.toString();

    return IcueNotification(
      title: message.notification?.title ?? data['title']?.toString(),
      body: message.notification?.body ?? data['body']?.toString(),
      data: Map<String, dynamic>.unmodifiable(data),
      admissionNo: admissionNo != null && admissionNo.trim().isNotEmpty
          ? admissionNo.trim()
          : null,
      action: action,
      messageId: message.messageId,
      sentTime: message.sentTime,
      rawPayload: message,
    );
  }

  /// The notification title, if present.
  final String? title;

  /// The notification body text, if present.
  final String? body;

  /// The payload data map.
  final Map<String, dynamic> data;

  /// The student identification number / admission number extracted from the payload.
  final String? admissionNo;

  /// Optional action associated with the notification (e.g. `bus_tracking`, `live_tracking`).
  final String? action;

  /// Unique identifier of the notification message, if available.
  final String? messageId;

  /// Timestamp when the message was sent by the server.
  final DateTime? sentTime;

  /// The raw originating payload object (such as [RemoteMessage] or raw `Map`).
  final dynamic rawPayload;

  /// Converts this notification back into a map representation.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      'data': data,
      if (admissionNo != null) 'AdmissionNo': admissionNo,
      if (action != null) 'action': action,
      if (messageId != null) 'messageId': messageId,
      if (sentTime != null) 'sentTime': sentTime!.millisecondsSinceEpoch,
    };
  }

  IcueNotification copyWith({
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? admissionNo,
    String? action,
    String? messageId,
    DateTime? sentTime,
    dynamic rawPayload,
  }) {
    return IcueNotification(
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      admissionNo: admissionNo ?? this.admissionNo,
      action: action ?? this.action,
      messageId: messageId ?? this.messageId,
      sentTime: sentTime ?? this.sentTime,
      rawPayload: rawPayload ?? this.rawPayload,
    );
  }

  @override
  String toString() =>
      'IcueNotification(messageId: $messageId, admissionNo: $admissionNo, title: $title, action: $action)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueNotification &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          admissionNo == other.admissionNo &&
          title == other.title &&
          body == other.body &&
          action == other.action;

  @override
  int get hashCode => Object.hash(messageId, admissionNo, title, body, action);
}
