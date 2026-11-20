import 'dart:async';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:icue_sdk/live_tracking_module.dart';
import 'package:icue_sdk/src/config/env.dart';
import 'package:icue_sdk/src/models/icue_notification.dart';
import 'package:icue_sdk/src/models/launch_result.dart';
import 'package:icue_sdk/src/models/navigation_intent.dart';
import 'package:icue_sdk/src/models/notification_config.dart';
import 'package:icue_sdk/src/models/sdk_config.dart';
import 'package:icue_sdk/src/models/setup_report.dart';
import 'package:icue_sdk/src/services/injectable.dart';
import 'package:icue_sdk/src/services/notification_service.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:icue_sdk/src/version.dart';

export 'package:icue_sdk/src/config/env.dart' show IcueEnvironment;
export 'package:icue_sdk/src/models/icue_notification.dart'
    show IcueNotification;
export 'package:icue_sdk/src/models/launch_result.dart'
    show
        IcueException,
        IcueInvalidStudentException,
        IcueLaunchBuffered,
        IcueLaunchFailure,
        IcueLaunchResult,
        IcueLaunchSuccess,
        IcueNavigationException,
        IcueNotInitializedException;
export 'package:icue_sdk/src/models/navigation_intent.dart'
    show IcueNavigationIntent;
export 'package:icue_sdk/src/models/notification_config.dart'
    show
        IcueFirebaseOptions,
        IcueNotificationPresentation,
        IcueNotifications,
        IcueNotificationsDisabled,
        IcueNotificationsFirebaseManaged,
        IcueNotificationsHostManaged,
        IcuePermissionStatus,
        IcuePlatformCredentials;
export 'package:icue_sdk/src/models/sdk_config.dart' show IcueSdkConfig;
export 'package:icue_sdk/src/models/setup_report.dart' show IcueSetupReport;

/// Callback signature for handling incoming iCue notifications.
typedef IcueNotificationCallback = void Function(IcueNotification notification);

/// Callback signature for handling iCue navigation intents.
typedef IcueNavigationIntentCallback = void Function(
  IcueNavigationIntent intent,
);

/// Callback signature for handling iCue notification tap events.
typedef IcueNotificationTapCallback = void Function(
  IcueNotification notification,
);

/// A [NavigatorObserver] that monitors route changes and automatically
/// processes pending notification navigation intents when the navigator is ready.
class IcueNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    IcueSdk.processPendingNavigation();
  }
}

/// Public API manager for iCue push notifications and navigation intents.
///
/// Accessed via [IcueSdk.notifications].
class IcueNotificationManager {
  const IcueNotificationManager._();

  static final StreamController<IcueNotification> _receivedController =
      StreamController<IcueNotification>.broadcast();
  static final StreamController<IcueNavigationIntent> _intentController =
      StreamController<IcueNavigationIntent>.broadcast();
  static final StreamController<IcueNotification> _tappedController =
      StreamController<IcueNotification>.broadcast();

  /// Internal dispatcher for incoming notification events.
  static void dispatchNotificationReceived(IcueNotification notification) {
    if (_receivedController.hasListener) {
      _receivedController.add(notification);
    }
  }

  /// Internal dispatcher for navigation intents.
  static void dispatchNavigationIntent(IcueNavigationIntent intent) {
    if (_intentController.hasListener) {
      _intentController.add(intent);
    }
  }

  /// Internal dispatcher for notification tap interactions.
  static void dispatchNotificationTapped(IcueNotification notification) {
    if (_tappedController.hasListener) {
      _tappedController.add(notification);
    }
  }

  /// Stream of incoming iCue push notifications received while the app is in the foreground.
  ///
  /// Can be subscribed to at any point in the application lifecycle (including before [IcueSdk.init]).
  Stream<IcueNotification> get onNotificationReceived =>
      _receivedController.stream;

  /// Stream of navigation intents (e.g. from notification taps or deep links).
  ///
  /// Can be subscribed to at any point in the application lifecycle (including before [IcueSdk.init]).
  Stream<IcueNavigationIntent> get onNavigationIntent =>
      _intentController.stream;

  /// Stream of notification tap interactions.
  ///
  /// Can be subscribed to at any point in the application lifecycle (including before [IcueSdk.init]).
  Stream<IcueNotification> get onNotificationTapped => _tappedController.stream;

  /// Configures push notification behavior at runtime.
  Future<void> configure(IcueNotifications config) async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    await getIt<NotificationService>().configure(config);
  }

  /// Manually supplies a push notification device token to the SDK.
  ///
  /// The token will be cached locally and synchronized with the backend once
  /// a student session is active.
  Future<void> setToken(String token) async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    await getIt<NotificationService>().setToken(token);
  }

  /// Synchronizes the active device token with the iCue backend.
  ///
  /// Returns `true` if the backend confirmed token registration.
  Future<bool> syncTokenWithBackend({
    String? studentId,
    bool force = false,
  }) async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    return getIt<NotificationService>().syncTokenWithBackend(
      studentId: studentId,
      force: force,
    );
  }

  /// Unregisters the device push token from the iCue backend.
  ///
  /// Host applications retain ownership of their FCM/APNs token; this method
  /// only removes backend delivery associations without invalidating the token locally.
  Future<bool> unregisterToken() async {
    if (!getIt.isRegistered<NotificationService>()) return true;
    return getIt<NotificationService>().unregisterToken();
  }

  /// Explicitly destroys the Firebase Cloud Messaging registration token from Firebase servers.
  ///
  /// Only call this if you want to invalidate the device token across your entire application.
  Future<void> invalidateProviderToken() async {
    if (!getIt.isRegistered<NotificationService>()) return;
    await getIt<NotificationService>().invalidateProviderToken();
  }

  /// Checks the current push notification permission status.
  Future<IcuePermissionStatus> get permissionStatus async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    return getIt<NotificationService>().getPermissionStatus();
  }

  /// Requests notification permissions from the platform.
  Future<IcuePermissionStatus> requestPermission() async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    return getIt<NotificationService>().requestPermission();
  }

  /// Checks whether notification permission is authorized or provisional.
  Future<bool> get isPermissionGranted async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    return getIt<NotificationService>().isPermissionGranted();
  }

  /// Registers a specific student ID for push notifications.
  ///
  /// Returns `true` if backend registration confirmed success.
  Future<bool> registerStudent(String studentId, {String? token}) async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    return getIt<NotificationService>()
        .registerStudent(studentId, token: token);
  }

  /// Unregisters a specific student ID from push notifications on the iCue backend.
  ///
  /// Returns `true` if backend unregistration confirmed success.
  Future<bool> unregisterStudent(String studentId, {String? token}) async {
    if (!getIt.isRegistered<NotificationService>()) return true;
    return getIt<NotificationService>()
        .unregisterStudent(studentId, token: token);
  }

  /// Unregisters all linked students from push notifications on the iCue backend.
  ///
  /// Returns `true` if all backend unregistrations succeeded.
  Future<bool> unregisterAllStudents({String? token}) async {
    if (!getIt.isRegistered<NotificationService>()) return true;
    return getIt<NotificationService>().unregisterAllStudents(token: token);
  }

  /// Registers multiple student IDs for push notifications in sequence.
  ///
  /// Returns `true` if all backend registrations succeeded.
  Future<bool> registerStudents(
    List<String> studentIds, {
    String? token,
  }) async {
    var allSuccess = true;
    for (final id in studentIds) {
      final success = await registerStudent(id, token: token);
      if (!success) allSuccess = false;
    }
    return allSuccess;
  }

  /// Returns the list of student identification numbers currently registered for push notifications.
  Future<List<String>> getRegisteredStudents() async {
    if (!getIt.isRegistered<SessionService>()) {
      await configureDependencies();
    }
    return getIt<SessionService>().getRegisteredStudents();
  }

  /// Forwards an incoming push notification into the SDK's presentation and event pipeline.
  ///
  /// Accepts [RemoteMessage], [IcueNotification], or a raw `Map<String, dynamic>` payload.
  Future<void> handleMessage(dynamic messageOrPayload) async {
    final notification = switch (messageOrPayload) {
      final IcueNotification notif => notif,
      final RemoteMessage msg => IcueNotification.fromRemoteMessage(msg),
      final Map<String, dynamic> map => IcueNotification.fromMap(map),
      _ => IcueNotification.fromMap(const {}),
    };
    await handleIncomingNotification(notification);
  }

  /// Forwards a notification tap interaction into the SDK pipeline and triggers live tracking navigation.
  ///
  /// Accepts [RemoteMessage], [IcueNotification], or a raw `Map<String, dynamic>` payload.
  Future<void> handleTap(
    dynamic messageOrPayload, {
    BuildContext? context,
  }) async {
    final notification = switch (messageOrPayload) {
      final IcueNotification notif => notif,
      final RemoteMessage msg => IcueNotification.fromRemoteMessage(msg),
      final Map<String, dynamic> map => IcueNotification.fromMap(map),
      _ => IcueNotification.fromMap(const {}),
    };
    await handleNotificationTap(notification, context: context);
  }

  /// Parses a raw payload map and routes to [handleNotificationTap] or [handleIncomingNotification].
  Future<void> handleRawPayload(
    Map<String, dynamic> payload, {
    BuildContext? context,
    bool isTap = true,
  }) async {
    final notification = IcueNotification.fromMap(payload);
    if (isTap) {
      await handleNotificationTap(notification, context: context);
    } else {
      await handleIncomingNotification(notification);
    }
  }

  /// Forwards an incoming [IcueNotification] into the SDK's presentation and event pipeline.
  Future<void> handleIncomingNotification(IcueNotification notification) async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    await getIt<NotificationService>().handleIncomingNotification(notification);
  }

  /// Forwards a notification tap interaction into the SDK pipeline.
  Future<void> handleNotificationTap(
    IcueNotification notification, {
    BuildContext? context,
  }) async {
    if (!getIt.isRegistered<NotificationService>()) {
      await configureDependencies();
    }
    await getIt<NotificationService>().handleInteraction(
      notification,
      source: 'manualTap',
      context: (context?.mounted ?? false) ? context : null,
    );
  }

  /// Returns the current active notification configuration.
  IcueNotifications get currentConfig {
    if (getIt.isRegistered<NotificationService>()) {
      return getIt<NotificationService>().currentConfig;
    }
    return const IcueNotifications.disabled();
  }

  /// Whether notification services are configured.
  bool get isConfigured {
    if (getIt.isRegistered<NotificationService>()) {
      return getIt<NotificationService>().isConfigured;
    }
    return false;
  }
}

/// Main entry point for bootstrapping and launching iCue features on demand.
///
/// Initialize on demand with [init] whenever required in your application
/// lifecycle. Use [openLiveTracking] to navigate into the live tracking flow.
class IcueSdk {
  /// The SDK version, e.g. `0.2.0` or `0.2.0-beta.3`.
  static const String version = icueSdkVersion;

  /// Whether this is a beta build (version contains `-beta`). Betas may have
  /// known issues and are not meant for production releases.
  static bool get isBeta => icueSdkIsBeta;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Dedicated manager for push notification bindings, permissions, and handlers.
  static const IcueNotificationManager notifications =
      IcueNotificationManager._();

  static IcueSdkConfig? _activeConfig;
  static IcueSdkConfig? _cfg;
  static GlobalKey<NavigatorState>? _externalNavigatorKey;
  static Completer<void>? _initCompleter;

  /// Broadcast stream of iCue push notifications received while the app is in the foreground.
  static Stream<IcueNotification> get onNotificationReceived =>
      notifications.onNotificationReceived;

  /// Broadcast stream of iCue navigation intents.
  static Stream<IcueNavigationIntent> get onNavigationIntent =>
      notifications.onNavigationIntent;

  /// Broadcast stream of iCue notification tap events.
  static Stream<IcueNotification> get onNotificationTapped =>
      notifications.onNotificationTapped;

  /// Returns the current active [BuildContext] from available navigator keys.
  static BuildContext? get currentContext =>
      _externalNavigatorKey?.currentContext ?? navigatorKey.currentContext;

  /// Returns the current active [OverlayState] from available navigator keys.
  static OverlayState? get overlayState =>
      _externalNavigatorKey?.currentState?.overlay ??
      navigatorKey.currentState?.overlay;

  /// Allows host apps to provide their own navigator key.
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _externalNavigatorKey = key;
    processPendingNavigation();
  }

  /// Active configuration if the SDK has been initialized.
  static IcueSdkConfig? get config => _activeConfig ?? _cfg;

  /// Whether the SDK has been initialized with an active configuration.
  static bool get isInitialized => _activeConfig != null;

  /// Initializes or updates the SDK configuration on demand with the provided [cfg].
  ///
  /// This operation is transactional: if initialization fails, all state is rolled back cleanly.
  static Future<void> init(IcueSdkConfig cfg) async {
    if (_activeConfig != null) {
      if (_configEquals(_activeConfig!, cfg)) {
        if (getIt.isRegistered<NotificationService>()) {
          await getIt<NotificationService>().configure(cfg.notifications);
        }
        return;
      }
      return reconfigure(cfg);
    }

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      IcueEnv().init(cfg.env);
      if (icueSdkIsBeta) {
        log(
          'iCue SDK $icueSdkVersion is a BETA build: it may have known issues '
          'and is not recommended for production releases.',
        );
      }

      if (!getIt.isRegistered<SessionService>()) {
        await configureDependencies();
      }
      final session = getIt<SessionService>();
      session.setConfig(cfg);

      if (cfg.identificationNo != null && cfg.identificationNo!.isNotEmpty) {
        await session.setIdentificationNo(cfg.identificationNo!);
      } else if (cfg.restoreSession) {
        await session.restoreLastIdentificationNo();
      }

      // Configure notifications asynchronously based on contract
      await getIt<NotificationService>().configure(cfg.notifications);

      _cfg = cfg;
      _activeConfig = cfg;
      _initCompleter = null;
      completer.complete();
      unawaited(processPendingNavigation());
    } catch (e, st) {
      _initCompleter = null;
      _activeConfig = null;
      _cfg = null;
      completer.completeError(e, st);
      rethrow;
    }
  }

  /// Updates the active SDK configuration at runtime.
  static Future<void> reconfigure(IcueSdkConfig cfg) async {
    final oldConfig = _activeConfig ?? _cfg;
    final credentialsChanged = oldConfig == null ||
        oldConfig.apiKey != cfg.apiKey ||
        oldConfig.apiUser != cfg.apiUser ||
        oldConfig.env != cfg.env;

    IcueEnv().init(cfg.env);

    if (!getIt.isRegistered<SessionService>()) {
      await configureDependencies();
    }
    final session = getIt<SessionService>();

    // 1. Only clear session when core tenant credentials or environment change
    if (credentialsChanged) {
      await session.clearSession();
    }

    // 2. Set new config
    _cfg = cfg;
    _activeConfig = cfg;
    session.setConfig(cfg);

    if (cfg.identificationNo != null && cfg.identificationNo!.isNotEmpty) {
      await session.setIdentificationNo(cfg.identificationNo!);
    }

    if (getIt.isRegistered<NotificationService>()) {
      await getIt<NotificationService>().configure(cfg.notifications);
      await getIt<NotificationService>().syncTokenWithBackend();
    }
  }

  /// Runs preflight checks and returns an [IcueSetupReport] diagnostic summary.
  static Future<IcueSetupReport> checkSetup({
    String? targetStudentId,
  }) async {
    final issues = <String>[];

    final isInit = isInitialized;
    final cfg = config;

    final hasApiKey = cfg?.apiKey != null && cfg!.apiKey.isNotEmpty;
    if (!hasApiKey) {
      issues.add('API key is missing or empty.');
    }

    final hasApiUser = cfg?.apiUser != null && cfg!.apiUser.isNotEmpty;
    if (!hasApiUser) {
      issues.add('API user identifier is missing or empty.');
    }

    final session =
        getIt.isRegistered<SessionService>() ? getIt<SessionService>() : null;
    final activeId =
        targetStudentId ?? session?.identificationNo ?? cfg?.identificationNo;
    final isAuthenticated =
        session?.token != null && session!.token!.isNotEmpty;

    final notifService = getIt.isRegistered<NotificationService>()
        ? getIt<NotificationService>()
        : null;
    final notifConfig = notifService?.currentConfig ??
        cfg?.notifications ??
        const IcueNotifications.disabled();

    final notifMode = switch (notifConfig) {
      IcueNotificationsDisabled() => 'disabled',
      IcueNotificationsHostManaged() => 'hostManaged',
      IcueNotificationsFirebaseManaged() => 'firebaseManaged',
    };

    final hasDefaultFirebase = _hasDefaultFirebaseApp();
    if (notifConfig is IcueNotificationsFirebaseManaged &&
        !hasDefaultFirebase &&
        notifConfig.firebaseOptions == null) {
      issues.add(
        'Notifications configured as firebaseManaged, but no default Firebase app exists and no IcueFirebaseOptions were supplied.',
      );
    }

    var permStatus = IcuePermissionStatus.notDetermined;
    if (notifService != null) {
      permStatus = await notifService.getPermissionStatus();
    }

    final token = session?.fcmToken;
    final tokenRegistered = token != null && token.isNotEmpty;

    if (notifConfig.isEnabled && !tokenRegistered) {
      issues.add(
        'Push notifications are enabled, but no device push token has been registered with the SDK.',
      );
    }

    final navBound = _externalNavigatorKey?.currentState != null ||
        navigatorKey.currentState != null;
    if (!navBound) {
      issues.add(
        'Navigator key is not bound to a mounted widget. Set MaterialApp(navigatorKey: IcueSdk.navigatorKey).',
      );
    }

    return IcueSetupReport(
      isInitialized: isInit,
      apiKeyConfigured: hasApiKey,
      apiUserConfigured: hasApiUser,
      activeIdentificationNo: activeId,
      sessionAuthenticated: isAuthenticated,
      notificationMode: notifMode,
      firebaseAppAvailable: hasDefaultFirebase,
      notificationPermission: permStatus,
      pushTokenRegistered: tokenRegistered,
      navigatorKeyBound: navBound,
      issues: issues,
    );
  }

  /// Resets SDK state, container, and notification services (primarily for unit testing).
  @visibleForTesting
  static Future<void> resetForTesting() async {
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      try {
        await _initCompleter!.future;
      } catch (_) {}
    }
    _initCompleter = null;
    _activeConfig = null;
    _cfg = null;
    _externalNavigatorKey = null;
    if (getIt.isRegistered<NotificationService>()) {
      await getIt<NotificationService>().dispose();
    }
    if (getIt.isRegistered<SessionService>()) {
      await getIt<SessionService>().clearAllPersistence();
    }
    await getIt.reset();
  }

  /// Manually registers the push notification device token.
  /// Safe to call before or after [init].
  static Future<void> setPushToken(String token) async {
    await notifications.setToken(token);
  }

  /// Manually sets the active student identification number for the SDK session.
  static Future<void> setIdentificationNo(String identificationNo) async {
    if (!getIt.isRegistered<SessionService>()) {
      await configureDependencies();
    }
    await getIt<SessionService>().setIdentificationNo(identificationNo);

    if (getIt.isRegistered<NotificationService>()) {
      await getIt<NotificationService>().syncTokenWithBackend();
    }
  }

  /// Opens the Live Tracking experience for the given [identificationNo].
  ///
  /// Returns a typed [IcueLaunchResult] representing the outcome.
  static Future<IcueLaunchResult> openLiveTracking(
    BuildContext context, {
    required String identificationNo,
    IcueSdkConfig? config,
  }) async {
    if (config != null) {
      await init(config);
    }

    if (_cfg == null) {
      log('iCue SDK: Cannot open live tracking: SDK is not initialized.');
      return const IcueLaunchResult.failure(
        error: IcueNotInitializedException(),
      );
    }

    if (identificationNo.trim().isEmpty) {
      log('iCue SDK: Cannot open live tracking: Student identification number is empty.');
      return const IcueLaunchResult.failure(
        error: IcueInvalidStudentException(),
      );
    }

    await getIt<SessionService>().setIdentificationNo(identificationNo);

    if (!context.mounted) {
      return const IcueLaunchResult.failure(
        error: IcueNavigationException('BuildContext is unmounted.'),
      );
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LiveTrackingModule()));

    return const IcueLaunchResult.success();
  }

  /// Opens Live Tracking from the root navigator without requiring a [BuildContext].
  ///
  /// If the root navigator is not yet mounted (e.g. cold start), buffers the
  /// navigation intent and returns [IcueLaunchBuffered].
  static Future<IcueLaunchResult> openLiveTrackingFromRoot({
    required String identificationNo,
    IcueSdkConfig? config,
  }) async {
    if (config != null) {
      await init(config);
    }

    if (_cfg == null) {
      log(
        'iCue SDK: Cannot open live tracking yet: SDK is not initialized. Buffering navigation for identificationNo: $identificationNo.',
      );
      if (!getIt.isRegistered<SessionService>()) {
        await configureDependencies();
      }
      getIt<SessionService>().setPendingIdentificationNo(identificationNo);
      return IcueLaunchResult.buffered(identificationNo: identificationNo);
    }

    if (identificationNo.trim().isEmpty) {
      log('iCue SDK: Cannot open live tracking: Student identification number is empty.');
      return const IcueLaunchResult.failure(
        error: IcueInvalidStudentException(),
      );
    }

    final key = _externalNavigatorKey ?? navigatorKey;
    final navigatorState = key.currentState;
    final context = key.currentContext;

    if (navigatorState == null && context == null) {
      log(
        'iCue SDK: Root navigator not ready. Buffering navigation for identificationNo: $identificationNo.',
      );
      getIt<SessionService>().setPendingIdentificationNo(identificationNo);
      return IcueLaunchResult.buffered(identificationNo: identificationNo);
    }

    await getIt<SessionService>().setIdentificationNo(identificationNo);

    final route =
        MaterialPageRoute<void>(builder: (_) => const LiveTrackingModule());
    if (navigatorState != null) {
      navigatorState.push(route);
      return const IcueLaunchResult.success();
    }

    if (context != null && context.mounted) {
      Navigator.of(context).push(route);
      return const IcueLaunchResult.success();
    }
    return const IcueLaunchResult.failure(error: IcueNavigationException());
  }

  /// Replays any pending cold-start notification navigation intent once the
  /// root navigator becomes available.
  static Future<void> processPendingNavigation() async {
    if (_cfg == null || !getIt.isRegistered<SessionService>()) return;
    final session = getIt<SessionService>();
    final pendingId = session.pendingIdentificationNo;
    if (pendingId == null || pendingId.isEmpty) return;

    final key = _externalNavigatorKey ?? navigatorKey;
    final navigatorState = key.currentState;
    final context = key.currentContext;

    if (navigatorState != null || context != null) {
      session.clearPendingIdentificationNo();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await openLiveTrackingFromRoot(identificationNo: pendingId);
      });
    }
  }

  /// Unregisters the active push token from the iCue backend.
  ///
  /// IMPORTANT: The host retains ownership of its device push token.
  /// To invalidate the underlying FCM provider token, use [IcueNotificationManager.invalidateProviderToken].
  static Future<void> deletePushToken() async {
    await notifications.unregisterToken();
  }

  /// Alias for [deletePushToken].
  static Future<void> deleteToken() => deletePushToken();

  /// Dispatches an incoming notification event to active streams and configured callbacks.
  static void notifyNotificationReceived(dynamic messageOrNotification) {
    final IcueNotification notification = switch (messageOrNotification) {
      final IcueNotification notif => notif,
      final RemoteMessage msg => IcueNotification.fromRemoteMessage(msg),
      final Map<String, dynamic> map => IcueNotification.fromMap(map),
      _ => IcueNotification.fromMap(const {}),
    };
    notifications.handleIncomingNotification(notification);
  }

  /// Dispatches a notification tap interaction to active streams and configured callbacks.
  static void notifyNotificationTapped(dynamic messageOrNotification) {
    final IcueNotification notification = switch (messageOrNotification) {
      final IcueNotification notif => notif,
      final RemoteMessage msg => IcueNotification.fromRemoteMessage(msg),
      final Map<String, dynamic> map => IcueNotification.fromMap(map),
      _ => IcueNotification.fromMap(const {}),
    };
    notifications.handleNotificationTap(notification);
  }

  /// Clears the active SDK session, unregisters notification associations on the
  /// iCue backend, and resets active configuration.
  ///
  /// Note: The device's provider FCM token is NOT deleted from Firebase.
  static Future<void> logout() async {
    _initCompleter = null;
    if (!getIt.isRegistered<SessionService>()) {
      _activeConfig = null;
      _cfg = null;
      return;
    }

    final session = getIt<SessionService>();
    try {
      await notifications.unregisterToken();
    } finally {
      await session.clearSession();
      _activeConfig = null;
      _cfg = null;
      _initCompleter = null;
    }
  }

  /// Determines whether a notification payload belongs to the iCue SDK.
  static bool isIcuePayload(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;

    final provider = data['provider']?.toString();
    final type = data['type']?.toString();
    if (provider == 'icue' &&
        (type == 'bus_tracking' || type == 'icue_notification')) {
      return true;
    }

    // Direct or nested payload support with tracking identifiers
    if (icueAdmissionKeys.any(data.containsKey) ||
        data.containsKey('RouteTrackId')) {
      return true;
    }

    final nestedData = data['data'];
    if (nestedData is Map<String, dynamic>) {
      return isIcuePayload(nestedData);
    }

    return false;
  }

  /// Determines whether an incoming message belongs to the iCue SDK.
  static bool isIcueNotification(dynamic message) {
    if (message is RemoteMessage) {
      return isIcuePayload(message.data);
    }
    if (message is IcueNotification) {
      return isIcuePayload(message.data);
    }
    if (message is Map<String, dynamic>) {
      return isIcuePayload(message);
    }
    return false;
  }

  /// Extracts a student identification number from flat or nested payloads.
  static String? admissionNoFromPayload(Map<String, dynamic> data) {
    final nestedData = data['data'];
    return icueAdmissionNoFrom(data) ??
        icueAdmissionNoFrom(nestedData is Map ? nestedData : null);
  }

  /// Handles an iCue background message forwarded from the host application's
  /// custom [FirebaseMessaging.onBackgroundMessage] handler.
  ///
  /// Note: Background isolates cannot display Flutter overlay banners.
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (!isIcueNotification(message)) return;

    log(
      'iCue SDK: Received forwarded background message: ${message.messageId} ${message.data}',
    );

    if (!getIt.isRegistered<SessionService>()) {
      await configureDependencies();
    }
  }

  /// Handles a notification tap event by routing to live tracking or dispatching
  /// an [IcueNavigationIntent].
  static Future<void> handleNotificationTap(
    dynamic dataOrNotification, {
    BuildContext? context,
  }) async {
    final IcueNotification notification = switch (dataOrNotification) {
      final IcueNotification notif => notif,
      final RemoteMessage msg => IcueNotification.fromRemoteMessage(msg),
      final Map<String, dynamic> map => IcueNotification.fromMap(map),
      _ => IcueNotification.fromMap(const {}),
    };

    if (!isIcuePayload(notification.data) &&
        (notification.admissionNo == null ||
            notification.admissionNo!.isEmpty)) {
      log('iCue SDK: Notification tap ignored: Not an iCue payload.');
      return;
    }

    await notifications.handleNotificationTap(notification, context: context);
  }

  /// Helper to verify value equality of SDK configurations.
  static bool _configEquals(IcueSdkConfig a, IcueSdkConfig b) {
    return a.apiKey == b.apiKey &&
        a.apiUser == b.apiUser &&
        a.identificationNo == b.identificationNo &&
        a.env == b.env &&
        a.restoreSession == b.restoreSession &&
        a.notifications == b.notifications;
  }

  static bool _hasDefaultFirebaseApp() {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }
}
