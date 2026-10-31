// Config for the `icueadmin-dev` Firebase project (iOS/Android/web dev apps).
// Regenerate with:
//   flutterfire configure --project=icueadmin-dev --out=lib/firebase_options_dev.dart \
//     --android-package-name=com.thoughtniques.icueadmin.dev \
//     --ios-bundle-id=com.thoughtniques.icueadmin.dev
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDOrnL_ILQo0U6hQxEa6UPIeOziZn3GwSc',
    appId: '1:483508933555:web:1d2ade2818b6c2534771c6',
    messagingSenderId: '483508933555',
    projectId: 'icueadmin-dev',
    authDomain: 'icueadmin-dev.firebaseapp.com',
    storageBucket: 'icueadmin-dev.firebasestorage.app',
    measurementId: 'G-PCEKBYF4T2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDhwNHoUIIaKbFQE2WZao_ZYFrzBnxRZDU',
    appId: '1:483508933555:android:8ee188c89cbd3f9e4771c6',
    messagingSenderId: '483508933555',
    projectId: 'icueadmin-dev',
    storageBucket: 'icueadmin-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCDI8lgwp7tUcrnQV2z8NaGa0FiJVHnEE0',
    appId: '1:483508933555:ios:86ac36962745ce354771c6',
    messagingSenderId: '483508933555',
    projectId: 'icueadmin-dev',
    storageBucket: 'icueadmin-dev.firebasestorage.app',
    iosBundleId: 'com.thoughtniques.icueadmin.dev',
  );
}
