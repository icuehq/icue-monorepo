library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:icue_firebase/src/analytics_service.dart';
import 'package:icue_firebase/src/crashlytics_service.dart';
import 'package:icue_firebase/src/notification_service.dart';

export 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

export 'src/analytics_service.dart';
export 'src/crashlytics_service.dart';
export 'src/notification_service.dart' show NotificationService;

/// Single entry point for every app: pass its generated `DefaultFirebaseOptions`.
/// Add new Firebase services here once.
Future<void> initFirebase(FirebaseOptions options) async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: options);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await CrashlyticsService.instance.init();
  await AnalyticsService.instance.init();
}
