# iCue Admin

<p align="center">
<img src="https://bitbucket.org/icueteam/icueschoolapp/src/main/assets/logo.png" width="300" height="300" />
</p>

## Getting Started

## Generate APK/Appbundle

### For generating the PROD builds

Generating the PROD appbundle:

```sh
flutter build appbundle --dart-define=ENVIRONMENT=PROD --flavor prod
```

Generating the PROD APK:

```sh
flutter build apk --dart-define=ENVIRONMENT=PROD --flavor prod
```

### For generating the DEV builds

Generating the DEV appbundle:

```sh
flutter build appbundle --dart-define=ENVIRONMENT=DEV --flavor dev
```

Generating the DEV APK:

```sh
flutter build apk --dart-define=ENVIRONMENT=DEV --flavor dev
```

### Build Runner CMD

```sh
dart run build_runner build --delete-conflicting-outputs
```

### Send an SMS to the emulator with the following command

```sh
adb emu sms send 900 "20632 is your OTP for iCueAdmin App login. if you did not request for OTP, please contact us at support@thoughtniques.com"
```
