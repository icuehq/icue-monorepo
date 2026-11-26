// Config for the `icueadmin-dev` Firebase project (Android dev app).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDhwNHoUIIaKbFQE2WZao_ZYFrzBnxRZDU',
    appId: '1:483508933555:android:a9a5e923e3b332384771c6',
    messagingSenderId: '483508933555',
    projectId: 'icueadmin-dev',
    storageBucket: 'icueadmin-dev.firebasestorage.app',
  );
}
