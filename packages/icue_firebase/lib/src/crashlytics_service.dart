import 'dart:isolate';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_firebase/src/crashlytics_web_stub.dart'
    if (dart.library.js_interop) 'package:icue_firebase/src/crashlytics_web.dart';

/// App-agnostic wrapper around [FirebaseCrashlytics]. Apps never touch
/// Crashlytics directly; use [CrashlyticsService.instance].
class CrashlyticsService {
  CrashlyticsService._();

  static final instance = CrashlyticsService._();

  FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  /// Hooks global error handlers. Call once, after Firebase is initialized.
  /// Collection is on in every build mode, so debug errors reach the project's Crashlytics too.
  Future<void> init() async {
    if (kIsWeb) {
      // A load failure must never block app startup.
      try {
        await initWebCrashlytics();
      } on Object catch (error) {
        debugPrint('Web Crashlytics unavailable: $error');
        return;
      }
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        recordWebError(details.exception, details.stack);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        recordWebError(error, stack);
        return true;
      };
      return;
    }
    await _c.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = _c.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _c.recordError(error, stack, fatal: true);
      return true;
    };
    // Errors thrown in other isolates.
    Isolate.current.addErrorListener(
      RawReceivePort((Object? pair) {
        final [error, stack] = pair! as List;
        _c.recordError(
          error,
          stack == null ? null : StackTrace.fromString(stack.toString()),
          fatal: true,
        );
      }).sendPort,
    );
  }

  /// Tags subsequent reports with the user. Pass null [id] to clear (logout).
  void setUser({
    String? id,
    String? organizationId,
    String? zoneId,
    String? branchId,
    String? schoolName,
  }) {
    if (kIsWeb) {
      setWebUser(
        id: id,
        organizationId: organizationId,
        zoneId: zoneId,
        branchId: branchId,
        schoolName: schoolName,
      );
      return;
    }
    _c.setUserIdentifier(id ?? '');
    _c.setCustomKey('organizationId', organizationId ?? '');
    _c.setCustomKey('zoneId', zoneId ?? '');
    _c.setCustomKey('branchId', branchId ?? '');
    _c.setCustomKey('schoolName', schoolName ?? '');
  }

  void clearUser() => setUser();

  void setCustomKey(String key, String value) {
    if (kIsWeb) {
      setWebCustomKey(key, value);
      return;
    }
    _c.setCustomKey(key, value);
  }

  /// Records a handled error as non-fatal.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    List<Object> information = const [],
  }) async {
    if (kIsWeb) {
      recordWebError(error, stack, reason: reason, information: information);
      return;
    }
    await _c.recordError(
      error,
      stack,
      reason: reason,
      information: information,
    );
  }

  void log(String message) {
    if (kIsWeb) {
      logWeb(message);
      return;
    }
    _c.log(message);
  }
}
