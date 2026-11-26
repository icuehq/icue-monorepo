# iCue Admin App

The production admin application for iCue.

## Building Android Artifacts

Run these commands from `apps/icueadmin` (or pass `-t lib/main.dart` from the repository root). Ensure dependencies are resolved (`dart pub get` at repository root) and `android/key.properties` is configured for release signing.

---

### 1. Generate APKs

#### Development APK
Points to the dev backend and Firebase project (`icueadmin-dev`):
```bash
flutter build apk --flavor dev --dart-define=ENV=dev
```
- **Output:** `build/app/outputs/flutter-apk/app-dev-release.apk`
- **Application ID:** `com.thoughtniques.icueadmin.dev`

#### Production APK
Points to the production backend and Firebase project:
```bash
flutter build apk --flavor prod --dart-define=ENV=prod
```
- **Output:** `build/app/outputs/flutter-apk/app-prod-release.apk`
- **Application ID:** `com.thoughtniques.icueadmin`

#### Per-ABI APKs (Optional)
To generate separate APKs per target architecture (`arm64-v8a`, `armeabi-v7a`) rather than a single fat APK, append `--split-per-abi`:
```bash
flutter build apk --flavor dev --dart-define=ENV=dev --split-per-abi
flutter build apk --flavor prod --dart-define=ENV=prod --split-per-abi
```

---

### 2. Generate Android App Bundles (AAB)

Use App Bundles for Google Play Store publishing.

#### Development AAB
```bash
flutter build appbundle --flavor dev --dart-define=ENV=dev
```
- **Output:** `build/app/outputs/bundle/devRelease/app-dev-release.aab`

#### Production AAB
```bash
flutter build appbundle --flavor prod --dart-define=ENV=prod
```
- **Output:** `build/app/outputs/bundle/prodRelease/app-prod-release.aab`

---

### Running Locally

To run directly on an Android device or emulator:

```bash
# Dev
flutter run --flavor dev --dart-define=ENV=dev

# Prod
flutter run --flavor prod --dart-define=ENV=prod
```
