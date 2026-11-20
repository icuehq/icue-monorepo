# icueadmin migration gap report

Old: `icue_monorepo/apps/icueadmin` (183 files, ~31k LOC). New: `repo-v2` (`apps/icueadmin` + `features/*`).
Method: static diff of routes, API endpoints, JSON keys, UI strings, dependencies, assets, platform config; `flutter analyze` and existing tests.

## Verdict

Structure and plumbing are migrated well. **Business flows are not**: anything that picks a file or photo is faked, one whole app-settings subsystem is gone, and the expense payloads were redesigned and no longer match the old contract.

- `flutter analyze` (all non-inventory packages): clean (1 pubspec sort info). So the breakage is behavioural, not compile errors.
- `flutter test`: 121 pass. No test covers the broken areas below (the unit tests use fake services).

## What migrated correctly

- All 12 domain features have models, services, providers, DI and screens. Every old reachable page has a new counterpart.
- Auth/OTP login, role actions, branches, push-token register/remove, logout, Crashlytics, store update check, Hive to `local_storage`, fleet socket, attendance session manager, face-SDK attendance, analytics (replaces `ScreenTracker`).
- Model JSON keys match the old ones. Missing keys (`BranchId`, `ZoneId`, `Source`, and so on) are injected by the new `AuthInterceptor`.
- API endpoints: all live ones are present. Added in new: `firebaseToken`, `changeStudentRoutes`, `getPrsnAlcoholTest`.

## Critical (feature does not work)

### C1. File/photo picking is faked everywhere — FIXED (not device-tested)
Fixed with `pickFile` in `icue_ui` (camera/gallery/document, quality 30), wired into all 8 sites; driver docs upload front/back/profile, vehicle docs collect number and dates first; iOS photo-library description and Android `CAMERA` added. `package_info_plus` was lowered to ^9 to resolve a `win32` conflict with `file_picker`.
`image_picker` and `file_picker` are not a dependency anywhere in the new workspace (old: `FilePickerUtils` + `FileUploadWidget`, used in 14 screens). The new buttons set hard-coded names and junk bytes:

| Screen | Evidence |
|---|---|
| Expense bill upload | `generic_expense_form_page.dart:238` sets `invoice_sample.jpg` with bytes `[0,1,2,3]` |
| Alcohol test photo | `alcohol_test_form_page.dart:242` sets `[1,2,3,4]` |
| Complaint photo | `add_complaint_page.dart:211` sets `[1,2,3]` |
| Self/End filling gauge photo | `self_filling_page.dart:185`, `end_filling_page.dart:266` set fixed names |
| Driver documents | `driver_docs_page.dart:151` only shows a snackbar "File picker opened" |
| Vehicle documents | `vehicle_docs_page.dart:196` only shows a snackbar |

Result: users cannot upload driver or vehicle documents at all. Expenses, alcohol tests and complaints either submit corrupt files or no real evidence. The service and provider upload code exists, but nothing feeds it.
Fix: add a picker to `icue_ui` (port `FileUploadWidget`) and wire the 8 call sites. Then restore `NSPhotoLibraryUsageDescription` (iOS) and the `CAMERA` permission (Android), both of which the old app declared.

### C2. Expense submit contract changed — MOSTLY FIXED (not device-tested)
Fixed: battery, tyres, maintenance, salary and fuel-station now send the old keys (including `FixedDate`, tyre `Type`, category/sub-category ids and names, salary `Mode`/`Name`, fuel `KM`/`FuelFilled`, odometer photo, fuel-price update). Dates now go as `MM/dd/yyyy` (the form was sending `dd/MM/yyyy`). Bill is required when status is not UnBilled. Service tests assert the keys.
**Self-filling session flow — now rebuilt (not device-tested):** start gauge → vehicle/storage list (filled ones disabled, End Filling guard) → per-vehicle fuel entry (`Mode: SelfFilling`) or loose-fuel entry per storage → confirmation (Add Another / End Filling) → end gauge. Also fixed: fuel types are `PETROL/DIESEL/LPG` (new code used `Diesel/Petrol/CNG`), start reading and gauge photo are optional again, `File` multipart key and `MM/dd/yyyy` `TransDate`, storages only when the server says `toFill`.
Old text of the gap (now resolved):
**(was missing) the self-filling session flow:** after "start gauge" the old app listed vehicles and fuel storages for the session, took a `Mode: SelfFilling` fuel entry per vehicle, and a loose-fuel entry per storage (`StorType/StorName/StorCap/PricePerLitre`), then End Filling. The new self-filling page just starts the session and pops. The provider already has `fetchFuelStorages` and `filledVehicleNumbers`; the vehicle/storage list screen and loose-fuel form still need building.

Original finding (kept for reference):
Six old per-type forms were collapsed into one `GenericExpenseFormPage` that invents new keys:

| Type | Old keys | New keys |
|---|---|---|
| Tyres | `Type`, `TyreName`, `TyreNo`, `Warranty`, `FixedDate` | `TyreBrand`, `TyreSize`, `Quantity` (no type, no warranty, no fixed date) |
| Battery | `BatteryName/Capacity/No`, `Warranty`, `FixedDate` | same names, but `FixedDate` dropped |
| Maintenance | `CategoryId`, `CategoryName`, `SubCategoryId`, `SubCategoryName`, "Other sub category", `FixedDate` | `CategoryId`, `SubCategory` only |
| Salary | `Name`, `Mode` | `StaffName`, `SalaryMonth` |
| Fuel station | `FuelFilled`, `KM`, odometer image | `Litres`, `Rate` |
| Loose fuel | `FuelFilled`, `PricePerLitre`, `StorName/StorCap/StorType` | storage details missing, `Litres`/`Rate` |

The old code was the working contract. Re-derive the payloads from the old `pages/manage_expense/**` files. The old loose-fuel flow (fuel storage selection) is also not reachable: `getFuelStorages` exists but the loose-fuel form is gone.

### C3. Admin app settings are not migrated — FIXED (not device-tested)
`AppSettings` lives in `features/auth` (`AuthProvider.appSettings`, loaded on dashboard and attendance page, cleared on logout/branch change). Attendance mode is honoured (manual-only skips the sheet, facial-only hides manual), photo upload is required when enabled for facial-photo sessions, and complaints accept up to `ComplaintImageLimit` photos (`Images` list, as before). Cleaning image flags were never used by the old app, so they are parsed but not applied.

Original finding:
`getAdminAppSettings` and the `AppSettings` model are gone (`CommonProvider`, called on dashboard and attendance). Behaviour lost:
- Attendance mode restriction (`MANUAL` / `FACIAL` / `BOTH`): the new mode sheet always offers every mode, so a school configured for manual only can still pick facial.
- `UploadAttendImages`: the old confirmation screen required photo upload only when enabled. New ignores the flag.
- `ComplaintImageLimit`, `CleaningImageLimit`, `IsUploadComplaintImage`, `IsUploadCleaningImage`: no limits are applied.

## High — FIXED (not device-tested)

- **H1.** Unknown routes now show a `ComingSoonPage` (`errorBuilder`) instead of the default go_router error. No `regularactivities` route: the new logbook page never links to it.
- **H2.** Deleted the unused `dashboard_feature_grid.dart` and `sub_actions_sheet.dart`.
- **H3.** Routes that need `extra` (driver info/docs, vehicle details/docs, vehicle options, expense forms, self-filling, complaint details, gate pass confirm, attendance sections/create/sdk) now redirect to their list or parent page when opened without it, instead of crashing on a failed cast. Query-parameter deep links (`?driverId=`, `?id=`) were not restored.
- **H4.** `getCountries` / `getChildPlaces` restored in `features/drivers`; the driver form uses Country and State dropdowns again (state list follows the country, edit mode preselects).

Original findings:

- **H1. Unknown or unhandled dashboard keys.** The old router had `errorBuilder` that showed `ComingSoon`, plus a `layout.regularactivities` route. The new router has neither, so any backend `routeState` the app does not know opens the default go_router error page. The dashboard still does `context.push('/${routeState}')`, so the backend keys must match `AppRoutes` exactly.
- **H2. Dead keyword-matching UI.** `dashboard_feature_grid.dart` and `sub_actions_sheet.dart` are never used. They route by guessing from title text and only cover some features. Delete them so nobody wires them in later.
- **H3. Driver info deep link.** Old `driver-info` took `?driverId=`. New requires `state.extra as Driver`, so it crashes if the route is opened without extra (restore, deep link, push-notification routing). Same pattern for vehicle details/docs (old used `?id=`).
- **H4. Country/state/city lookups.** `getCountries` and `getChildPlaces` are gone. The old add-driver form used dropdowns; the new one uses free-text fields.

## Medium — FIXED where marked (none device-tested)

- **Vehicle form:** added Dash Cam Id and Service Due Date; fuel types are `PETROL/DIESEL/LPG`; air condition sent as `AC`/`NON AC` (was `Yes`/`No`).
- **Date contract:** driver, vehicle, fire-extinguisher/first-aid, vehicle-document, gate-pass and attendance-check dates now go as `MM/dd/yyyy` like the old app (several were `dd/MM/yyyy` or `yyyy-MM-dd`). Reports already did.
- **Cleaning log:** the result parser read `failedCnt`/`failedData`; the backend sends `FailedCnt`/`FailedData` objects, so failures were never shown. Fixed, and each failed vehicle is listed with date and reason.
- **Complaint form:** duplicate custom category is rejected ("Category already exists").
- **Login:** OTP autofill restored (`otp_autofill`, Android user-consent, 5-digit code signs in automatically).
- **App:** version `1.1.0+11` and description set; Android `VIBRATE` added.
- **Not changed (judged equivalent or unused):** `DeleteDialog`/report filter/image viewer have per-screen equivalents; gate-pass filters exist under different labels; `lottie`, `cached_network_image`, `firebase_performance`, `timelines_plus`, `appinio_swiper`, `dotted_border` and the old animation/placeholder assets have no users in the new code; boot-completed receivers only matter for scheduled notifications, which the new app does not use. Android `FOREGROUND_SERVICE` not re-added — verify the face SDK on a device.

## Not a gap (confirmed)

- Old files never imported anywhere (dead in old): `vehicle_management/*` fuel price and fuel fill pages, `all_vehicles_list_page`, `announcement_warning_dialog`, `route_time_selection_page`, `keyboard_visibility_detector`, `student_face_enrollment_service`. So `updateFuelPrice`, `addVehicleFuelReading` and `sendTestPush` are not regressions.
- `ScreenTracker`, `RouteObserver` replaced by `AnalyticsService.instance.observer`.

## Suggested order

1. C1 pickers (blocks C2 and most uploads).
2. C2 expense payloads, matched against the old pages.
3. C3 app settings (`getAdminAppSettings` into a feature or `auth`, read by attendance and logbook).
4. H1 to H4, then the medium list.
5. Add a service-level test per fixed payload (assert on `FormData` keys), because the existing fake-service tests could not have caught C2.

Not verified: runtime behaviour on a device or emulator, and the Inventory/Library features (new, out of scope).
