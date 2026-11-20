# iCue SDK Example

This app is configured to test live tracking and Firebase Cloud Messaging through the SDK.

## Firebase Setup

The example uses FlutterFire-generated options from `lib/firebase_options.dart` and configures `IcueNotifications.firebaseManaged` in `IcueSdk.init`.

It also assigns `IcueSdk.navigatorKey` and installs `IcueNavigatorObserver` so
notification navigation received during cold start is replayed once the root
navigator is ready.

This example assumes a consumer-owned Firebase project. The SDK reads the FCM
token from the default Firebase app and sends it to iCue after student
authentication. For server-side delivery, the iCue backend must be configured with
this Firebase project's sending credentials.

Android files configured:

- `android/app/google-services.json`
- Google Services Gradle plugin in `android/settings.gradle.kts`
- `com.google.gms.google-services` applied in `android/app/build.gradle.kts`
- `POST_NOTIFICATIONS` permission in `android/app/src/main/AndroidManifest.xml`

iOS files configured:

- `ios/Runner/GoogleService-Info.plist`
- `ios/Runner/Runner.entitlements` with `aps-environment`
- `UIBackgroundModes` / `remote-notification` in `ios/Runner/Info.plist`

For physical iOS device testing, also enable these in Xcode for the Runner target:

- A valid signing team and provisioning profile
- Firebase Console APNs key or certificate for this bundle id

## Test Steps

1. Run the app on a real Android or iOS device.
2. Sign in with one of the pre-configured students so the SDK can authenticate the student and register the FCM token with iCue.
3. Watch the debug logs for `FCM SERVER TOKEN` and `updateRegTokens`.
4. Send a test FCM message from Firebase Console or your server.
5. Tap the notification. The SDK should open live tracking for the `AdmissionNo` in the payload.
6. Tap the logout icon in the AppBar to verify that `IcueSdk.logout()` cleanly unregisters push token associations from the iCue backend without deleting the device's FCM token.

The SDK defaults to `autoRegisterFcmBackgroundHandler: false` so it does not
replace a handler owned by the host app. Set it to `true` in `IcueNotifications.firebaseManaged`
when specifically testing SDK background registration, or forward iCue messages from the
host's existing handler with `IcueSdk.handleBackgroundMessage`.

Sample Notification Response received by device (`RemoteMessage.data`):

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

The SDK receives foreground messages, displays an in-app banner overlay (and broadcasts to streams/callbacks), handles notification taps, and routes to `IcueSdk.openLiveTrackingFromRoot`.
