# iCue SDK Project Context

Use this file as the first reference before implementing or updating anything in this repository. It captures the current project shape, runtime flow, key files, and conventions.

## Project Summary

`icue_sdk` is a Flutter package that embeds an iCue school bus live-tracking experience into host apps. The package exposes an SDK facade, initializes environment/session/dependency state, validates a student by identification number, renders a Google Maps live tracking UI, polls iCue backend APIs, animates the bus marker, displays ETA/route/driver info, and provides decoupled push notification management with explicit opt-in contracts.

The root package is the distributable SDK. `example/` is a Flutter app used to exercise the package locally.

## Repository Layout

- `lib/icue_sdk.dart`: public SDK facade, notification manager namespace, and public config types.
- `lib/live_tracking_module.dart`: provider wiring for the tracking feature.
- `lib/config/`: environment selection and base URLs.
- `lib/services/`: session, DI, notification service, tracking animation controller, map math helpers.
- `lib/services/networking/`: Dio API client, routes, result/error wrappers.
- `lib/providers/`: ChangeNotifier state for auth/user, vehicle tracking, notifications.
- `lib/pages/`: SDK screens.
- `lib/dialogs/`: notification and tracking detail dialogs.
- `lib/widgets/`: reusable UI widgets.
- `lib/models/`: API response/domain models, pure-Dart notification models (`IcueNotification`, `IcueNavigationIntent`, `IcueNotifications`, `IcueSetupReport`, `IcueLaunchResult`).
- `assets/`: map marker and preview assets packaged with the SDK.
- `example/`: consumer app showing SDK initialization and `openLiveTracking` calls.

## Public Integration Surface

The exported public entry point is `package:icue_sdk/icue_sdk.dart`.

Important public types and methods:

- `IcueSdkConfig`: requires `apiKey` and `apiUser`, defaults `env` to `IcueEnvironment.prod`, defaults `notifications` to `IcueNotifications.disabled()`.
- `IcueNotifications`: sealed hierarchy (`disabled()`, `hostManaged(...)`, `firebaseManaged(...)`).
- `IcueNotification`: pure-Dart notification model decoupled from `firebase_messaging` `RemoteMessage`.
- `IcueNavigationIntent`: typed navigation intent emitted upon notification tap or deep link.
- `IcueLaunchResult`: typed outcome returned by `openLiveTracking` and `openLiveTrackingFromRoot` (`success`, `buffered`, `failure`).
- `IcueSetupReport`: preflight diagnostic report returned by `IcueSdk.checkSetup()`, with `toDiagnosticSummary()` for formatted ASCII output.
- `IcueNotificationManager` (`IcueSdk.notifications`): namespace for runtime notification configuration, permissions, unified message forwarding (`handleMessage`, `handleTap`), multi-student registration (`registerStudent`, `registerStudents`, `getRegisteredStudents`), and intent streams.
- `IcueSdk.isInitialized`: boolean flag indicating whether the SDK is actively configured.
- `IcueSdk.init(config)`: initializes the SDK on demand with transactional rollback on failure.
- `IcueSdk.reconfigure(config)`: updates API credentials and switches active school/environment dynamically without dropping sessions on notification updates.
- `IcueSdk.checkSetup()`: runs diagnostics on credentials, session, permissions, and navigator bindings.
- `IcueSdk.openLiveTracking(context, identificationNo: ...)`: pushes the tracking flow and returns `Future<IcueLaunchResult>`.
- `IcueSdk.openLiveTrackingFromRoot(identificationNo: ...)`: opens tracking from root navigator, buffering if unmounted.
- `IcueSdk.logout()`: unregisters device/student tokens from iCue backend and clears session state without invalidating the device's FCM token.
- `IcueSdk.navigatorKey`: default key host apps can assign to `MaterialApp.navigatorKey`.
- `IcueNavigatorObserver`: replays buffered cold-start notification navigation when the navigator becomes ready.

## Runtime Flow

1. Host app calls `IcueSdk.init` on demand (e.g. on student login or before opening tracking).
2. `IcueSdk.init` stores config, initializes `IcueEnv`, configures GetIt/Injectable dependencies, stores config in `SessionService`, and configures `NotificationService` according to `IcueNotifications`.
3. If `IcueNotifications.firebaseManaged` is specified, Firebase listeners and tokens are initialized asynchronously in the background without delaying core tracking readiness.
4. Host app calls `IcueSdk.openLiveTracking(context, identificationNo: studentId)`.
5. SDK stores `identificationNo` in `SessionService` and pushes `LiveTrackingModule`.
6. `LiveTrackingModule` provides singleton instances of `UserProvider`, `VehicleProvider`, and `NotificationsProvider`.
7. `InitialPage` calls `UserProvider.validateUserAuth` after first frame.
8. On auth success, `InitialPage` displays `LiveTrackingPage`.
9. `LiveTrackingPage` creates `LiveTrackingController`, loads package marker assets, and starts tracking.
10. `LiveTrackingController` calls `VehicleProvider.getVehicleLocation`, then polls every 5 seconds while active.
11. `VehicleProvider` fetches/caches route coordinates, vehicle location, route metadata, bus stops, pickup/drop points, and builds `LiveData`.
12. `LiveTrackingController` turns `LiveData` into Google Maps markers, polylines, pulse circles, camera targets, and smooth marker animation.

## Notifications Contract

`NotificationService` handles notifications with an explicit opt-in model:

- **Disabled mode (`IcueNotifications.disabled`)**: No Firebase listeners, no token fetching, no permission prompts. Pure tracking.
- **Host-managed mode (`IcueNotifications.hostManaged`)**: Host passes device token via `setToken(token)`, receives `IcueNotification` and `IcueNavigationIntent`, and routes navigation explicitly or automatically.
- **Firebase-managed mode (`IcueNotifications.firebaseManaged`)**: SDK attaches FCM listeners, handles foreground banners based on `IcueNotificationPresentation` (`sdkBanner`, `system`, `hostManaged`, `none`), and synchronizes tokens.
- **Token Ownership**: `logout()` and `unregisterToken()` only detach student/device associations on the iCue backend (`/v1.0/logout`). The underlying device FCM token is never deleted, protecting host application push features.
- **Multi-Student**: `IcueSdk.notifications.registerStudent(studentId)` and `unregisterStudent(studentId)` support multi-child family applications.

## State and Persistence

`SessionService` stores:
- SDK config.
- Active student identification number.
- Authenticated `User`.
- Device push token.
- Registered student ID lists for notifications.
- Session storage keys are namespaced by `apiUser` (`icue_${apiUser}_user_${studentId}`, `icue_${apiUser}_active_id`) to prevent collisions across multiple school environments.

## Testing Status

The test suite contains comprehensive automated unit and widget tests covering:
- API client error handling and token refresh.
- Map math and dead reckoning bearing calculations.
- Data models serialization and edge cases.
- SDK compatibility, DI isolation, and transactional initialization.
- Notification contract modes, presentation policies, streams, and intent routing.
- Multi-student registration and logout token preservation.
- Preflight diagnostic reports (`checkSetup`).

Run all tests:
```bash
flutter test
```
