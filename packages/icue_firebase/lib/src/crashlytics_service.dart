import 'dart:isolate';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// App-agnostic wrapper around [FirebaseCrashlytics]. Apps never touch
/// Crashlytics directly; use [CrashlyticsService.instance].
class CrashlyticsService {
  CrashlyticsService._();

  static final instance = CrashlyticsService._();

  FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  /// Crashlytics has no web implementation; every call is a no-op there.
  static const _supported = !kIsWeb;

  /// Hooks global error handlers. Call once, after Firebase is initialized.
  /// Collection is on in release builds only.
  Future<void> init() async {
    if (!_supported) return;
    await _c.setCrashlyticsCollectionEnabled(!kDebugMode);
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
    if (!_supported) return;
    _c.setUserIdentifier(id ?? '');
    _c.setCustomKey('organizationId', organizationId ?? '');
    _c.setCustomKey('zoneId', zoneId ?? '');
    _c.setCustomKey('branchId', branchId ?? '');
    _c.setCustomKey('schoolName', schoolName ?? '');
  }

  void clearUser() => setUser();

  /// Records a handled error as non-fatal.
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    List<Object> information = const [],
  }) {
    if (!_supported) return;
    _c.recordError(error, stack, reason: reason, information: information);
  }

  void log(String message) {
    if (_supported) _c.log(message);
  }
}
