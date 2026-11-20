## 0.2.0-beta.3

- What changed
- Another change

## 0.2.0-beta.2

- **Package Bundle Optimization**: Excluded `example/` app and development tooling from published distribution archive via `.pubignore` to optimize package download size.
- **Documentation Overhaul**: Redesigned developer integration documentation (`icue-sdk-docs.html`) with Light/Dark mode themes, versioning support, enhanced API references, and preflight diagnostic guides.

## 0.2.0-beta.1

- **Decoupled Notification Architecture**: Introduced sealed `IcueNotifications` hierarchy (`disabled`, `hostManaged`, `firebaseManaged`) with explicit opt-in contracts and pure-Dart models (`IcueNotification`, `IcueNavigationIntent`, `IcuePlatformCredentials`).
- **Dynamic On-Demand Initialization & Reconfiguration**: Added `IcueSdk.reconfigure(config)` and transactional runtime updates to credentials, environments, and notification modes without throwing configuration errors.
- **Typed Launch Outcomes**: `IcueSdk.openLiveTracking` and `IcueSdk.openLiveTrackingFromRoot` now return typed `IcueLaunchResult` (`IcueLaunchSuccess`, `IcueLaunchBuffered`, `IcueLaunchFailure`).
- **Preflight Diagnostics**: Added `IcueSdk.checkSetup()` returning `IcueSetupReport` with `report.isReady` and ASCII `toDiagnosticSummary()`.
- **Multi-Student Push Notification Management**: Added `IcueSdk.notifications.registerStudent`, `registerStudents`, `unregisterStudent`, `unregisterAllStudents`, and `getRegisteredStudents`.
- **Safe Token Preservation**: `IcueSdk.logout()` and `unregisterToken()` detach student associations on the iCue backend without deleting or invalidating the device's provider FCM token. Added `IcueNotificationManager.invalidateProviderToken()` for explicit deletion.
- **In-App Notification Banner**: Added animated foreground banner overlay configurable via `IcueNotificationPresentation.sdkBanner`.
- **Unified Handlers & Streams**: Added `IcueSdk.onNotificationTapped` stream, `IcueSdk.notifications.handleMessage`, and `IcueSdk.notifications.handleTap` for seamless integration with custom routers and host message pipelines.

## 0.1.1

- Extracted device information handling into a dedicated `DeviceInfoService`.
- Added SDK logout functionality through `IcueSdk.logout()`, including backend token removal and Firebase registration-token deletion.
- Exposed `IcueSdk.deleteToken()` and `IcueSdk.deletePushToken()` for deleting a push token independently of the student session.
- Added host-managed push token ingestion with `IcueSdk.setPushToken` and device-wide token persistence.
- Added pure-Dart Firebase credentials through `IcuePlatformCredentials` and `IcueFirebaseOptions.fromCredentials`.
- Replaced the former named secondary Firebase app strategy with default-app reuse or initialization, matching `firebase_messaging` behavior.
- Added configurable notification permission requests, FCM background-handler registration, and Android notification icons.
- Added iCue payload filtering, flat and namespaced `AdmissionNo` extraction, background-message forwarding, and cold-start navigation buffering through `IcueNavigatorObserver`.
- Made SDK initialization idempotent and concurrency-safe while rejecting conflicting API or Firebase configuration.
- Isolated the SDK dependency container from the host application's global GetIt instance.
- Hardened student switching, stale authentication responses, API error mapping, retry-loop prevention, model parsing, coordinate validation, and notification decoding.
- Broadened compatible dependency ranges while requiring Dart 3 and Flutter 3.10 or newer.
- Added unit tests for sessions, models, API behavior, notifications, payload compatibility, and SDK initialization.
- Enhanced example app with multi-student identification number switching.

## 0.1.0

- Upgraded live tracking architecture with smooth 60 FPS vehicle movement and continuous real-time camera tracking.
- Throttled (~30 FPS) and deduplicated marker emissions to eliminate Google Maps marker flicker.
- Adaptive polling intervals (10s when stopped, 3s near stop, 5s normal) and 2-poll network debouncing.
- Top animated "GPS signal lost" banner (`isOfflineNotifier`) and floating "Connecting to live GPS..." status pill (`isLoadingNotifier`).
- Dual-layer route polyline rendering (border + fill).
- Smooth off-route gliding, 300ms backward correction, and 800ms catch-up glide.
- Instant page navigation by removing full-screen loading spinners.
- Fixed timestamp skew calculation in `VehicleProvider` using `parseStrict` and `.abs()`.

## 0.0.9

- Added notifications support.

## 0.0.8

- Added bus stop support to live tracking with improved marker rendering.
- Enhanced bus marker motion smoothing using Exponential Moving Average (EMA) for rotation and refined look-ahead logic.
- Improved polyline path-snapping with index penalties to prevent "jumping" on overlapping route segments.
- Added session state clearing logic to `VehicleProvider` and `LiveTrackingController`.
- Map recentering now preserves the user's zoom level.

## 0.0.7

- Added `BearingHelper` utility class with Haversine distance, geographic bearing, marker rotation, coordinate interpolation, and dead-reckoning extrapolation.
- Map recentering now preserves the user's zoom level; only the initial camera placement and explicit recenter taps reset zoom to 18.
- Bus animation uses a vsync `Ticker` for dead reckoning between polls, keeping the marker moving smoothly at 60 fps without Timer stutter.
- Replaced full-set marker iteration with a static marker cache, reducing per-frame overhead at 60 fps.
- Path segment traversal is now O(1) by advancing the index monotonically within each animation cycle.
- Bus marker rotation uses time-delta clamped angular velocity, making rotation frame-rate independent and removing discontinuous branching.

## 0.0.6

- Added `NotificationService` with full FCM lifecycle management (foreground, background, cold-start).
- SDK now creates a named secondary Firebase app (`icue_sdk_secondary_app`) to avoid conflicts with the host app's Firebase instance.
- `IcueSdk.openLiveTrackingFromRoot` added for context-less navigation from notification taps.
- `IcueSdk.setNavigatorKey` added so host apps can supply their own navigator key.
- Session persistence: user data and FCM token are stored in `SharedPreferences` and restored on re-entry.
- Automatic token refresh via `TokenRefreshInterceptor` — expired sessions are silently renewed without user action.

## 0.0.5

- Refactored `LiveTrackingController` into a standalone class with `ValueNotifier`-driven state.
- Replaced `Timer.periodic` polling with a sequential async loop to eliminate overlapping API calls.
- Added smooth 60fps bus animation along the route polyline with path-snapping.
- Added pulse circle animation around the bus marker.
- Bus marker rotation now uses shortest-angle interpolation to avoid 360° wrapping.

## 0.0.4

- Improved inline API documentation across all public classes and methods.
- Added `IcueSdkConfig` and `IcueSdk` dartdoc comments.
- Expanded platform setup documentation in README.

## 0.0.3

- Updated package metadata for Cloudsmith private registry publishing.
- Fixed README platform setup notes for Android and iOS.

## 0.0.2

- Initial public release with live tracking module, `VehicleProvider`, `UserProvider`, and `NotificationsProvider`.
- Google Maps integration with route polyline, student marker, and bus marker.
- `TrackingInfoCard` with pickup point, route number, ETA, and optional driver call button.

## 0.0.1

- Internal development preview. Not published.
