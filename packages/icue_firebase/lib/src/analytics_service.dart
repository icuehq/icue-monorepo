import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// App-agnostic wrapper around [FirebaseAnalytics]. Apps never touch
/// Analytics directly; use [AnalyticsService.instance].
class AnalyticsService {
  AnalyticsService._();

  static final instance = AnalyticsService._();

  FirebaseAnalytics get _a => FirebaseAnalytics.instance;

  /// Collection is on in release builds only.
  Future<void> init() => _a.setAnalyticsCollectionEnabled(!kDebugMode);

  /// Add to `GoRouter(observers: [...])` / `MaterialApp.navigatorObservers`
  /// for automatic screen_view events (routes must be named).
  late final observer = FirebaseAnalyticsObserver(analytics: _a);

  /// Tags subsequent events with the user. Pass null [id] to clear (logout).
  Future<void> setUser({
    String? id,
    Map<String, String?> properties = const {},
  }) async {
    await _a.setUserId(id: id);
    for (final e in properties.entries) {
      // Firebase caps property values at 36 chars.
      final v = id == null ? null : e.value;
      await _a.setUserProperty(
        name: e.key,
        value: v != null && v.length > 36 ? v.substring(0, 36) : v,
      );
    }
  }

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _a.logEvent(name: name, parameters: parameters);

  Future<void> logLogin(String method) => _a.logLogin(loginMethod: method);
}
