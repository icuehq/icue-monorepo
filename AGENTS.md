# iCue agent instructions

## Instruction maintenance (required for every repository change)

Update instructions only when a change introduces or invalidates a critical,
durable rule: security boundaries, shared business contracts, architectural
constraints, or essential build/release workflows. Routine UI changes, local
implementation details, class names, pagination settings and task history belong
in code or focused documentation, not `AGENTS.md`. Most changes need no update.

When an update is necessary, edit or remove the existing rule rather than append
an overlapping one. Keep it brief and verify scope, contradictions, paths and
commands. Do not add changelog entries.

Root `AGENTS.md` is canonical; `CLAUDE.md` imports it. Add scoped files only for
substantial durable differences; give each scoped `AGENTS.md` a sibling `CLAUDE.md`
containing `@AGENTS.md`, because Claude Code reads only `CLAUDE.md` files once one
exists. Add `.agents/rules` only when conditional loading adds value beyond this
shared hierarchy; each rule file needs `trigger` frontmatter or Antigravity drops it.
Essential behavior must not depend on machine-local settings or fallback filenames.

## Repository layout

Flutter/Dart Pub workspace (root `pubspec.yaml`) managed with Melos. Every package
must be listed under `workspace:` and use `resolution: workspace`.

- `apps/icueadmin` — the production admin app (go_router, provider, get_it). Screens live in `lib/features/<name>/`, routing in `lib/routing/`, DI bootstrap in `lib/di/`.
- `apps/super_admin` — Android super-admin app (student face enrollment/identification; password login via `AuthProvider.loginWithPassword`, `dev`/`prod` flavors). Mounts `features/face_enrollment`.
- `apps/impl` — scaffold only; do not build features here.
- `features/<name>` — one package per business domain (auth, drivers, vehicles, routes, announcements, expenses, logbook, reports, gatepass, tracking, drop_boarding, attendance, face_enrollment). Each has `models/`, `services/`, `providers/`, `di/` under `lib/src/` and exports its public API from `lib/<name>.dart`.
- `packages/api_client` — HTTP client, interceptors, errors, `ApiEnvironment`. `packages/local_storage`, `packages/icue_ui` (the single shared UI package: theme, fonts, widgets, tables, layouts, formatting helpers and UI services), `packages/icue_firebase`, `packages/icue_face_sdk` (native Android/iOS plugin).

## Architecture rules

- Dependencies point downward: apps → features → packages. Feature packages must never depend on an app. Feature-to-feature dependencies are limited to the existing `auth` and `routes` base features (no cycles); other shared code moves to `packages/`.
- Apps import a feature only through its barrel file, never `package:<feature>/src/...`.
- Feature packages own their full vertical: models, services, providers, **and UI** (`lib/src/ui/`) plus their routes (`<Feature>Routes` constants and a `<feature>Routes()` list of `RouteBase`s). A second app must be able to reuse a feature by depending on it and mounting its routes; nothing feature-specific may live in an app. Apps keep only entry points (route mounting, navigation, DI aggregation, theme) and app-specific widgets. Feature UI must not import from an app; every reusable widget lives in `packages/icue_ui`; a widget only one app uses stays in that app. Inventory and Library are migrated; other features still have UI in the app and move over when a second app needs them or when they are next reworked.
- Inventory and Library UI must work on desktop web as well as phones: mount routes inside `IcueModuleShell` (side navigation on wide screens), build lists with `IcueAdaptiveList` (table when wide, cards on phones) or `IcueAdaptiveCardList`, wrap page bodies in `IcueCenteredBody`, and open forms through `showFormPage`/`pushFormPage` (dialog when wide). All live in `packages/icue_ui` (`IcueBreakpoints`); do not add per-screen width checks. Other modules stay phone-first until migrated.
- The branch is the tenant: Firestore data lives under `orgs/{orgId}/zones/{zoneId}/branches/{branchId}/` and the token claims `orgId`, `zoneId`, `branchId` must match that path in rules, Storage and callables. Never share data across branches and never add a `campusId`; read branch collections only through `branchCollection()` (`icue_firebase`) or `CallableContext`.
- Dependency injection uses `get_it` + `injectable`. Each feature package declares a micro-package module; the app aggregates them in `lib/di/injection.dart`. A new feature package must be registered in the app's `injection.dart` and the root `workspace:` list.
- All HTTP goes through `api_client`; do not create ad-hoc `Dio`/`http` clients in features or apps.
- Inventory and Library (`features/inventory`, `features/library` — package `school_library`, since `library` is a Dart keyword) are Firebase-backed: reads use Firestore, writes go through Cloud Functions callables in `firebase/`, via `icue_firebase`, except code-keyed masters (inventory categories/units/stores/items/variants/vendors, library libraries/categories), inventory purchase requests/quotations/purchase orders (every step incl. receiving goods)/invoices, and Receive Stock, issue-request submit/approve, issuing stock, acknowledging an issue, returns, transfer requests, approvals, cancellations, dispatches, receipts, stock adjustments and unavailable stock (`StockWrites`: one client transaction each; no audit log or notifications), which are plain client Firestore writes guarded by the managing permission in `firestore.rules`. Library titles, copy edit/move/status, manual member block, borrowing policies and circulation (issue, return, renew, mark lost, report or resolve an incident: `LoanWrites`) are also plain client writes: each stamps `lastWrite` (who, action, reason, server time; enforced in `firestore.rules`) and the `audit*` triggers in `firebase/functions/src/library/audit.ts` write the audit log from it, and `notices.ts` sends the member's circulation notices. They do not use `api_client`; text search is web-only: the client queries the Enterprise `search` database directly with Firestore Pipelines (`searchMirror` in `icue_firebase`; `textSearchSupported` hides search boxes elsewhere; architecture §10). Firestore stores ERP people/departments as IDs only. Authority: `docs/inventory-library-technical-architecture.md`; build state and next phase: `docs/inventory-library-progress.md`. Work one phase per session on the shared branch, and update the progress doc at the end of each phase.
- Library Overview figures are counters in `libraryStats/overall` (per library under `libraries`) and `libraryStats/day_yyyy-MM-dd`, updated only by the audit triggers in `firebase/functions/src/library/stats.ts` when the data is written; never recompute them with scheduled jobs. A new figure goes into `deltas` there and `contracts/library.yaml`.
- Inventory and Library store every date and time as a Firestore `Timestamp`, never a string. A calendar day is midnight India time: write it with `dayTimestamp` (Dart, `icue_firebase`) / `dayTimestamp` (TS, `shared/dates.ts`), read it with `readDay`/`timestampDay`; callable inputs may still carry `yyyy-MM-dd`.
- No legacy support or backward compatibility anywhere: do not keep old shapes, deprecated aliases, migration fallbacks or compatibility shims, and do not guard against schema changes for existing data. Change code, APIs, contracts, Firestore schemas, document shapes and indexes directly and delete what they replace; callers are updated in the same change.
- Cloud Functions errors: throw `HttpsError` with a message a school user can act on (no field names, ids or internals); every function runs through `logged()` in `firebase/functions/src/shared/errors.ts`, the only place errors are logged. Plug in an external tracker with `setErrorReporter`, never ad-hoc `logger` calls in handlers.
- API base URL is selected at build time via `--dart-define=ENV=` (or `FLAVOR=`). Never hardcode environment URLs elsewhere. The Firebase project follows the same switch (`apps/icueadmin/lib/app_firebase_options.dart`, native configs in `android/app/src/<flavor>/` and `ios/config/<env>/`); never point a dev build at the prod project.

## Security boundaries

- Never commit secrets: signing keystores, `.p8`/`.pepk` keys, `passwords.txt`, `.env` files, API tokens. Never read, print, copy or reference their contents in output.
- `AuthKey_*.p8`, `keystore.jks`, `private_key.pepk`, `passwords.txt` at the repo root are currently tracked by git and must be removed from history/rotated by the owner; do not add similar files, and add new secret patterns to `.gitignore` first.
- Do not log tokens, OTPs, phone numbers or face/biometric data.

## Commands

Run from the repo root (`dart pub get` first; `melos bootstrap` is not needed with workspaces):

- `melos run lint` — `flutter analyze` on every package (must pass with no errors/warnings).
- `melos run format` / `melos run format:check` — Dart formatting.
- `melos run test` — tests in every package with a `test/` dir.
- `melos run firebase:test` — Cloud Functions (`firebase/functions`) and Security Rules (`firebase/rules-tests`) tests on the emulator. Firebase deploys default to `icueadmin-dev`; prod needs `--project prod`.
- `melos run emulators` — local Firebase emulators (run as `icueadmin-dev` because the mobile apps take their project ID from `google-services.json`; all services are emulated and `outboxSend` never sends real FCM there). Loads `firebase/.emulator-data` on start and saves it on Ctrl-C; `melos run emulators:reset` wipes it. Inventory permissions come from the Node `getActionsByRole` Ids sent as the `actionIds` token claim and mapped in `firebase/functions/src/shared/permissions.ts` (`docs/inventory-library-node-actions.md`); there is no per-school seed. To run the app against them use the `icueadmin [Dev + Emulators · Android|iOS]` launch configs (`--dart-define=FIREBASE_EMULATOR=<host>`; debug/profile builds only), which sign in with a locally built unsigned custom token instead of Node's `/v1.0/firebaseToken`.
- `melos run naming:check` — fails on abbreviated names, `inv`/`lib` prefixes and `u_`/`p_` uid prefixes in Inventory and Library code.
- `melos run gen` — `build_runner` (injectable DI config). Re-run after changing any `@injectable`/annotated class or adding a package module.
- `melos run gen:contracts` / `check:contracts` — Firestore collection names, status enums and document field keys shared by Flutter and Cloud Functions live in `contracts/*.yaml` and generate `packages/icue_firebase/lib/src/contracts.g.dart` and `firebase/functions/src/shared/contracts.ts`. The Dart view models of Inventory and Library (`models:` sections) generate `<file>.g.dart` next to the hand-written `<file>.dart`, which keeps only extensions, enums and helpers. Edit the YAML, never the outputs; new shared collections, statuses, field keys and model fields go there.

Never hand-edit `*.g.dart`, `*.module.dart`, `injection.config.dart` or other generated files.

## Code style

- Every public widget, theme or service class in `icue_ui` is prefixed `Icue` and lives in `lib/src/<group>/icue_<name>.dart` (e.g. `IcueTextField` in `icue_text_field.dart`); apps and features import only `package:icue_ui/icue_ui.dart`.
- Lints are defined in the root `analysis_options.yaml` (strict casts/inference/raw types, single quotes, trailing commas, `always_use_package_imports`, `prefer_final_locals`). Follow them; do not add `// ignore:` without a documented reason (`document_ignores` is on).
- Use package imports, never relative `../` imports.
- User-facing dates, times and money use Indian formats: `05/03/2025` (or `05 Mar 2025`), 12-hour `02:30 PM`, `₹1,23,456.00`. Format and parse them only through the `icue_ui` extensions (`toRupees`, `toNumericDate`, `toNumericDateTime`, `toDisplayDay`/`toDisplayTime` for stored strings, `toApiDate`/`todayIST` for stored values, `toDateOrNull`…) and pick dates with `IcueDateField`, which stores `yyyy-MM-dd` but shows the Indian form; do not inline `DateFormat`, `NumberFormat`, `toStringAsFixed` or `toIso8601String().substring`.
- Names follow `docs/naming-map.md`: full words (no `qty`, `cmp`, `inv`, `lib`…), dates end in `Date` and timestamps in `At`, locals say what they hold. `melos run naming:check` enforces it for Inventory and Library. A Firebase uid is the ERP ID as a string, with no prefix.

## Code structure & screen size limits

- Screen files must not exceed 500 lines of code.
- Extract sub-views, forms, cards, and modal components into separate widget files in dedicated widget directories to maintain modularity, readability, and testability.

## Testing guidelines

- Do not write or add widget tests. Focus testing on pure unit, service, model, and business logic.
- Tests live in the owning package's `test/` directory.

## Git

- Branch from `main`; use conventional commits with scope (`feat(auth): ...`, `fix(icue_ui): ...`).
- Don't commit `build/`, `.dart_tool/`, `.idea/` or generated platform secrets.

Final summaries must include either:

- `Instruction impact: reviewed; no instruction changes required.`
- `Instruction impact: updated <files> because <durable repository knowledge changed>.`
