import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channel = AndroidNotificationChannel(
  'icue_default',
  'General',
  description: 'General notifications',
  importance: Importance.high,
);

final _local = FlutterLocalNotificationsPlugin();

Future<void> _initLocal({DidReceiveNotificationResponseCallback? onTap}) async {
  await _local.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher_monochrome'),
      // Permission is requested explicitly via requestPermission().
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: onTap,
  );
  await _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_channel);
}

Future<void> _show(RemoteMessage m) {
  final title = m.notification?.title ?? m.data['title'] as String?;
  final body = m.notification?.body ?? m.data['body'] as String?;
  return _local.show(
    id: (m.messageId ?? '${m.sentTime?.millisecondsSinceEpoch}').hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode(m.data),
  );
}

/// Runs in its own isolate while the app is backgrounded/terminated.
/// Messages with a `notification` block are shown by the OS; this only
/// renders data-only messages (title/body in `data`).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.notification != null || message.data['title'] == null) return;
  await _initLocal();
  await _show(message);
}

/// Push notifications for all apps: FCM + local notifications so messages
/// show in foreground (Android), background and terminated states.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  /// Call once after Firebase is initialized and the app can handle
  /// navigation. [onTap] receives the message `data` of a tapped notification.
  Future<void> init({
    required void Function(Map<String, dynamic>) onTap,
  }) async {
    void tap(String? payload) {
      if (payload == null || payload.isEmpty) return;
      onTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    }

    await _initLocal(onTap: (r) => tap(r.payload));

    // iOS renders foreground notifications natively; Android needs a local one.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen((m) {
      if (defaultTargetPlatform == TargetPlatform.android) _show(m);
    });

    // Tapped while backgrounded / launched from terminated.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onTap(m.data));
    final initial = await _fcm.getInitialMessage();
    if (initial != null) onTap(initial.data);
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      tap(launch?.notificationResponse?.payload);
    }
  }

  /// Asks for notification permission (Android 13+ / iOS). Returns granted.
  Future<bool> requestPermission() async {
    final s = await _fcm.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  // ponytail: FCM token API is deprecated in favour of register()/onRegistered
  // (Firebase Installation ID); switch once the backend sends to FIDs.
  Future<String?> get token async {
    // iOS: the FCM token isn't available until APNs has issued its token.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _fcm.getAPNSToken() == null) {
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    // Deprecated token API, see note above.
    // ignore: deprecated_member_use
    return _fcm.getToken();
  }

  // Deprecated token API, see note above.
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;
}
