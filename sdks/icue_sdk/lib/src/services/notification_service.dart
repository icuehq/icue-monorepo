import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:icue_sdk/icue_sdk.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/providers/user_provider.dart';
import 'package:icue_sdk/src/providers/vehicle_provider.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:icue_sdk/src/widgets/in_app_notification_banner.dart';
import 'package:injectable/injectable.dart';

// --- Constants ---
class _Constants {
  static const int maxProcessedMessages = 256;
}

bool _backgroundHandlerRegistered = false;

@pragma('vm:entry-point')
Future<void> icueFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  log('iCue FCM background message: ${message.messageId} ${message.data}');
}

@singleton
@injectable
class NotificationService {
  NotificationService({
    required UserProvider userProvider,
    VehicleProvider? vehicleProvider,
    required SessionService sessionService,
  })  : _userProvider = userProvider,
        _sessionService = sessionService;

  static final Set<String> _handledInitialMessageIds = <String>{};

  final SessionService _sessionService;
  final UserProvider _userProvider;

  IcueNotifications _config = const IcueNotifications.disabled();
  bool _isConfigured = false;
  String? _lastSyncedToken;
  int? _lastSyncedStudentId;
  final Map<String, Future<bool>> _inFlightSync = {};

  // Stream Subscriptions
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  // Event Controllers
  final StreamController<IcueNotification> _notificationReceivedController =
      StreamController<IcueNotification>.broadcast();
  final StreamController<IcueNavigationIntent> _navigationIntentController =
      StreamController<IcueNavigationIntent>.broadcast();
  final StreamController<IcueNotification> _notificationTappedController =
      StreamController<IcueNotification>.broadcast();

  // Deduplication Queues
  final Queue<String> _processedMessageIds =
      ListQueue(_Constants.maxProcessedMessages);
  final Queue<String> _processedInteractionIds =
      ListQueue(_Constants.maxProcessedMessages);

  // Streams
  Stream<IcueNotification> get onNotificationReceived =>
      _notificationReceivedController.stream;

  Stream<IcueNavigationIntent> get onNavigationIntent =>
      _navigationIntentController.stream;

  Stream<IcueNotification> get onNotificationTapped =>
      _notificationTappedController.stream;

  IcueNotifications get currentConfig => _config;

  bool get isConfigured => _isConfigured;

  /// Configures notification behavior based on the supplied [IcueNotifications] contract.
  Future<void> configure(IcueNotifications notifications) async {
    _config = notifications;
    _isConfigured = true;

    // Reset existing FCM subscriptions
    await _cancelSubscriptions();

    switch (notifications) {
      case IcueNotificationsDisabled():
        log('iCue Notifications: Mode set to DISABLED. Zero listeners attached.');
        IcueNotificationOverlay.dismiss();
        break;

      case IcueNotificationsHostManaged(
          token: final hostToken,
          presentation: _,
          inAppNotificationDuration: _,
          onNotificationReceived: _,
          onNavigationIntent: _,
          onNotificationTapped: _,
          autoNavigateOnTap: _,
        ):
        log('iCue Notifications: Mode set to HOST_MANAGED.');
        if (hostToken != null && hostToken.isNotEmpty) {
          await _sessionService.setFcmToken(hostToken);
          // Sync asynchronously in background without blocking
          unawaited(syncTokenWithBackend());
        }
        break;

      case IcueNotificationsFirebaseManaged(
          firebaseOptions: final customOptions,
          autoRegisterFcmBackgroundHandler: final autoRegisterBg,
          autoRequestPermission: final autoRequestPerm,
          presentation: final presentationStyle,
          inAppNotificationDuration: _,
          onNotificationReceived: _,
          onNavigationIntent: _,
          onNotificationTapped: _,
          autoNavigateOnTap: _,
        ):
        log('iCue Notifications: Mode set to FIREBASE_MANAGED.');
        await _initializeFirebaseApp(customOptions);

        if (!_hasDefaultFirebaseApp()) {
          log('iCue Notifications: No default Firebase app found. FCM management deferred.');
          return;
        }

        // Register background handler if requested
        if (autoRegisterBg) {
          _registerBackgroundHandler();
        }

        // Request permissions if explicitly configured
        if (autoRequestPerm) {
          unawaited(requestPermission());
        }

        // Apply iOS foreground presentation options
        await _applyPresentationOptions(presentationStyle);

        // Setup message listeners and fetch token asynchronously
        _setupMessageHandlers();
        unawaited(_initializeToken());
        break;
    }
  }

  /// Checks the current push notification authorization status.
  Future<IcuePermissionStatus> getPermissionStatus() async {
    if (!_hasDefaultFirebaseApp()) {
      return IcuePermissionStatus.notDetermined;
    }
    try {
      final settings = await _messaging.getNotificationSettings();
      return _mapAuthorizationStatus(settings.authorizationStatus);
    } catch (e) {
      log('iCue FCM: Error reading notification settings: $e');
      return IcuePermissionStatus.notDetermined;
    }
  }

  /// Requests notification permissions from the host operating system.
  Future<IcuePermissionStatus> requestPermission() async {
    if (!_hasDefaultFirebaseApp()) {
      log('iCue FCM: Cannot request permission: Firebase app is not initialized.');
      return IcuePermissionStatus.notDetermined;
    }
    try {
      final settings = await _messaging.requestPermission();
      return _mapAuthorizationStatus(settings.authorizationStatus);
    } catch (e, st) {
      log(
        'iCue FCM: Failed to request notification permission',
        error: e,
        stackTrace: st,
      );
      return IcuePermissionStatus.notDetermined;
    }
  }

  /// Checks whether notification permission is authorized or provisional.
  Future<bool> isPermissionGranted() async {
    final status = await getPermissionStatus();
    return status == IcuePermissionStatus.authorized ||
        status == IcuePermissionStatus.provisional;
  }

  /// Alias for [isPermissionGranted].
  Future<bool> isNotificationPermissionEnabled() => isPermissionGranted();

  /// Manually supplies a push notification device token to the SDK.
  Future<void> setToken(String token) async {
    await _sessionService.setFcmToken(token);
    await syncTokenWithBackend();
  }

  /// Synchronizes the active device token with the iCue backend for the given [studentId]
  /// or the currently active student.
  ///
  /// Returns `true` if the backend confirmed token registration, `false` otherwise.
  Future<bool> syncTokenWithBackend({
    String? studentId,
    bool force = false,
  }) async {
    if (!_config.isEnabled) {
      log('iCue Notifications: syncTokenWithBackend skipped because notifications are disabled.');
      return false;
    }

    final targetId = studentId ?? _sessionService.identificationNo;
    if (targetId == null || targetId.isEmpty) {
      log('iCue Notifications: Token cached locally. Backend sync deferred until student ID is set.');
      return false;
    }

    if (!force && _inFlightSync.containsKey(targetId)) {
      return _inFlightSync[targetId]!;
    }

    final future = _executeTokenSync(targetId, force: force);
    _inFlightSync[targetId] = future;
    try {
      return await future;
    } finally {
      unawaited(_inFlightSync.remove(targetId));
    }
  }

  Future<bool> _executeTokenSync(String targetId, {required bool force}) async {
    try {
      var token = _sessionService.fcmToken;
      if ((token == null || token.isEmpty) && _hasDefaultFirebaseApp()) {
        // ignore: deprecated_member_use, register() exists only in firebase_messaging 17; the SDK supports >=14.7.
        token = await _messaging.getToken();
      }
      if (token == null || token.isEmpty) {
        log('iCue Notifications: No device push token available to sync.');
        return false;
      }

      await _sessionService.setFcmToken(token);

      User? student;
      if (_sessionService.identificationNo == targetId &&
          _userProvider.user != null) {
        student = _userProvider.user;
      } else {
        student = _sessionService.getUserForStudent(targetId) ??
            await _sessionService.loadUserForStudent(targetId) ??
            await _userProvider.authenticateStudent(targetId);
      }

      if (student == null) {
        log('iCue Notifications: Student auth failed for $targetId. Token registration deferred.');
        return false;
      }

      final numericStudentId = student.id;
      if (!force &&
          _lastSyncedToken == token &&
          _lastSyncedStudentId == numericStudentId) {
        log('iCue Notifications: Token already synced for student $numericStudentId, skipping duplicate request.');
        return true;
      }

      final success = await _userProvider.updateRegTokens(
        token,
        studentId: numericStudentId,
        bearerToken: student.token,
      );

      if (success) {
        await _sessionService.addRegisteredStudent(targetId);
        _lastSyncedToken = token;
        _lastSyncedStudentId = numericStudentId;
        log('iCue Notifications: Token successfully synced with backend for student $numericStudentId ($targetId)');
        return true;
      } else {
        log('iCue Notifications: Backend rejected token registration for student $numericStudentId ($targetId)');
        return false;
      }
    } catch (e, st) {
      log(
        'iCue Notifications: Failed to sync token with backend',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Registers a specific student ID for push notifications.
  ///
  /// Returns `true` if backend registration succeeds, `false` otherwise.
  Future<bool> registerStudent(String studentId, {String? token}) async {
    if (token != null && token.isNotEmpty) {
      await _sessionService.setFcmToken(token);
    }
    return syncTokenWithBackend(studentId: studentId, force: true);
  }

  /// Unregisters push notification associations from the iCue backend for a student.
  ///
  /// IMPORTANT: This notifies the iCue backend to detach the student/token association.
  /// It DOES NOT delete the FCM token from the device or Firebase servers.
  Future<bool> unregisterStudent(String studentId, {String? token}) async {
    try {
      final activeToken = token ?? _sessionService.fcmToken;
      final success = await _userProvider.logout(
        token: activeToken,
        studentId: studentId,
      );
      if (success) {
        await _sessionService.removeRegisteredStudent(studentId);
        final studentObj = _sessionService.getUserForStudent(studentId) ??
            await _sessionService.loadUserForStudent(studentId) ??
            (_sessionService.identificationNo == studentId
                ? _sessionService.user
                : null);
        final numericId = studentObj?.id ?? int.tryParse(studentId);
        if (_lastSyncedStudentId == numericId) {
          _lastSyncedToken = null;
          _lastSyncedStudentId = null;
        }
        log('iCue Notifications: Student $studentId unregistered from notifications.');
        return true;
      } else {
        log('iCue Notifications: Backend unregistration failed for student $studentId.');
        return false;
      }
    } catch (e, st) {
      log(
        'iCue Notifications: Failed to unregister student $studentId',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Unregisters all registered students from iCue push notifications and clears
  /// local push token storage without invalidating the provider FCM token.
  Future<bool> unregisterAllStudents({String? token}) async {
    try {
      final registered = await _sessionService.getRegisteredStudents();
      final activeToken = token ?? _sessionService.fcmToken;

      var allSuccess = true;
      for (final studentId in registered) {
        final success = await _userProvider.logout(
          token: activeToken,
          studentId: studentId,
        );
        if (success) {
          await _sessionService.removeRegisteredStudent(studentId);
        } else {
          allSuccess = false;
        }
      }

      await _sessionService.clearRegisteredStudents();
      await _sessionService.clearFcmToken();
      _lastSyncedToken = null;
      _lastSyncedStudentId = null;
      log('iCue Notifications: All students unregistered from iCue backend.');
      return allSuccess;
    } catch (e, st) {
      log(
        'iCue Notifications: Error during unregisterAllStudents',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Unregisters the active token from iCue backend. Alias for clean unregistration.
  Future<bool> unregisterToken() async {
    final activeId = _sessionService.identificationNo;
    if (activeId != null && activeId.isNotEmpty) {
      return unregisterStudent(activeId);
    } else {
      return unregisterAllStudents();
    }
  }

  /// Explicitly invalidates the Firebase Cloud Messaging device token from Firebase servers.
  ///
  /// Only call this if your host application deliberately intends to destroy the device's
  /// FCM token for the entire app.
  Future<void> invalidateProviderToken() async {
    try {
      if (_hasDefaultFirebaseApp()) {
        // ignore: deprecated_member_use, register() exists only in firebase_messaging 17; the SDK supports >=14.7.
        await _messaging.deleteToken();
        log('iCue FCM: Provider token explicitly invalidated.');
      }
    } catch (e, st) {
      log(
        'iCue FCM: Failed to invalidate provider token',
        error: e,
        stackTrace: st,
      );
    } finally {
      _lastSyncedToken = null;
      _lastSyncedStudentId = null;
      await _sessionService.clearFcmToken();
    }
  }

  /// Displays an in-app banner overlay if the configured presentation style is [IcueNotificationPresentation.sdkBanner].
  Future<void> showNotification(IcueNotification notification) async {
    if (_config.presentation != IcueNotificationPresentation.sdkBanner) {
      return;
    }

    try {
      final title = notification.title ?? 'iCue Notification';
      final body = notification.body ?? '';
      final duration = _config.inAppNotificationDuration;

      final overlay = IcueSdk.overlayState;
      if (overlay != null) {
        IcueNotificationOverlay.show(
          overlayState: overlay,
          title: title,
          body: body,
          duration: duration,
          onTap: () {
            handleInteraction(notification, source: 'inAppBanner');
          },
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final retryOverlay = IcueSdk.overlayState;
          if (retryOverlay != null) {
            IcueNotificationOverlay.show(
              overlayState: retryOverlay,
              title: title,
              body: body,
              duration: duration,
              onTap: () {
                handleInteraction(notification, source: 'inAppBanner');
              },
            );
          }
        });
      }
    } catch (e, st) {
      log(
        'iCue Notifications: Failed to display in-app banner',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Handles user interaction with a notification (tap from banner, system tray, or host router).
  Future<void> handleInteraction(
    IcueNotification notification, {
    required String source,
    BuildContext? context,
  }) async {
    final messageId = notification.messageId ??
        notification.sentTime?.millisecondsSinceEpoch.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    if (_processedInteractionIds.contains(messageId)) {
      log('iCue Notifications: Duplicate interaction ignored: $messageId');
      return;
    }

    if (_processedInteractionIds.length >= _Constants.maxProcessedMessages) {
      _processedInteractionIds.removeFirst();
    }
    _processedInteractionIds.addLast(messageId);

    log('iCue Notifications: Interaction handled from source: $source for admissionNo: ${notification.admissionNo}');

    // 1. Dispatch notification tapped event
    IcueNotificationManager.dispatchNotificationTapped(notification);
    if (_notificationTappedController.hasListener) {
      _notificationTappedController.add(notification);
    }
    _config.onNotificationTapped?.call(notification);

    // 2. Dispatch typed navigation intent
    final admissionNo = notification.admissionNo;
    if (admissionNo != null && admissionNo.isNotEmpty) {
      final intent = IcueNavigationIntent(
        identificationNo: admissionNo,
        notification: notification,
        action: notification.action,
        extras: notification.data,
      );

      IcueNotificationManager.dispatchNavigationIntent(intent);
      if (_navigationIntentController.hasListener) {
        _navigationIntentController.add(intent);
      }
      _config.onNavigationIntent?.call(intent);

      // 3. Auto-navigate if enabled
      if (_config.autoNavigateOnTap) {
        if (context != null && context.mounted) {
          await IcueSdk.openLiveTracking(
            context,
            identificationNo: admissionNo,
          );
        } else {
          await IcueSdk.openLiveTrackingFromRoot(identificationNo: admissionNo);
        }
      }
    }
  }

  /// Receives an incoming notification from any source (foreground listener or host manual forwarding).
  Future<void> handleIncomingNotification(IcueNotification notification) async {
    final messageId = notification.messageId ??
        notification.sentTime?.millisecondsSinceEpoch.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    if (_processedMessageIds.contains(messageId)) {
      log('iCue Notifications: Duplicate incoming message ignored: $messageId');
      return;
    }

    if (_processedMessageIds.length >= _Constants.maxProcessedMessages) {
      _processedMessageIds.removeFirst();
    }
    _processedMessageIds.addLast(messageId);

    // Dispatch to static manager and instance controller
    IcueNotificationManager.dispatchNotificationReceived(notification);
    if (_notificationReceivedController.hasListener) {
      _notificationReceivedController.add(notification);
    }
    _config.onNotificationReceived?.call(notification);

    // Display banner if presentation policy allows
    await showNotification(notification);
  }

  /// Cleans up subscriptions and resources.
  Future<void> dispose() async {
    await _cancelSubscriptions();
    IcueNotificationOverlay.dismiss();
    _lastSyncedToken = null;
    _lastSyncedStudentId = null;
    _isConfigured = false;
  }

  // --- Private Helpers ---

  Future<void> _cancelSubscriptions() async {
    await _onMessageSub?.cancel();
    _onMessageSub = null;
    await _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub = null;
    await _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub = null;
  }

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool _hasDefaultFirebaseApp() {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeFirebaseApp(IcueFirebaseOptions? options) async {
    if (_hasDefaultFirebaseApp()) return;
    if (options == null) return;

    final platformOptions = Platform.isAndroid
        ? options.android
        : Platform.isIOS
            ? options.ios
            : null;

    if (platformOptions != null) {
      await Firebase.initializeApp(options: platformOptions);
    }
  }

  Future<void> _applyPresentationOptions(
    IcueNotificationPresentation presentation,
  ) async {
    if (!Platform.isIOS || !_hasDefaultFirebaseApp()) return;

    try {
      if (presentation == IcueNotificationPresentation.sdkBanner) {
        // Prevent double banner on iOS by suppressing OS foreground alert
        await _messaging.setForegroundNotificationPresentationOptions(
          badge: true,
        );
      } else if (presentation == IcueNotificationPresentation.system) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      log('iCue FCM: Error applying presentation options: $e');
    }
  }

  void _setupMessageHandlers() {
    if (!_hasDefaultFirebaseApp()) return;

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      if (!IcueSdk.isIcuePayload(message.data)) return;
      final notification = IcueNotification.fromRemoteMessage(message);
      handleIncomingNotification(notification);
    });

    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (!IcueSdk.isIcuePayload(message.data)) return;
      final notification = IcueNotification.fromRemoteMessage(message);
      handleInteraction(notification, source: 'onMessageOpenedApp');
    });

    _messaging.getInitialMessage().then((message) {
      if (message != null && IcueSdk.isIcuePayload(message.data)) {
        final id = message.messageId ??
            message.sentTime?.millisecondsSinceEpoch.toString() ??
            message.data.toString();
        if (_handledInitialMessageIds.contains(id)) return;
        _handledInitialMessageIds.add(id);

        final notification = IcueNotification.fromRemoteMessage(message);
        handleInteraction(notification, source: 'initialMessage');
      }
    });
  }

  Future<void> _initializeToken() async {
    if (!_hasDefaultFirebaseApp()) return;

    try {
      // Fetch latest token from FCM
      // ignore: deprecated_member_use, register() exists only in firebase_messaging 17; the SDK supports >=14.7.
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _sessionService.setFcmToken(token);
        await syncTokenWithBackend();
      }

      await _onTokenRefreshSub?.cancel();
      // ignore: deprecated_member_use, register() exists only in firebase_messaging 17; the SDK supports >=14.7.
      _onTokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        await _sessionService.setFcmToken(newToken);
        await syncTokenWithBackend();
      });
    } catch (e, st) {
      log(
        'iCue FCM: Error during token initialization',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _registerBackgroundHandler() {
    if (_backgroundHandlerRegistered || !_hasDefaultFirebaseApp()) return;
    try {
      FirebaseMessaging.onBackgroundMessage(
        icueFirebaseMessagingBackgroundHandler,
      );
      _backgroundHandlerRegistered = true;
    } catch (e) {
      log('iCue FCM: Background handler registration notice: $e');
    }
  }

  IcuePermissionStatus _mapAuthorizationStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return IcuePermissionStatus.authorized;
      case AuthorizationStatus.provisional:
        return IcuePermissionStatus.provisional;
      case AuthorizationStatus.denied:
        return IcuePermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return IcuePermissionStatus.notDetermined;
      default:
        return IcuePermissionStatus.denied;
    }
  }
}
