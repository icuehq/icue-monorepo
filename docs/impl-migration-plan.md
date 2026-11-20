# Parent app (`impl`) migration plan

Old: `/Users/naveenaluri/Development/icue/impl` (parent/student app, 134 Dart files, ~23.5k LOC, v6.1.1+71, 44 screens, ~46 API endpoints).
New: `apps/impl` (scaffold: empty `main.dart`, depends only on `api_client`).

Goal: 100% functional parity, rebuilt on the workspace architecture (AGENTS.md): feature packages own models/services/providers/UI/routes; the app keeps only entry point, routing, DI, theme, Firebase options.

## 0. Decisions (settled)

| # | Decision |
|---|---|
| D1 | `dev`/`prod` flavors like `super_admin` (`android/app/src/<flavor>/`, `ios/config/<env>/`), `app_firebase_options*` switched by `ENV`/`FLAVOR`. Local Firebase emulator support like `icueadmin`: `--dart-define=FIREBASE_EMULATOR=<host>` (debug/profile only), emulator launch configs for Android and iOS, signing in with the locally built unsigned custom token. Owner supplies the per-env `google-services.json` / `GoogleService-Info.plist` |
| D2 | Keep legacy ids (Android `com.icue.parent.impl`, iOS prod `com.thoughtniques.icue`); version continues from `6.1.1+71` |
| D3 | Keep en + es ARBs and locale switching |
| D4 | ~~Drop `flutter_cashfree_pg_sdk`~~ **Reversed in Phase 6:** the old payment page uses the Cashfree SDK (the Phase 0 search missed it by looking for the capitalised name). It is kept, in `features/mess_meals` only. |
| D5 | Port both live-tracking pages (v1 and v2) |
| D6 | Parent login (`/generateOtp`, `/parentLogin`) differs from staff login: add parent methods to `auth` |

## 1. Hard rules carried over from the repo

- Secrets: legacy folder holds `app_private_key.pem`, `password`, `iCueParent.jks`, `pepk.jar`, `encryption_public_key.pem`. The shared keystore (`iCueParent.jks`) is the same one all apps use and is not copied. `app_private_key.pem`, `encryption_public_key.pem` and `pepk.jar` are already copied into `apps/impl` and gitignored there; never commit them. The Azure APIM subscription key (`services/api_client.dart`) and the Google Maps key (`web/index.html`) are hardcoded in source: move to `--dart-define` / manifest placeholders, rotate them.
- HTTP only through `api_client`; env via `ApiEnvironment` (`--dart-define=ENV=`). The legacy default was PROD, the new default is dev: build scripts must pass `ENV=prod`.
- No Hive in the app: `local_storage`. No new Dio clients: the Azure client becomes a second `api_client` instance with its own base URL and key header.
- Screens ≤ 500 lines (legacy offenders: `select_date_dialog` 830, `live_tracking_page` 764, `live_tracking_v2_page` 725, `event_payment_history_page` 509); `constants.dart` (1989 lines, month and tracking lookup tables plus policy text) is split by owner.
- No widget tests; unit-test models/services/providers only. No legacy shims.
- Never run APK/iOS builds without being asked; emulators only for Firebase.

## 2. Target structure

New packages (add to root `workspace:`, `apps/impl/lib/di/injection.dart`, barrel + `<Feature>Routes` + `<feature>Routes()`):

| Package | Owns (legacy source) |
|---|---|
| `features/students` | `Student`/`User` models, `user_provider`, `students_list_page`, `student_info_bar`, selected-student state, `getStudentsList`, `getStuRtDetails`, `getStuLinkUrl` |
| `features/parent_transport` | `track_bus_page`, `live_tracking*` pages and providers, `student_vehicles` (`my_vehicles`), `transport_attendance_page`, route notifications, `vehicle_location`, `route_coordinates`, `active_route`, `getStuTransportInfo`, tracking info card/dialog |
| `features/safehands` | `safehands_page`, `escort/*`, `safehands`+`escort` models/providers, PIN status, escort photos |
| `features/school_connect` | hub page, complaints (+post), appointments, events (+payment history, QR via `genParentQRCodeForSchoolEvents`), request-for-entry (QR), academics/homework placeholders |
| `features/mess_meals` | `mess_meals_page`, menu, instant purchase, wallet recharge, voucher purchase flow (7 pages), `meals_provider` (500 lines, split), meal models |

Extend existing packages (do not duplicate):

| Existing | Add |
|---|---|
| `auth` | Parent OTP + login (`/generateOtp`, `/parentLogin`), role actions (`/getActionsByRole`), push token register/remove (`/updateRegTokens`, `/logout`), login/OTP screens |
| `gatepass` | Parent requests: `requestGatePass`, `getStuGatePass`, `getGatePassTypes` (already present), request list + generate pages |
| `announcements` | `getAnnouncementsByStudent` + parent list page |
| `icue_firebase` | Already has analytics, crashlytics, `notification_service` (replaces legacy `notification_service.dart` 445 lines, `crashlytics_service`, `analytics_service`, `ScreenTracker`). Extend only for local-notification channels / tap routing the legacy had |
| `icue_ui` | Replace app widgets (table below). Add only what a second app would reuse |

App-only (`apps/impl/lib`): `main.dart`, `app_firebase_options*`, `di/`, `routing/` (`app_router.dart`, `app_routes.dart`, shell with bottom/home), theme wiring (`IcueTheme`, Montserrat via `icue_fonts`), splash, dashboard, profile pages, notification-tap page, WebView page, `student_home_card`, `tile`, notifications dialog, ARBs.

### Widget and helper reuse map

| Legacy | Replace with |
|---|---|
| `gradient_button`, `inputfield`, `dropdown` | `IcueButton`, `IcueTextField`, `IcueDropdown` |
| `no_data_widget`, `coming_soon_page` | `IcueEmptyState` (+ app `ComingSoonPage` if still needed) |
| `AppUtils` snackbars, `loading_dialog`, `delete_dialog`, `logout_dialog` | `IcueToast`, `IcueDialog` |
| `date_range_selector`, `calendar_widget`, `select_date_dialog` (Syncfusion, 830 lines) | `IcueDateField`, `IcueDateFilterModal`; drop `syncfusion_flutter_datepicker` unless a range need survives |
| `app_update_checker` | `IcueAppUpdateService` |
| `file_picker_utils` | `pickFile` in `icue_ui` (`icue_file_picking.dart`) |
| Offline/no-wifi handling | `IcueConnectivityService` + `IcueConnectivityBanner` |
| Shimmer/loading placeholders | `IcueSkeleton` |
| Date/currency helpers in `app_utils` | `toNumericDate`, `toRupees`, etc. (Indian formats rule) |
| `hive_service` | `local_storage` |
| `ApiClient` + `_CombinedInterceptor` | `api_client` (`AuthInterceptor`, `ErrorInterceptor`); see phase 1 caveat |

Dependencies to add to `apps/impl`: `google_maps_flutter`, `flutter_inappwebview`, `qr_flutter`, `confetti`, `timelines_plus` (notification timeline), `dotted_border`, `app_settings`, `device_info_plus`, `flutter_local_notifications` (only if `icue_firebase` does not already expose it), `provider`, `go_router`, `get_it`, `injectable`, `firebase_*` via `icue_firebase`. Dropped: `device_preview`, `hive*`, `dio`, `flutter_cashfree_pg_sdk` (D4), `in_app_update` (check `icue_ui` already carries it), `syncfusion` (above).

## 3. Phases (one per session on the shared branch; update this doc at the end of each)

**Phase 1 – App shell and auth (DONE except items under "Phase 1 leftovers").** Native: flavors `dev`/`prod`, Firebase configs, ids per D1/D2, permissions (camera, photos, location for Maps, notifications), Maps API key placeholder. `pubspec`, `lib/di/injection.dart`, `app_router.dart` (splash → login → otp → students-list → shell), theme, analytics screen tracking. Auth parent flow. Caveat: `AuthInterceptor` injects `Source=adminapp`, `BranchId`, `OrganizationId`, `ZoneId` into POST bodies; diff against legacy `_CombinedInterceptor` and make `source` configurable (`parentapp` value from the legacy code) and the metadata injection match what parent endpoints expect. `students` package: list, selection, persistence. Dashboard + profile (children, terms, privacy, logout). Done when login → pick student → dashboard works against dev.

**Phase 2 – Notifications, announcements, gate pass (DONE; see result below).** Push registration, foreground/background handler (the legacy background handler re-initialises Firebase with the right options), notification-tap routing, notifications dialog, `getRouteNotifications`. Announcements and gate-pass parent screens inside the existing packages.

**Phase 3 – Transport (DONE; see result below).** `parent_transport`: track-bus entry, both live-tracking pages (split the 700+ line files into map, bottom card, ETA/legend widgets), Azure client, route coordinates, my vehicles CRUD (+ image), transport attendance, tracking info dialog. Maps-key handling per section 1.

**Phase 4 – SafeHands (DONE; see result below).** Token create/status, escort list/add (photo via `pickFile`, `dotted_border`), delete photo.

**Phase 5 – School Connect (DONE; see result below).** Hub, complaints (types, list, post with photo), events + payment history + QR, appointments, request-for-entry QR, PTM/academics/homework routes (currently coming-soon: keep as coming-soon routes, same paths).

**Phase 6 – Mess meals and payments (DONE; see result below).** Config/days/holidays, menu, instant purchase, voucher select → summary → payment (WebView + confetti success), purchases/history, voucher details dialog, wallet recharge, `payment_page`, `webview_page`. Split `meals_provider`. Highest risk: money; keep request payloads byte-compatible with legacy and unit-test every payload builder.

**Phase 7 – Parity sweep and cleanup (DONE; see result below).** Run the checklists in section 4, l10n (D3), update `AGENTS.md` (the `apps/impl — scaffold only` line, package list, new packages in workspace/DI rules), `melos run lint`, `format:check`, `test`, `gen`. Delete nothing in the legacy repo; it stays the reference until sign-off.

### Phase 1 result

Built: `apps/impl` bootstrap (Firebase, DI, storage, update check, `Source=parentapp`, 401 -> login), router with auth/student redirects, dashboard (server-driven tiles), profile (children, language en/es, terms, privacy, logout), `features/students` (student list, children tabs, role actions, route details), parent login/OTP/session in `features/auth` (`ParentAuthProvider`, `ParentTokenProvider`, `ParentSessionStorage`), `packages/parent_l10n`, `IcueSheetBody`/`IcueContextBar`/`IcueAssets` in `icue_ui`. Android and iOS `dev`/`prod` flavors with legacy ids, icons, permissions and prod Firebase configs; emulator launch configs (`FIREBASE_EMULATOR`). Unit tests for parent models, auth service and students service. `flutter analyze` is clean for `apps/impl`, `features/auth`, `features/students`, `packages/icue_ui`, `packages/parent_l10n`, `apps/icueadmin`, `apps/super_admin`, `features/library`.

Notes and decisions made:
- Session storage is new (`parentSession-v1`, JSON strings); installed legacy users are signed out once on update, no migration shim.
- Theme is the shared `IcueTheme` (teal), not the legacy green/purple.
- `features/library` `xml` lowered to `^7.0.0` so `flutter_svg` resolves.
- Dashboard `TrackingCard` arrives with Phase 3; `/profile/my-vehicles`, notification-tap routing and the other menu routes fall to the coming-soon page until their phases.
- Google Maps key was removed from the manifest/AppDelegate; Phase 3 re-adds it through a build placeholder.

Phase 1 leftovers (need the owner or a device):
- Dev Firebase: `icueadmin-dev` has no parent apps registered. Dev builds temporarily reuse the icueadmin dev app ids (`firebase_options_dev.dart`, `android/app/src/dev/google-services.json`, `ios/config/dev/GoogleService-Info.plist`). Register `com.icue.parent.impl.dev` and `com.thoughtniques.icue.dev` in `icueadmin-dev` and replace these three files.
- Release signing: provide `android/key.properties` (gitignored) pointing at the shared keystore.
- Run `pod install` for iOS and a device/simulator smoke test of login -> pick child -> dashboard; nothing has been built or run natively.
- Confirm the legacy `NSAllowsArbitraryLoads` ATS exception is still needed (kept for parity).

### Phase 2 result

Built: parent announcements (`ParentAnnouncement*`, page with tappable links/phones) in `features/announcements`; parent gate pass (types, request for today, requests list with a 10-day range, status pill) in `features/gatepass`; both mount under the dashboard route (`parentAnnouncementsRoutes()`, `parentGatePassRoutes()`, paths `/layout.announcements`, `/layout.gatepass`, `/layout.gatepass/gatepass-requests`). Push taps: `parseNotificationTap` + `_onNotificationTap` in `apps/impl` switch to the student in the payload (`StudentId`, `action`), reload its menu, then open Track, Announcement or home. Gate pass data resets when the student changes. Unit tests for the tap parser and the parent gate pass service.

Differences from legacy:
- The internal `/notification-tap` page is gone; the tap handler does its work directly.
- Route notifications history (`getRouteNotifications`, timeline dialog) moves to Phase 3 with live tracking, where it is opened from.
- Foreground/background message display and the notification channel come from `icue_firebase` (`high_importance_channel`, same id as the manifest).
- Not device-tested: tapping a push from a terminated app.

### Phase 3 result

Built `features/parent_transport`: live bus tracking for both data sources in one page (`isServerLessConfig` picks the serverless tracker, else the school server), shared map widget (route polyline, stops, school and student markers, gliding bus, follow/re-centre), info card (route, ETA, call driver), route notifications timeline, "no tracking" dialog with 5 s auto-close, My Vehicles (add/delete with plate validation), Transport Attendance (10-day range via the new `IcueDateRangeChip`, also used by gate pass), and the home `LiveTrackingBanner`. Routes: `/layout.trackbus`, `/layout.transportattendance`, `/profile/my-vehicles`. Tests cover geometry, parsing and the service. `analyze` and tests pass for `apps/impl`, `parent_transport`, `gatepass`, `auth`, `api_client`, `icue_ui`, `icueadmin`.

Changes from legacy:
- The three duplicate providers (`VehicleProvider`, `LiveTrackingProvider`, `LiveTrackingV2Provider`) are one `ParentTrackingProvider`; the two near-identical 700-line pages are one page plus `LiveMap`. The unused legacy `LiveTrackingProvider` is dropped.
- Route data is cached in memory per student (legacy used Hive); the `getTraceDate` freshness check is kept.
- The serverless route id was hardcoded to `2732` in legacy v2. It now comes from the student's first route in `getStuRtDetails` (`Routes[0].Id` and `Mode`); `getRouteCoordinate` already used that id as the route-details id, so this matches. Confirm the choice when a student has both a pickup and a drop route.
- Unused response fields (speed, deviation, RD, push flags) are not parsed.
- Errors for "not started / completed" are localized by the page, not set as text by the provider.

Setup you must do (nothing secret is committed):
- Serverless tracker: `--dart-define=LOCATION_API_KEY=<subscription key>` (and optionally `LOCATION_API_URL`). The old key was hardcoded in legacy source and should be rotated. Without the key, serverless students cannot track.
- Android Maps: `MAPS_API_KEY` in `~/.gradle/gradle.properties` or the environment.
- iOS Maps: `MAPS_API_KEY=<key>` in `ios/Flutter/Secrets.xcconfig` (gitignored).
- Not device-tested: map rendering, gliding, and push-then-track flow.

### Phase 4 result

Built `features/safehands`: today's PIN (generate or show), escort list with photo viewer and delete confirmation, add escort (permanent or temporary with a date range, photo from camera or gallery through the shared `pickFile`, dotted photo box). Routes keep the old spelling: `/layout.Safehands`, `/layout.Safehands/escort`, `/layout.Safehands/escort/add-escort`. Tests cover the PIN and escort parsing and the upload form keys.

Changes from legacy:
- `getSafeHandsPINStatus` is not ported: the legacy provider defined it but no screen called it.
- The Safe Hands artwork is the bundled `safe-hands.svg` instead of fetching the menu icon from the server.
- `saveEscortPhoto` still sends `Source=adminapp` in the form, exactly as the old app did; confirm with the backend before changing it.
- The server's refusal message (`err: true`) is now shown; the old app stayed silent.
- Camera/photo permission texts in `Info.plist` now describe escort photos.
 (tick during each phase)

- Routes: all 44 `GoRoute` paths in legacy `main.dart` (including odd ones such as `layout.trackbus`, `Layout.events`, `complaints`, notification-tap) keep identical path strings because the server sends them in push payloads and menu actions. Port `getActionsByRole`-driven dashboard tile visibility verbatim.
- Endpoints (all `/v1.0` unless noted): `generateOtp, parentLogin, logout, updateRegTokens, getActionsByRole, getStudentsList, getStuRtDetails, getStuLinkUrl, getStuTransportInfo, getStudentVehicles, saveStudentVehicle, deleteStudentVehicle, getactiveroute, getlivetrack, getVehicleLocation, getRouteCoordinate, getRouteNotifications, getTraceDate, CreateSafeHandsToken, GetSafeHandsTokenByStudent, getSafeHandsPINStatus, getEscortPhotos, saveEscortPhoto, deleteEscortPhoto, getFeedbackComplaintTypes, getFeedbackComplaintsByParent, postFeedbackComplaints, showEventsToParents, getStuEventPyments, genParentQRCodeForSchoolEvents, getAnnouncementsByStudent, getGatePassTypes, requestGatePass, getStuGatePass, getMealCnfgForApp, getMealDays, getMealVouchers, getMealVoucherDetails, getMealVoucherEffectiveDate/Dt, calcMealVoucherCharges, getStuMessCnfg, getStuPurchasedDates, messPaymentCheckOut, pingConnStats, sendTestPush` plus the Azure `locservices` call. Confirm the exact version prefix of each from the legacy provider.
- Models: keep JSON keys identical (the legacy `user.g.dart`, `route_coordinates.g.dart`, `vehicle_location.g.dart` are Hive/json adapters; regenerate only what is still needed, otherwise hand-written `fromJson`).
- Assets: `assets/*.svg|webp|png` move into the owning feature (`packages/<pkg>/assets/...`); shared logos go in `icue_ui`. Fonts come from `icue_ui`.
- Platform: URL schemes / deep links, notification icons and channels, entitlements (`Runner.entitlements`), `in_app_update`, edge-to-edge setup, web `index.html` Maps script (web support only if the legacy shipped web; confirm).
- Behaviours easy to miss: selected-student persistence across restarts, connectivity ping (`pingConnStats`), app-settings deep link on denied notifications (dashboard), locale switching, 401 handling and logout, `errorBuilder` → coming-soon, `ScreenTracker` names preserved for analytics continuity.

### Phase 7 result

Sweep done against the old app:
- **Routes:** every old path exists with the same spelling. Only `/splash` (replaced by the bootstrap splash) and `/notification-tap` (the tap handler navigates directly) are gone; `/coming-soon` was added back.
- **Endpoints:** every endpoint any old screen called is ported. Not ported because no screen called them: `getSafeHandsPINStatus`, `getMealDays`, `sendTestPush`.
- **Analytics:** routes are named with the old `ScreenTracker` names (`dashboard-page`, `track-bus-page`, `Meal Vourchers History`, ...) and `AnalyticsService.observer` logs `screen_view`, so the events continue. The old per-screen duration event is not ported.
- **Strings:** English and Spanish keys match one to one; no hardcoded user text remains in the parent features except the pre-localization splash and the two legal pages (English only, as before).
- **Docs:** `apps/impl/README.md` (run flags, keys that are not in git); AGENTS.md describes the app and its features.

Checks on the whole workspace: `melos run lint` passes; `dart format` is clean; tests pass in every package except two in `icue_firebase` (`firestore_pager_test`: `CrashlyticsService.recordError` needs an initialised Firebase), a package this work did not touch; `check-naming.mjs` reports 10 one/two-letter names, all in `features/inventory`, `features/library` and `firebase/` tests, none in the parent code.

## 5. Out of scope / risks

Still open (need the owner or a device):
- Register the parent dev apps in `icueadmin-dev` and replace the three temporary dev Firebase files.
- Provide `android/key.properties`, the Maps keys and `LOCATION_API_KEY`; rotate the old hardcoded Azure and Maps keys.
- `pod install`, then a device run of the whole flow (login, pick child, tracking, SafeHands, gate pass, School Connect, a sandbox meal payment).
- Confirm with the backend: the serverless route id source (`getStuRtDetails` first route), `Source=adminapp` on `saveEscortPhoto`, and the `NSAllowsArbitraryLoads` ATS exception.
- Web is not supported (the old `web/` build only served DevicePreview): the Maps web script and keys are not set up.
- Users are signed out once when they update, because the session storage is new.


- Firestore: the parent app is REST-only (no `cloud_firestore`), so none of the branch-tenant Firebase rules apply.
- Highest risk: payment flow, live tracking (maps + polling), interceptor behaviour differences (`Source`/`BranchId` injection), iOS bundle id and version continuity (store rejection if lower than `6.1.1+71`).
- Ordering assumes phases 2–6 are independent after phase 1; they can run as parallel sessions if each touches only its own package plus an append-only line in `injection.dart` and `app_router.dart`.
