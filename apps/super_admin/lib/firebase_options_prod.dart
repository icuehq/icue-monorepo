// Config for the `icueadmin` Firebase project (Android prod app).
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
    apiKey: 'AIzaSyBxwHkHassOzRhz9haVrJhlHcmKygGkx0Q',
    appId: '1:682367186948:android:333a338e190f3327b81d51',
    messagingSenderId: '682367186948',
    projectId: 'icueadmin',
    storageBucket: 'icueadmin.firebasestorage.app',
  );
}
