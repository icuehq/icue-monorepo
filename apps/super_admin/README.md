# Super Admin App

Android super-admin application for student face enrollment, identification, and face attendance.

## Building APKs

Run commands from the `apps/super_admin` directory (or specify `-t lib/main.dart` from the root). Ensure dependencies are resolved (`dart pub get` at the repository root).

### 1. Development APK

Builds the app pointing to the `dev` backend environment and Firebase project (`icueadmin-dev`):

```bash
flutter build apk --flavor dev --dart-define=ENV=dev
```

- **Output:** `build/app/outputs/flutter-apk/app-dev-release.apk`
- **Application ID:** `school.icue.super_admin.dev`

### 2. Production APK

Builds the app pointing to the `prod` backend environment and Firebase project:

```bash
flutter build apk --flavor prod --dart-define=ENV=prod
```

- **Output:** `build/app/outputs/flutter-apk/app-prod-release.apk`
- **Application ID:** `school.icue.super_admin`

---

### Per-ABI APKs (Optional)

To generate smaller, architecture-specific APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) instead of a single fat APK, append `--split-per-abi`:

```bash
flutter build apk --flavor dev --dart-define=ENV=dev --split-per-abi
flutter build apk --flavor prod --dart-define=ENV=prod --split-per-abi
```

### Running Locally

To run directly on a connected Android device or emulator:

```bash
# Dev
flutter run --flavor dev --dart-define=ENV=dev

# Prod
flutter run --flavor prod --dart-define=ENV=prod
```
