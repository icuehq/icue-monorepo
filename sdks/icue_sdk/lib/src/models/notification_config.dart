import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:icue_sdk/src/models/icue_notification.dart';
import 'package:icue_sdk/src/models/navigation_intent.dart';

/// Pure-Dart credentials for platform Firebase initialization.
///
/// Enables host apps to configure Firebase push credentials without
/// importing `package:firebase_core/firebase_core.dart`.
@immutable
class IcuePlatformCredentials {
  const IcuePlatformCredentials({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.iosBundleId,
  });

  final String apiKey;
  final String appId;
  final String? iosBundleId;
  final String messagingSenderId;
  final String projectId;

  FirebaseOptions toFirebaseOptions() => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        iosBundleId: iosBundleId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcuePlatformCredentials &&
          runtimeType == other.runtimeType &&
          apiKey == other.apiKey &&
          appId == other.appId &&
          iosBundleId == other.iosBundleId &&
          messagingSenderId == other.messagingSenderId &&
          projectId == other.projectId;

  @override
  int get hashCode => Object.hash(
        apiKey,
        appId,
        iosBundleId,
        messagingSenderId,
        projectId,
      );
}

/// Platform-specific Firebase options passed to the SDK so it can initialize
/// Firebase Cloud Messaging when the host application has not already
/// initialized Firebase.
@immutable
class IcueFirebaseOptions {
  const IcueFirebaseOptions({this.android, this.ios});

  /// Factory constructor accepting pure-Dart [IcuePlatformCredentials].
  factory IcueFirebaseOptions.fromCredentials({
    IcuePlatformCredentials? android,
    IcuePlatformCredentials? ios,
  }) {
    return IcueFirebaseOptions(
      android: android?.toFirebaseOptions(),
      ios: ios?.toFirebaseOptions(),
    );
  }

  /// Firebase options for Android.
  final FirebaseOptions? android;

  /// Firebase options for iOS.
  final FirebaseOptions? ios;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueFirebaseOptions &&
          runtimeType == other.runtimeType &&
          android?.apiKey == other.android?.apiKey &&
          android?.appId == other.android?.appId &&
          ios?.apiKey == other.ios?.apiKey &&
          ios?.appId == other.ios?.appId;

  @override
  int get hashCode => Object.hash(android?.apiKey, ios?.apiKey);
}

/// Defines how incoming notifications should be presented when the app is in the foreground.
enum IcueNotificationPresentation {
  /// SDK renders an animated top banner overlay in the foreground.
  /// (System foreground alert/sound is disabled to prevent duplicate banners on iOS).
  sdkBanner,

  /// System tray / OS displays the notification (e.g. iOS alert/sound).
  /// SDK does not render an in-app banner overlay.
  system,

  /// Host application controls all foreground notification display.
  /// SDK renders no banners and applies no system foreground options.
  hostManaged,

  /// Suppresses all foreground visual/audible notifications.
  none,
}

/// Authorization status for push notifications.
enum IcuePermissionStatus {
  /// Notifications are authorized with full alerts, sounds, and badges.
  authorized,

  /// Notifications are provisionally authorized (quiet delivery).
  provisional,

  /// User explicitly denied notification permissions.
  denied,

  /// Permission status has not yet been requested from the user.
  notDetermined,

  /// Push notifications are unsupported on the current platform/device.
  unsupported,
}

/// Sealed configuration contract defining how the iCue SDK manages notifications.
@immutable
sealed class IcueNotifications {
  const IcueNotifications();

  /// Completely disables push notifications in the SDK.
  ///
  /// The SDK will NOT attach Firebase listeners, request permissions, fetch tokens,
  /// or attempt background notification synchronization. This is the default.
  const factory IcueNotifications.disabled() = IcueNotificationsDisabled;

  /// Host-managed push notifications mode.
  ///
  /// The host application owns its push provider (FCM, OneSignal, etc.) and
  /// supplies device tokens to the SDK directly.
  const factory IcueNotifications.hostManaged({
    String? token,
    IcueNotificationPresentation presentation,
    Duration? inAppNotificationDuration,
    void Function(IcueNotification notification)? onNotificationReceived,
    void Function(IcueNavigationIntent intent)? onNavigationIntent,
    void Function(IcueNotification notification)? onNotificationTapped,
    bool autoNavigateOnTap,
  }) = IcueNotificationsHostManaged;

  /// SDK Firebase-managed push notifications mode.
  ///
  /// The SDK manages FCM listeners, background message callbacks, token refresh,
  /// and backend synchronization.
  const factory IcueNotifications.firebaseManaged({
    IcueFirebaseOptions? firebaseOptions,
    bool autoRegisterFcmBackgroundHandler,
    bool autoRequestPermission,
    IcueNotificationPresentation presentation,
    Duration? inAppNotificationDuration,
    void Function(IcueNotification notification)? onNotificationReceived,
    void Function(IcueNavigationIntent intent)? onNavigationIntent,
    void Function(IcueNotification notification)? onNotificationTapped,
    bool autoNavigateOnTap,
  }) = IcueNotificationsFirebaseManaged;

  /// Whether push notifications are enabled.
  bool get isEnabled;

  /// The presentation style for foreground notifications.
  IcueNotificationPresentation get presentation;

  /// Duration before an in-app banner overlay auto-dismisses.
  Duration? get inAppNotificationDuration;

  /// Optional callback for incoming foreground notifications.
  void Function(IcueNotification notification)? get onNotificationReceived;

  /// Optional callback for navigation intents (e.g. on notification tap).
  void Function(IcueNavigationIntent intent)? get onNavigationIntent;

  /// Optional callback for notification tap interactions.
  void Function(IcueNotification notification)? get onNotificationTapped;

  /// Whether tapping a notification automatically navigates to live tracking.
  /// Defaults to `true`.
  bool get autoNavigateOnTap;
}

/// Push notifications disabled configuration.
@immutable
class IcueNotificationsDisabled extends IcueNotifications {
  const IcueNotificationsDisabled();

  @override
  bool get isEnabled => false;

  @override
  IcueNotificationPresentation get presentation =>
      IcueNotificationPresentation.none;

  @override
  Duration? get inAppNotificationDuration => null;

  @override
  void Function(IcueNotification notification)? get onNotificationReceived =>
      null;

  @override
  void Function(IcueNavigationIntent intent)? get onNavigationIntent => null;

  @override
  void Function(IcueNotification notification)? get onNotificationTapped =>
      null;

  @override
  bool get autoNavigateOnTap => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IcueNotificationsDisabled;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Host-managed push notifications configuration.
@immutable
class IcueNotificationsHostManaged extends IcueNotifications {
  const IcueNotificationsHostManaged({
    this.token,
    this.presentation = IcueNotificationPresentation.sdkBanner,
    this.inAppNotificationDuration,
    this.onNotificationReceived,
    this.onNavigationIntent,
    this.onNotificationTapped,
    this.autoNavigateOnTap = true,
  });

  /// Optional push notification token (FCM, APNs, etc.) passed by host.
  final String? token;

  @override
  final IcueNotificationPresentation presentation;

  @override
  final Duration? inAppNotificationDuration;

  @override
  final void Function(IcueNotification notification)? onNotificationReceived;

  @override
  final void Function(IcueNavigationIntent intent)? onNavigationIntent;

  @override
  final void Function(IcueNotification notification)? onNotificationTapped;

  @override
  final bool autoNavigateOnTap;

  @override
  bool get isEnabled => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueNotificationsHostManaged &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          presentation == other.presentation &&
          inAppNotificationDuration == other.inAppNotificationDuration &&
          autoNavigateOnTap == other.autoNavigateOnTap;

  @override
  int get hashCode => Object.hash(
        token,
        presentation,
        inAppNotificationDuration,
        autoNavigateOnTap,
      );
}

/// Firebase-managed push notifications configuration.
@immutable
class IcueNotificationsFirebaseManaged extends IcueNotifications {
  const IcueNotificationsFirebaseManaged({
    this.firebaseOptions,
    this.autoRegisterFcmBackgroundHandler = false,
    this.autoRequestPermission = false,
    this.presentation = IcueNotificationPresentation.sdkBanner,
    this.inAppNotificationDuration,
    this.onNotificationReceived,
    this.onNavigationIntent,
    this.onNotificationTapped,
    this.autoNavigateOnTap = true,
  });

  /// Explicit Firebase options when the host has not initialized Firebase.
  final IcueFirebaseOptions? firebaseOptions;

  /// Whether the SDK should automatically register a FirebaseMessaging background handler.
  final bool autoRegisterFcmBackgroundHandler;

  /// Whether to automatically prompt for notification permissions during init.
  /// Defaults to `false` (recommended to let host control permission timing).
  final bool autoRequestPermission;

  @override
  final IcueNotificationPresentation presentation;

  @override
  final Duration? inAppNotificationDuration;

  @override
  final void Function(IcueNotification notification)? onNotificationReceived;

  @override
  final void Function(IcueNavigationIntent intent)? onNavigationIntent;

  @override
  final void Function(IcueNotification notification)? onNotificationTapped;

  @override
  final bool autoNavigateOnTap;

  @override
  bool get isEnabled => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcueNotificationsFirebaseManaged &&
          runtimeType == other.runtimeType &&
          firebaseOptions == other.firebaseOptions &&
          autoRegisterFcmBackgroundHandler ==
              other.autoRegisterFcmBackgroundHandler &&
          autoRequestPermission == other.autoRequestPermission &&
          presentation == other.presentation &&
          inAppNotificationDuration == other.inAppNotificationDuration &&
          autoNavigateOnTap == other.autoNavigateOnTap;

  @override
  int get hashCode => Object.hash(
        firebaseOptions,
        autoRegisterFcmBackgroundHandler,
        autoRequestPermission,
        presentation,
        inAppNotificationDuration,
        autoNavigateOnTap,
      );
}
