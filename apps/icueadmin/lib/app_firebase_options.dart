import 'package:api_client/api_client.dart';
import 'package:icue_firebase/icue_firebase.dart' show FirebaseOptions;
import 'package:icueadmin/firebase_options_dev.dart' as dev;
import 'package:icueadmin/firebase_options_prod.dart' as prod;

/// Firebase options for [environment], so Firebase always matches the API
/// environment (`--dart-define=ENV=` / `FLAVOR=`).
FirebaseOptions firebaseOptionsFor(ApiEnvironment environment) =>
    environment.isProd
    ? prod.DefaultFirebaseOptions.currentPlatform
    : dev.DefaultFirebaseOptions.currentPlatform;
