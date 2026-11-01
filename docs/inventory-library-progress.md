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
- [ ] `search` database (Enterprise, Native, `asia-south1`) in each project, then `firebase/scripts/create-search-index.sh <project>` (creates the `invItems` and `libCatalogue` text indexes; dev has the database and the `invItems` index from a spike; prod has neither)
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
| Inv-1 | Categories, units, items, tracking methods, variants, stores (10.2–10.5) | done, not deployed | – (uncommitted) |
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
| Lib-1 | Libraries, categories, catalogue (11.2–11.4) | done, not deployed | – (uncommitted) |
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

### Inv-1

Collections: `invCategories`, `invUnits` (doc ID = code), `invItems` (+ `variants`), `invStores`.

Functions (`firebase/functions/src/inventory/masters.ts`):

- [x] `inv-category-upsert`, `inv-category-setStatus`, `inv-unit-upsert`, `inv-item-upsert`, `inv-item-setStatus`, `inv-variant-upsert`, `inv-store-upsert`, `inv-store-setStatus`
- [x] `inv-seedDefaults` (FRS default categories and units, idempotent)
- [x] Unique codes via `uniqueKeys`; inactive category/subcategory rejected for new use; stock unit/tracking locked once `invMovements` exist
- [x] Item search: `syncItemSearch` trigger mirrors items into the `search` database, `inv-item-search` callable (`inventory/search.ts`, `runQuery` in `shared/callable.ts`)
- [x] Tests: `test/masters.test.ts`, `test/search.test.ts` (emulator; text search itself is emulated by a whole-word scan)

Rules and indexes:

- [x] `firestore.rules`: reads for categories/units/items/variants (`inv.items.view`), stores (`inv.stock.view` or `inv.settings`, campus-scoped)
- [x] `firestore.indexes.json`: `invItems` (`categoryId`, `name`); `search.rules` denies all client access to the `search` database
- [x] Rules tests for all of the above

Flutter:

- [x] `features/inventory`: models, `InventoryService` (reads + callables), `InventoryProvider`, DI, model tests
- [x] `icueadmin` screens under `features/inventory/` (home, categories, units, stores, items, item form, item details with variants); routes `/layout.inventory/...`; dashboard card opens it when Node's action `routeState` contains `inventory`
- [x] `melos run lint` passes; functions and rules tests pass

### Lib-1

Collections: `libLibraries`, `libCategories`, `libCatalogue` (title-level; copies arrive in Lib-2).

Functions (`firebase/functions/src/library/`):

- [x] `lib-library-upsert`, `lib-library-setStatus` (`lib.settings`); `lib-category-upsert`, `lib-category-setStatus`, `lib-catalogue-upsert`, `lib-catalogue-setStatus`, `lib-seedDefaults` (`lib.catalogue.manage`)
- [x] Unique library/category codes via `uniqueKeys`; campus fixed after creation; one level of subcategories; inactive category rejected for new use
- [x] Catalogue duplicate detection: `dupKey` = ISBN-13 (ISBN-10 converted) or normalized title + first author + edition + publisher + year, claimed in `uniqueKeys` and moved on edit; ISBN check digits validated; books without ISBN supported
- [x] Catalogue search: `syncCatalogueSearch` mirrors into the `search` database, `lib-catalogue-search` (whole-word title/subtitle/author/publisher/keywords, category filter; a query that is a valid ISBN is an exact lookup on `(default)`)
- [x] Shared master helpers moved to `shared/masters.ts` (used by inventory and library); `Ctx.delete` added
- [x] Tests: `test/library.test.ts` (emulator; text search itself is emulated by a whole-word scan)

Rules and indexes:

- [x] `firestore.rules`: reads for libraries/categories/catalogue with `lib.catalogue.view`
- [x] `firestore.indexes.json`: `libCatalogue` (`categoryId`, `title`); `create-search-index.sh` also creates the `libCatalogue` text index
- [x] Rules tests

Flutter:

- [x] `features/library` (`school_library`): models, `LibraryService`, `LibraryProvider`, DI, model tests
- [x] `icueadmin` screens under `features/library/` (home, libraries, categories, catalogue, book form, book details); routes `/layout.library/...`; dashboard card opens it when Node's action `routeState` contains `library`
- [x] `melos run lint` passes; functions and rules tests pass

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
- 2026-10-31 · Inv-1 · Item image upload and `files-getUploadPath` deferred (`imagePath` is stored as null) · no item screen needs it yet; arrives with the first mandatory upload (Inv-5 attachments) or earlier on request.
- 2026-10-31 · Inv-1 · Codes (category, item, SKU, store) cannot change after creation · their `uniqueKeys` entry is never released; renaming is a new record plus deactivating the old one.
- 2026-10-31 · Inv-1 · Preferred vendor is not set from the item form · `invVendors` arrives in Inv-3.
- 2026-10-31 · Inv-1 · Store storekeepers are entered as ERP staff IDs, campuses shown as "Campus <id>" · the Node staff and branch-name endpoints are not confirmed yet.
- 2026-11-01 · Inv-1 · Item search uses the Enterprise `search` database (trigger mirror + `inv-item-search`) instead of `searchTokens` · whole-word matching only, no prefix/type-ahead (verified on dev); search and category filter combine. Emulator falls back to a whole-word scan, so the real text-search path is untested locally.
- 2026-10-31 · Inv-1 · Seeding defaults is the `inv-seedDefaults` callable (button on empty categories/units screens), not a script · works per project without credentials and is covered by emulator tests.
- 2026-10-31 · Inv-1 · Item "stock across locations / history" (FRS 10.3) and import/export wait for Inv-2 balances and Inv-8 · nothing to show or import yet.
- 2026-11-01 · Lib-1 · Added `lib-category-setStatus` (not in the architecture's callable list) · categories carry a status (FRS 11.3) and inactive ones are rejected for new titles, so they need a way to be deactivated.
- 2026-11-01 · Lib-1 · Book cover upload deferred (`coverPath` stored as null) and "view physical copies" on the book page waits for Lib-2 · same reason as Inv-1 item images; no copies exist yet. Catalogue import/export waits for Lib-8.
- 2026-11-01 · Lib-1 · A duplicate title is a hard `already-exists` error, not a warning · the identity key (ISBN-13, or title/author/edition/publisher/year) is claimed in `uniqueKeys`; editing the identity moves the key. Two genuinely different books with identical details must differ in edition or year.
- 2026-11-01 · Lib-1 · Libraries and catalogue are readable by anyone with `lib.catalogue.view` (no campus filter) · the catalogue is school-wide and teachers need to see where books are; writes stay campus-scoped through the callable wrapper.
- 2026-11-01 · Lib-1 · Librarian staff are entered as ERP staff IDs, campuses shown as "Campus <id>" · same as Inv-1 stores; Node staff and branch-name endpoints are not confirmed.

## Open items

- `icueadmin` Firebase config is on the `prod` flavor; `dev` uses the real `icueadmin-dev` config (Android `src/dev/google-services.json`, iOS `ios/config/dev/GoogleService-Info.plist`, `lib/firebase_options_dev.dart`). Still to do on the Firebase side: confirm `icueadmin-dev` has Firestore (Standard, Native, `asia-south1`), Blaze plan and Auth enabled; upload the APNs key; add the dev Android SHA-1/SHA-256 if needed.
- iOS now builds for both flavors (CocoaPods only, SPM off). To get there: Firebase plugins pinned to `firebase_core 5.0.0` / `firebase_analytics 13.0.0` / `firebase_crashlytics 6.0.0` / `firebase_messaging 17.0.0` (iOS SDK 12.19.0, the newest on CocoaPods trunk; `5.1.0` needs 12.19.3), `icue_face_sdk` on ML Kit 7, iOS minimum raised to 15.5, pods linked statically, and flavor xcconfigs fixed. Unpin Firebase once trunk has 12.19.3. Re-test face recognition on a device after the ML Kit 6→7 upgrade.
- `ios/Podfile.lock` is untracked; decide whether to commit it.
- Dev Node push credentials must be switched to `icueadmin-dev`; APNs key must be uploaded to `icueadmin-dev`.
- Node `POST /v1.0/firebaseToken`: the app assumes response `{ "token": "<custom token>" }`, uid `u_<userId>`, claims per architecture §2. Until it is live the exchange fails silently, and `registerPushToken` re-calls Node `updateRegTokens` on each launch (its "already registered" mark is set only after both writes).
- `icueadmin-dev`: enable Firestore (`(default)`, Standard, Native, `asia-south1`) and Blaze, then deploy rules, indexes (incl. `requests.expireAt` TTL) and functions (`firebase deploy --project dev` from `firebase/`), then seed: `npm --prefix firebase/functions run seed -- --project dev --school <sid> --roles admin=<id>,…` (needs Node role IDs per school).
- Parent app: when it joins the monorepo (or in its current repo before then) it needs the same custom-token exchange (uid `p_<parentId>`, `pt: parent`, `wards`), `session-sync`, and token dual-write to `devices/{uid}/tokens`.
