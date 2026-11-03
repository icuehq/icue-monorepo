library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:icue_firebase/src/analytics_service.dart';
import 'package:icue_firebase/src/crashlytics_service.dart';
import 'package:icue_firebase/src/emulator.dart';
import 'package:icue_firebase/src/notification_service.dart';

export 'package:cloud_firestore/cloud_firestore.dart';
export 'package:cloud_functions/cloud_functions.dart'
    show FirebaseFunctionsException;
export 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException, User;
export 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseOptions;
export 'package:firebase_storage/firebase_storage.dart'
    show FirebaseStorage, Reference;

export 'src/analytics_service.dart';
export 'src/backend.dart';
export 'src/contracts.g.dart';
export 'src/crashlytics_service.dart';
export 'src/emulator.dart' show emulatorCustomToken, emulatorHost, usesEmulator;
export 'src/notification_service.dart' show NotificationService;
export 'src/school_data.dart';

/// Single entry point for every app: pass its generated `DefaultFirebaseOptions`.
/// Add new Firebase services here once.
Future<void> initFirebase(FirebaseOptions options) async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: options);
  await connectEmulators();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await CrashlyticsService.instance.init();
  await AnalyticsService.instance.init();
}
