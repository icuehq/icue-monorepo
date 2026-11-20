import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_firebase/src/backend.dart';

/// Host of the local Firebase emulators, from `--dart-define=FIREBASE_EMULATOR=`:
/// `10.0.2.2` on the Android emulator, `127.0.0.1` on the iOS simulator, the
/// Mac's LAN IP on a physical device. Empty = real Firebase.
const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR');

/// Ports from `firebase/firebase.json`.
const _authPort = 9109;
const _firestorePort = 8190;
const _functionsPort = 5011;
const _storagePort = 9209;

/// True when this build talks to the emulators. Never in release builds.
bool get usesEmulator => emulatorHost.isNotEmpty && !kReleaseMode;

/// Points every Firebase service at the emulators; call after
/// `Firebase.initializeApp`. No-op unless [usesEmulator].
Future<void> connectEmulators() async {
  if (!usesEmulator) return;
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, _authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, _firestorePort);
  FirebaseFunctions.instanceFor(region: functionsRegion)
      .useFunctionsEmulator(emulatorHost, _functionsPort);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, _storagePort);
}

/// Unsigned custom token for the Auth emulator, which accepts them without a
/// signature. Stands in for Node's `/v1.0/firebaseToken` in local runs.
/// Null unless [usesEmulator].
String? emulatorCustomToken(String uid, Map<String, Object?> claims) {
  if (!usesEmulator) return null;
  String part(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  const issuer = 'firebase-auth-emulator@example.com';
  return [
    part({'alg': 'none', 'typ': 'JWT'}),
    part({
      'iss': issuer,
      'sub': issuer,
      'aud': 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
      'iat': now,
      'exp': now + 3600,
      'uid': uid,
      'claims': claims,
    }),
    '',
  ].join('.');
}
