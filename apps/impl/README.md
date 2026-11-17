# iCue Parent (`impl`)

Parent/guardian app: students, live bus tracking, SafeHands escorts, gate pass, School Connect (complaints, events, entry QR), mess vouchers with online payment, announcements. Migrated from the old `impl` project; see `docs/impl-migration-plan.md` for what moved where.

REST only (no Firestore). Features live in `features/*`; this app keeps the entry point, DI, routing and the home/profile screens.

## Run

Flavors are `dev` and `prod`; the same name goes to `--dart-define=ENV=`.

```bash
flutter run --flavor dev --dart-define=ENV=dev
```

Launch configs for VS Code (including the Firebase emulator variants) are in `.vscode/launch.json`.

## Keys that are not in git

| What | Where |
|---|---|
| Serverless tracker subscription key | `--dart-define=LOCATION_API_KEY=...` (optional `LOCATION_API_URL`) |
| Google Maps key, Android | `MAPS_API_KEY` in `~/.gradle/gradle.properties` or the environment |
| Google Maps key, iOS | `MAPS_API_KEY=...` in `ios/Flutter/Secrets.xcconfig` |
| Release signing | `android/key.properties` pointing at the shared keystore |
| Firebase configs | `android/app/src/<flavor>/google-services.json`, `ios/config/<env>/GoogleService-Info.plist` |

The dev Firebase files temporarily reuse the `icueadmin-dev` apps until the parent dev apps are registered (`com.icue.parent.impl.dev`, `com.thoughtniques.icue.dev`).

## Checks

```bash
melos run lint && melos run format:check && melos run test
```
