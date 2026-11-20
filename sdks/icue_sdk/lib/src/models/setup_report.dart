import 'package:icue_sdk/src/models/notification_config.dart';

/// Preflight diagnostic report returned by `IcueSdk.checkSetup()`.
///
/// Gives host applications full visibility into SDK initialization state,
/// credentials, notification bindings, navigation readiness, and active student sessions.
class IcueSetupReport {
  const IcueSetupReport({
    required this.isInitialized,
    required this.apiKeyConfigured,
    required this.apiUserConfigured,
    required this.activeIdentificationNo,
    required this.sessionAuthenticated,
    required this.notificationMode,
    required this.firebaseAppAvailable,
    required this.notificationPermission,
    required this.pushTokenRegistered,
    required this.navigatorKeyBound,
    required this.issues,
  });

  /// Whether `IcueSdk.init` has been successfully executed with active configuration.
  final bool isInitialized;

  /// Whether a non-empty API key is configured.
  final bool apiKeyConfigured;

  /// Whether a non-empty API user identifier is configured.
  final bool apiUserConfigured;

  /// The active student identification number, if set.
  final String? activeIdentificationNo;

  /// Whether the active student session is authenticated with backend bearer tokens.
  final bool sessionAuthenticated;

  /// Active notification configuration mode (`disabled`, `hostManaged`, or `firebaseManaged`).
  final String notificationMode;

  /// Whether a default Firebase app is initialized and accessible.
  final bool firebaseAppAvailable;

  /// Current notification permission authorization status.
  final IcuePermissionStatus notificationPermission;

  /// Whether a push notification device token is stored and synchronized.
  final bool pushTokenRegistered;

  /// Whether a root navigator key or external key is bound to the SDK.
  final bool navigatorKeyBound;

  /// List of actionable diagnostic warnings or misconfiguration issues.
  final List<String> issues;

  /// Whether the SDK is fully ready to open live tracking without critical configuration issues.
  bool get isReady =>
      isInitialized && apiKeyConfigured && apiUserConfigured && issues.isEmpty;

  /// Formats the setup report into a clean, human-readable ASCII diagnostic table.
  String toDiagnosticSummary() {
    final buffer = StringBuffer();
    buffer
        .writeln('┌────────────────────────────────────────────────────────┐');
    buffer
        .writeln('│               iCue SDK Diagnostic Report               │');
    buffer
        .writeln('├────────────────────────────────┬───────────────────────┤');
    buffer.writeln(
      '│ SDK Initialized                │ ${_pad(isInitialized ? "✅ Yes" : "❌ No")} │',
    );
    buffer.writeln(
      '│ API Key Configured             │ ${_pad(apiKeyConfigured ? "✅ Yes" : "❌ Missing")} │',
    );
    buffer.writeln(
      '│ API User Configured            │ ${_pad(apiUserConfigured ? "✅ Yes" : "❌ Missing")} │',
    );
    buffer.writeln(
      '│ Active Student ID              │ ${_pad(activeIdentificationNo ?? "None")} │',
    );
    buffer.writeln(
      '│ Session Authenticated          │ ${_pad(sessionAuthenticated ? "✅ Authenticated" : "ℹ️ Deferred")} │',
    );
    buffer.writeln(
      '│ Notification Mode              │ ${_pad(notificationMode)} │',
    );
    buffer.writeln(
      '│ Push Token Registered          │ ${_pad(pushTokenRegistered ? "✅ Registered" : "❌ Not registered")} │',
    );
    buffer.writeln(
      '│ Navigator Key Bound            │ ${_pad(navigatorKeyBound ? "✅ Bound" : "❌ Not bound")} │',
    );
    buffer.writeln(
      '│ Status                         │ ${_pad(isReady ? "🚀 READY FOR TRACKING" : "⚠️ ISSUES DETECTED")} │',
    );
    buffer
        .writeln('└────────────────────────────────┴───────────────────────┘');
    if (issues.isNotEmpty) {
      buffer.writeln('\nIssues Detected:');
      for (var i = 0; i < issues.length; i++) {
        buffer.writeln('  ${i + 1}. ${issues[i]}');
      }
    }
    return buffer.toString();
  }

  static String _pad(String text, [int width = 21]) {
    if (text.length >= width) return text.substring(0, width);
    return text.padRight(width);
  }

  @override
  String toString() {
    return 'IcueSetupReport('
        'isInitialized: $isInitialized, '
        'apiKeyConfigured: $apiKeyConfigured, '
        'apiUserConfigured: $apiUserConfigured, '
        'activeStudent: $activeIdentificationNo, '
        'authenticated: $sessionAuthenticated, '
        'notifications: $notificationMode, '
        'permission: $notificationPermission, '
        'tokenRegistered: $pushTokenRegistered, '
        'navigatorBound: $navigatorKeyBound, '
        'issues: ${issues.isEmpty ? "None" : issues.join("; ")})';
  }
}
