# Inventory & Library – Progress Tracker

Source of truth for what is built. Read this first in every session, then the FRS
(`inventory-and-library-management-prd-frs.md`) and the architecture
(`inventory-library-technical-architecture.md`) sections for the phase at hand.

## How phases are worked

- One phase per session. All phases go on the **same branch**; there is no PR per phase.
- Each phase ends with its own commit(s), conventional style with scope, subject starting
  with the phase id, e.g. `feat(inventory): Inv-2 stock receiving, issuance, returns, transfers`.
  Find a phase's work with `git log --oneline --grep "Inv-2"`.
- A phase is done only when every item in its checklist is ticked and its tests pass.
  The session that finishes it ticks the boxes, fills in **Commit**, and logs any
  deviation below. If a phase changes the architecture, edit the architecture doc in the
  same commit.
- Update only this file's checkboxes, **Status**, **Commit** and the logs. Do not add
  narrative.

## Phase checklist template

Every phase delivers, where applicable: Cloud Functions, Security Rules, Firestore
indexes, rules tests, function tests (emulator), Dart models/services/providers in the
feature package, icueadmin screens (files under 500 lines), and DI registration.

## Environment prerequisites

- [ ] Firestore `(default)` database (Standard, Native, `asia-south1`) created in each project (prod has it; `icueadmin-dev` has not enabled the Firestore API yet)
- [x] Firebase project `icueadmin-dev` created, project ID `icueadmin-dev` (project number 483508933555); Android, iOS and web dev apps registered; aliases in `firebase/.firebaserc`
- [ ] Blaze plan enabled on both projects
- [ ] Node dev: `POST /v1.0/firebaseToken` live (signs with `icueadmin-dev` service account)
- [ ] Node prod: `POST /v1.0/firebaseToken` live
- [ ] Node endpoints confirmed (students by class/section, staff, departments, roles, academic years)
- [x] Dev/prod Android and iOS flavors with separate app IDs (both build)

## Phase 0 – Shared foundation

**Status:** done, not deployed · **Commit:** –

- [x] `firebase/` scaffold: `firebase.json`, `.firebaserc` (aliases `dev`, `prod`; default `dev`), emulators
- [x] Functions project (TypeScript, Node 22, `asia-south1`), shared wrapper: auth, access, validation, idempotency (`requests`), audit, counters, `uniqueKeys`, outbox
- [x] `session.sync`, `userAccess`, `config/rolePermissions` seed, `onRolePermissionsChange`
- [x] `outboxSend` and token dual-write (Node + `devices/{uid}/tokens`), logout cleanup
- [x] Rules and Storage rules base, rules-test harness
- [x] `icue_firebase`: auth, firestore, functions, storage; callable helper; paged query helper
- [x] `features/auth`: Firebase custom-token exchange and sign-out
- [x] `features/inventory` and `features/library` packages created, registered in root `workspace:` and `injection.dart`
- [x] `AGENTS.md` updated: features use Firestore/Functions directly, not `api_client`; points here
- [x] Parent app token exchange + token dual-write plan noted (applies when it joins the monorepo)

## Inventory

| Phase | Scope (FRS) | Status | Commit |
| --- | --- | --- | --- |
| Inv-1 | Categories, units, items, tracking methods, variants, stores (10.2–10.5) | not started | – |
| Inv-2 | Stock overview, receiving, issuance, returns, transfers, adjustments, damaged/expired/lost (10.6–10.12) | not started | – |
| Inv-3 | Purchase requests, approvals, vendors (10.13–10.14) | not started | – |
| Inv-4 | Quotations, comparison, purchase orders, PO PDF (10.15–10.16) | not started | – |
| Inv-5 | Goods receiving/inspection, vendor invoices (10.17–10.18) | not started | – |
| Inv-6 | Assets, assignment, maintenance (10.19–10.20) | not started | – |
| Inv-7 | Stock verification, reports, notifications, dashboard (10.1, 10.21–10.23) | not started | – |
| Inv-8 | Scanning, RFID, offline, import/export (§11, §14, §9) | not started | – |

Inventory definition of done: FRS §31.

## Library

| Phase | Scope (FRS) | Status | Commit |
| --- | --- | --- | --- |
| Lib-1 | Libraries, categories, catalogue (11.2–11.4) | not started | – |
| Lib-2 | Copies, accession numbers, acquisition, barcodes (11.5–11.6) | not started | – |
| Lib-3 | Memberships, borrowing policies (11.7–11.8) | not started | – |
| Lib-4 | Issue, return, renewal (11.9–11.11) | not started | – |
| Lib-5 | Reservations, waiting lists (11.12) | not started | – |
| Lib-6 | Fines, lost and damaged books (11.13–11.14) | not started | – |
| Lib-7 | Inter-library transfers, stock verification (11.15–11.16) | not started | – |
| Lib-8 | Reports, notifications, dashboard, import/export, parent view (11.1, 11.17–11.18) | not started | – |

Library definition of done: FRS §32.

## Per-phase checklists

Filled in at the start of each phase from the architecture doc (collections, callables,
rules, indexes, screens) so the list is concrete before coding begins.

### Phase 0

Collections (all under `schools/{sid}/` unless noted):

- [x] `config/rolePermissions` `{roles: {"<roleId>": [perm…]}}`, seeded by `firebase/functions/scripts/seed.ts --project dev --school <sid> --roles admin=<id>,principal=<id>,…` from the §3.1 default table
- [x] `userAccess/{uid}` `{perms, cmp, all, rol, pt, eid, wards, updatedAt}`
- [x] `requests/{requestId}` `{uid, fn, result, expireAt}`, TTL on `expireAt` (7 days) in `firestore.indexes.json`
- [x] `auditLogs/{auto}`, `counters/{type_fy}`, `uniqueKeys/{kind_value}`, `outbox/{eventKey}`, `notifications/{eventKey__uid}`
- [x] `devices/{uid}` (`mute`) and `devices/{uid}/tokens/{sha256(token)}` `{token, platform, app, updatedAt}` (root level)

Functions (`firebase/functions`, TypeScript, Node 22, `asia-south1`, zod):

- [x] `src/shared/callable.ts`: wrapper — auth, reject parents, load `userAccess`, permission + campus check, zod input, `requests` replay, one transaction with queued writes, audit helper
- [x] `src/shared/permissions.ts`: permission keys, default role table, `resolvePerms(rolePermissions, roleIds)`
- [x] `src/shared/keys.ts`: `fyOf(date)`, `nextNumber` (counters), `claimUniqueKey` (uniqueKeys)
- [x] `src/shared/outbox.ts`: `enqueue` (in-transaction, skips existing key) and `outboxSend` trigger (recipients by perm+campus / eid / wards, mute, `notifications` copy, `sendEach`, dead-token cleanup)
- [x] `src/session.ts`: `session-sync` callable, `onRolePermissionsChange` trigger
- [x] Tests (vitest): unit for `resolvePerms`, `fyOf`; emulator for wrapper (idempotent replay, rollback on failure, permission/campus/parent rejection), counters, uniqueKeys, outbox enqueue + recipient resolution, session-sync, onRolePermissionsChange recompute

Rules:

- [x] `firestore.rules`: helpers (§8.1), deny all client writes, own `userAccess` / `notifications` read, `config` read in school, `devices` owner read/write (token doc keys checked)
- [x] `storage.rules`: `schools/{sid}/{module}/…` read by school + module view permission; writes denied until `files.getUploadPath` exists
- [x] `firebase/rules-tests` (vitest + `@firebase/rules-unit-testing`): cross-school, cross-user, internal collections, client writes, devices, storage

Scaffold:

- [x] `firebase/firebase.json` (firestore, storage, functions, emulators: auth, firestore, functions, storage), `.firebaserc` (exists), `firestore.indexes.json`
- [x] Root `melos.scripts`: `firebase:test` (functions + rules tests on the emulator)

Flutter:

- [x] `icue_firebase`: `firebase_auth 7.0.0`, `cloud_firestore 7.0.0`, `cloud_functions 7.0.0`, `firebase_storage 14.0.0` (pinned with core 5.0.0); `callFunction` (region, `requestId`, retry with same id on `unavailable`/`deadline-exceeded`); `fetchPage` (cursor paging)
- [x] `features/auth`: `POST /v1.0/firebaseToken` → `signInWithCustomToken` → `session-sync`, after login and on restore when Firebase has no user (best-effort: never blocks Node login); token dual-write; Firestore token delete then `FirebaseAuth.signOut()` on logout
- [x] `features/inventory`, `features/library` (package `school_library`): package, barrel, micro module; root `workspace:`, app `pubspec.yaml`, `injection.dart`; `melos run gen`
- [x] `AGENTS.md`: Firebase rule (already present) + `firebase/` test commands
- [x] Parent app: exchange + token dual-write noted in Open items
- [x] `melos run lint` passes

## Decisions and deviations

Format: `date · phase · what changed from the architecture doc · why`.

- 2026-10-31 · 0 · Callables deploy as `<group>-<name>` (`session-sync`), not `session.sync` · Cloud Functions names cannot contain dots; every later callable follows the same pattern.
- 2026-10-31 · 0 · Outbox entries are read-then-set inside the business transaction (skip if the key exists), not `create` · a `create` on an existing key aborts the whole transaction, e.g. the second low-stock event of a day would fail the issue itself. Jobs outside transactions may still use `create`.
- 2026-10-31 · 0 · Firestore uses the `(default)` database, not a database named `icueadmin` · prod already has only `(default)`; Storage rules' `firestore.get()` reads `(default)`.
- 2026-10-31 · 0 · Storage writes are denied until `files-getUploadPath` (pending-upload registration) exists; arrives with the first upload (Inv-1 item images) · the design allows uploads only to registered paths.
- 2026-10-31 · 0 · `config.setRolePermissions` deferred to the permission-editor screen; until then the seed script (audited) is the only writer of `rolePermissions` · no caller yet.
- 2026-10-31 · 0 · `userAccess` also stores `rol`, `pt`, `eid`, `wards` · recompute on role-map change needs role IDs; outbox person-based recipients resolve by `eid`/`wards`.
- 2026-10-31 · 0 · Library Dart package is `school_library` (directory stays `features/library`) · `library` is a Dart reserved word.
- 2026-10-31 · 0 · Callable wrapper queues writes and applies them after the handler · Firestore transactions require all reads before writes; helpers (counters, uniqueKeys, outbox) read lazily. Ceiling: `nextNumber` gives one number per type per transaction.
- 2026-10-31 · 0 · Mute keys are read with `data().mute[category]`, never `get('mute.<category>')` · categories contain dots, which `get()` treats as nested paths.
- 2026-10-31 · 0 · Region is set in `src/region.ts`, imported first by every function file, not in `index.ts` · `setGlobalOptions` only affects functions created after it runs; imports are evaluated first, so callables landed in `us-central1` (found when running the emulator).
- 2026-10-31 · 0 · App emulator mode (`FIREBASE_EMULATOR` dart-define) mints an unsigned custom token locally (claims from the Node user) instead of calling `/v1.0/firebaseToken` · the Node endpoint is not live; ignored in release builds. Android debug manifest allows cleartext for `10.0.2.2`.
- 2026-10-31 · 0 · App emulators run as project `icueadmin-dev` (not `demo-icue`); automated tests still use `demo-icue` · mobile apps take the project ID from `google-services.json` and ignore a Dart override, so the app called `/icueadmin-dev/...` and the Functions emulator answered 404. Real FCM is skipped inside the emulator (`FUNCTIONS_EMULATOR`).
- 2026-10-31 · 0 · Emulator ports moved off the defaults (Firestore 8190, Auth 9109, Functions 5011, Storage 9209, UI 4010) · avoids clashing with other local emulator suites.

## Open items

- `icueadmin` Firebase config is on the `prod` flavor; `dev` uses the real `icueadmin-dev` config (Android `src/dev/google-services.json`, iOS `ios/config/dev/GoogleService-Info.plist`, `lib/firebase_options_dev.dart`). Still to do on the Firebase side: confirm `icueadmin-dev` has Firestore (Standard, Native, `asia-south1`), Blaze plan and Auth enabled; upload the APNs key; add the dev Android SHA-1/SHA-256 if needed.
- iOS now builds for both flavors (CocoaPods only, SPM off). To get there: Firebase plugins pinned to `firebase_core 5.0.0` / `firebase_analytics 13.0.0` / `firebase_crashlytics 6.0.0` / `firebase_messaging 17.0.0` (iOS SDK 12.19.0, the newest on CocoaPods trunk; `5.1.0` needs 12.19.3), `icue_face_sdk` on ML Kit 7, iOS minimum raised to 15.5, pods linked statically, and flavor xcconfigs fixed. Unpin Firebase once trunk has 12.19.3. Re-test face recognition on a device after the ML Kit 6→7 upgrade.
- `ios/Podfile.lock` is untracked; decide whether to commit it.
- Dev Node push credentials must be switched to `icueadmin-dev`; APNs key must be uploaded to `icueadmin-dev`.
- Node `POST /v1.0/firebaseToken`: the app assumes response `{ "token": "<custom token>" }`, uid `u_<userId>`, claims per architecture §2. Until it is live the exchange fails silently, and `registerPushToken` re-calls Node `updateRegTokens` on each launch (its "already registered" mark is set only after both writes).
- `icueadmin-dev`: enable Firestore (`(default)`, Standard, Native, `asia-south1`) and Blaze, then deploy rules, indexes (incl. `requests.expireAt` TTL) and functions (`firebase deploy --project dev` from `firebase/`), then seed: `npm --prefix firebase/functions run seed -- --project dev --school <sid> --roles admin=<id>,…` (needs Node role IDs per school).
- Parent app: when it joins the monorepo (or in its current repo before then) it needs the same custom-token exchange (uid `p_<parentId>`, `pt: parent`, `wards`), `session-sync`, and token dual-write to `devices/{uid}/tokens`.
