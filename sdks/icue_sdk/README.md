# iCue SDK

[![Version](https://img.shields.io/badge/version-0.2.0--beta.3-orange.svg)](https://dart.cloudsmith.io/icue/icue-sdk/)
[![Flutter](https://img.shields.io/badge/flutter-3.24.0+-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

The **iCue SDK** is a production-ready Flutter library designed to integrate real-time school bus live tracking into your parent-facing applications. It provides a plug-and-play tracking module featuring smooth 60fps animations, intelligent polyline snapping, ETA estimations, and decoupled push notification management.

---

## 📸 Visual Preview

|          Live Tracking Experience          |         Student Location View          |
| :----------------------------------------: | :------------------------------------: |
| ![Tracking Preview](assets/tracking.webp)  | ![Map Preview](assets/student-map.png) |
| _Animated bus movement and route polyline_ |    _Student pickup/drop-off points_    |

---

## 🚀 Features

- **Smooth 60fps Animation**: High-performance bus interpolation on Google Maps using frame-independent dead reckoning.
- **Intelligent Routing**: Automatic rendering of route polylines with path-snapping and jitter filtering.
- **Real-time ETA**: Dynamic calculation of arrival times for student pickup and drop-off points.
- **Explicit Opt-in Notifications**: Zero implicit Firebase hooks. Full host-managed or SDK-managed modes with `IcueNotifications`.
- **Typed Outcomes**: Explicit `IcueLaunchResult` for tracking navigation and preflight diagnostic checks with `IcueSdk.checkSetup()`.
- **Multi-Student Support**: Explicit per-student notification registration, session isolation, and token detachment without breaking host app FCM tokens.

---

## 📦 Installation

Add the SDK to your `pubspec.yaml` using your private Cloudsmith registry.

**Stable (recommended).** A normal constraint never installs a beta:

```yaml
dependencies:
  flutter:
    sdk: flutter
  icue_sdk:
    hosted:
      name: icue_sdk
      url: https://dart.cloudsmith.io/icue/icue-sdk/
    version: ^0.2.0
```

**Beta (opt-in, may have known issues, not for production).** Pin the exact
beta version; it is never selected automatically:

```yaml
  icue_sdk:
    hosted:
      name: icue_sdk
      url: https://dart.cloudsmith.io/icue/icue-sdk/
    version: 0.2.0-beta.3
```

Beta builds log a warning when `IcueSdk.init` runs, and `IcueSdk.isBeta` /
`IcueSdk.version` report the build you are on.

Then, fetch the package:

```bash
flutter pub get
```

---

## 🛠 Platform Setup

### 1. Android Configuration

#### Update Permissions

Add network permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

> [!NOTE]
> The SDK displays live bus telemetry queried from the iCue cloud API and does not track the parent device's location. Device location permissions (`ACCESS_FINE_LOCATION`) are not required.

#### Add Google Maps API Key

Add inside the `<application>` tag of `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

#### Min SDK Implementation

Ensure `minSdkVersion` is **24** or higher in `android/app/build.gradle`:

```gradle
defaultConfig {
    minSdkVersion 24
}
```

### 2. iOS Configuration

#### Google Maps Setup

Initialize Google Maps in `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

#### Push Notification Setup (Optional)

When using push notifications, enable the **Push Notifications** capability and the **Background Modes -> Remote notifications** option for the Runner target in Xcode.

---

## 🚦 Integration Guide

### Step 1: Bind the Navigator Key

The SDK uses the navigator key for context-less deep linking and notification routing. Attach `IcueSdk.navigatorKey` and `IcueNavigatorObserver` to your `MaterialApp`:

```dart
MaterialApp(
  navigatorKey: IcueSdk.navigatorKey,
  navigatorObservers: [IcueNavigatorObserver()],
  // ... rest of your config
);
```

> [!TIP]
> If your app already uses a custom `GlobalKey<NavigatorState>`, register it using `IcueSdk.setNavigatorKey(myKey)` and still include `IcueNavigatorObserver`. The observer automatically buffers and replays notification intents received before the navigator is mounted (e.g. cold start).

---

### Step 2: Initialize on Demand

Initialize the iCue SDK on-demand at any point in your application lifecycle (such as upon parent login, student profile selection, or right before accessing tracking):

```dart
import 'package:icue_sdk/icue_sdk.dart';

await IcueSdk.init(
  const IcueSdkConfig(
    apiKey: 'YOUR_API_KEY',
    apiUser: 'YOUR_API_USER',
    env: IcueEnvironment.prod, // Use .dev for staging
    notifications: IcueNotifications.disabled(), // Pure tracking mode (default)
  ),
);
```

---

### Step 3: Open Live Tracking

Open the tracking module with a student identification number:

```dart
final result = await IcueSdk.openLiveTracking(
  context,
  identificationNo: '12345',
);

if (result.isFailure) {
  print('Could not open tracking: ${result.errorMessage}');
}
```

---

### Step 4: Preflight Diagnostics

Run preflight checks anytime to verify your credentials, environment, permissions, and navigator configuration:

```dart
final report = await IcueSdk.checkSetup();
print(report.toDiagnosticSummary());
```

---

### Step 5: Sign Out / Reset Session

When the user signs out, call `IcueSdk.logout()` to unregister student push associations from the iCue backend and clear cached credentials:

```dart
await IcueSdk.logout();
```

> [!IMPORTANT]
> `IcueSdk.logout()` only removes the student and device association from the iCue backend. It **never** invalidates or deletes the underlying FCM token from the device, ensuring non-iCue push notifications in the host app remain fully functional.

---

## 🔔 Push Notification Contracts

Push notifications are explicitly opt-in and controlled via `IcueNotifications`.

### Mode A: Tracking Only (No Push Notifications)

```dart
await IcueSdk.init(
  const IcueSdkConfig(
    apiKey: 'YOUR_API_KEY',
    apiUser: 'YOUR_API_USER',
    notifications: IcueNotifications.disabled(),
  ),
);
```

---

### Mode B: Host-Managed Notifications (Recommended)

When your application manages its own push provider (FCM, OneSignal, etc.):

```dart
await IcueSdk.init(
  IcueSdkConfig(
    apiKey: 'YOUR_API_KEY',
    apiUser: 'YOUR_API_USER',
    notifications: IcueNotifications.hostManaged(
      token: hostDeviceToken,
      presentation: IcueNotificationPresentation.sdkBanner,
      onNavigationIntent: (intent) {
        // Custom router integration (e.g. GoRouter)
        appRouter.go('/tracking/${intent.identificationNo}');
      },
    ),
  ),
);

// Forward incoming foreground notifications:
FirebaseMessaging.onMessage.listen((message) {
  if (IcueSdk.isIcueNotification(message)) {
    IcueSdk.notifications.handleMessage(message);
  }
});

// Forward notification tap interactions:
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  if (IcueSdk.isIcueNotification(message)) {
    IcueSdk.notifications.handleTap(message, context: context);
  }
});

// In your top-level background handler:
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (IcueSdk.isIcueNotification(message)) {
    await IcueSdk.handleBackgroundMessage(message);
  }
}
```

---

### Mode C: SDK-Managed Firebase

When you want the SDK to handle Firebase Cloud Messaging directly:

```dart
await IcueSdk.init(
  IcueSdkConfig(
    apiKey: 'YOUR_API_KEY',
    apiUser: 'YOUR_API_USER',
    notifications: IcueNotifications.firebaseManaged(
      autoRegisterFcmBackgroundHandler: false,
      autoRequestPermission: false, // Control permission timing manually
      presentation: IcueNotificationPresentation.sdkBanner,
      firebaseOptions: IcueFirebaseOptions.fromCredentials(
        android: const IcuePlatformCredentials(
          apiKey: 'AIza...',
          appId: '1:123456789:android:...',
          messagingSenderId: '123456789',
          projectId: 'your-firebase-project',
        ),
        ios: const IcuePlatformCredentials(
          apiKey: 'AIza...',
          appId: '1:123456789:ios:...',
          messagingSenderId: '123456789',
          projectId: 'your-firebase-project',
          iosBundleId: 'com.example.yourapp',
        ),
      ),
    ),
  ),
);

// Request permissions on your own screen/timing:
final status = await IcueSdk.notifications.requestPermission();
```

---

### Push Notification Lifecycle & Sign-Out (Logout)

When a parent signs out of your application, call `IcueSdk.logout()` to unregister the device's push notification associations on the iCue backend and prevent subsequent alerts for that student:

```dart
// Option 1: Full SDK Sign-Out (Recommended on host app logout)
// Clears session cache and unregisters push tokens on iCue backend without deleting device FCM token
await IcueSdk.logout();

// Option 2: Push Token Unregistration Only
// Detaches device token from iCue backend while keeping local session active
await IcueSdk.notifications.unregisterToken();
```

> [!NOTE]
> **Token Ownership & Safety**: Calling `IcueSdk.logout()` or `IcueSdk.notifications.unregisterToken()` only removes the device push association from the iCue backend (`/v1.0/logout`). It **never** destroys or invalidates the underlying FCM/APNs token on the device, ensuring all non-iCue push notifications in the host application remain fully functional.

---

## 👨‍👩‍👧 Multi-Student Notification Management (Optional)

For family applications managing multiple enrolled children simultaneously:

```dart
// Register multiple students for background push notifications
await IcueSdk.notifications.registerStudents(['STUDENT_1', 'STUDENT_2'], token: deviceToken);

// Inspect currently registered students
final registeredIds = await IcueSdk.notifications.getRegisteredStudents();

// Unregister a specific student on switch/signout
await IcueSdk.notifications.unregisterStudent('STUDENT_1');

// Unregister all students on parent logout
await IcueSdk.notifications.unregisterAllStudents();

// Or perform a full SDK logout to unregister all push associations and clear session state
await IcueSdk.logout();
```


---

## 📦 Notification Response Structure

Incoming push notifications from iCue deliver the following response map (accessed via `RemoteMessage.data` or SDK notification streams):

```json
{
  "icon": "ic_launcher",
  "action": "Track",
  "Sound": "default",
  "body": "Dear Parent, R - 02 Pickup has been started.",
  "title": "Naveen Aluri - Route has been started",
  "click_action": "0",
  "StudentName": "Naveen Aluri",
  "AdmissionNo": "7978",
  "StudentId": "108233"
}
```

### Notification Response Fields Reference

| Field | Type | Description |
| :--- | :--- | :--- |
| `AdmissionNo` | `String` / `Number` | **(Required)** Unique student admission number (e.g. `"7978"`). Used by the SDK to authenticate and load live tracking. |
| `StudentId` | `String` / `Number` | Unique student numeric ID (e.g. `"108233"`). |
| `StudentName` | `String` | Student full name (e.g. `"Naveen Aluri"`). |
| `action` | `String` | Target action (e.g. `"Track"`). |
| `title` | `String` | Notification title string. |
| `body` | `String` | Notification description / route message text. |
| `Sound` | `String` | Notification sound resource (e.g. `"default"`). |
| `icon` | `String` | Android notification icon identifier (e.g. `"ic_launcher"`). |
| `click_action` | `String` / `Number` | Notification click action identifier. |


---

## 🔍 Troubleshooting

| Issue | Solution |
| :--- | :--- |
| **`IcueNotInitializedException`** | Await `IcueSdk.init(config)` before calling `openLiveTracking`. |
| **Blank Google Maps view** | Ensure Google Maps SDK is enabled with billing active in Google Cloud Console. |
| **Notification tap does not navigate** | Ensure `IcueSdk.navigatorKey` and `IcueNavigatorObserver` are attached to `MaterialApp`. |
| **Permission prompt appears too early** | Use `IcueNotifications.disabled()` or set `autoRequestPermission: false` in `IcueNotifications.firebaseManaged` and call `IcueSdk.notifications.requestPermission()` at the right moment. |

---

## 🤝 Support

- **Live SDK Documentation**: [https://www.icue.school/sdk-docs](https://www.icue.school/sdk-docs)
- **Beta Integration Guide**: [https://www.icue.school/sdk-beta-docs](https://www.icue.school/sdk-beta-docs)
- **Technical Support**: [chakri@thoughtniques.com](mailto:chakri@thoughtniques.com)
- **Package Registry**: [Cloudsmith iCue-SDK](https://dart.cloudsmith.io/icue/icue-sdk/)

---

_© 2026 iCue School Bus Tracking. All rights reserved._
