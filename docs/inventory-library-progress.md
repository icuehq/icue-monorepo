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
- [ ] `search` database (Enterprise, Native, `asia-south1`) in each project, then `firebase/scripts/create-search-index.sh <project>` (creates the `inventoryItems` and `libraryCatalogue` text indexes; dev has the database and the `inventoryItems` index from a spike; prod has neither)
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
| Inv-1 | Categories, units, items, tracking methods, variants, stores (10.2–10.5) | done, not deployed | – (committed) |
| Inv-2 | Stock overview, receiving, issuance, returns, transfers, adjustments, damaged/expired/lost (10.6–10.12) | done, not deployed | – (committed) |
| Inv-3 | Purchase requests, approvals, vendors (10.13–10.14) | done, not deployed | – (committed) |
| Inv-4 | Quotations, comparison, purchase orders, PO PDF (10.15–10.16) | done, not deployed | – |
| Inv-5 | Goods receiving/inspection, vendor invoices (10.17–10.18) | done, not deployed | – |
| Inv-6 | Assets, assignment, maintenance (10.19–10.20) | done, not deployed | – |
| Inv-7 | Reports, notifications, dashboard (10.1, 10.21–10.23) | done, not deployed | – |
| Inv-8 | Scanning, RFID, offline, import/export (§11, §14, §9) | done, not deployed | – |

Inventory definition of done: FRS §31.

## Library

| Phase | Scope (FRS) | Status | Commit |
| --- | --- | --- | --- |
| Lib-1 | Libraries, categories, catalogue (11.2–11.4) | done, not deployed | – (committed) |
| Lib-2 | Copies, accession numbers, book, barcodes (11.5–11.6) | done, not deployed | d3f48e8 |
| Lib-3 | Memberships, borrowing policies (11.7–11.8) | done, not deployed | abb3f9d |
| Lib-4 | Issue, return, renewal (11.9–11.11) | done, not deployed | 04fe97f |
| Lib-5 | Reservations, waiting lists (11.12) | done, not deployed | 0ab4b80 |
| Lib-6 | Fines, lost and damaged books (11.13–11.14) | done, not deployed | 44c1383 |
| Lib-7 | Inter-library transfers, stock verification (11.15–11.16) | in progress (backend done; UI pending) | – |
| Lib-8 | Reports, notifications, dashboard, import/export, parent view (11.1, 11.17–11.18) | done, not deployed | – |

Library definition of done: FRS §32.

## Per-phase checklists

Filled in at the start of each phase from the architecture doc (collections, callables,
rules, indexes, screens) so the list is concrete before coding begins.

### Phase 0

Collections (all under `schools/{schoolId}/` unless noted):

- [x] `config/rolePermissions` `{roles: {"<roleId>": [permission…]}}`, seeded by `firebase/functions/scripts/seed.ts --project dev --school <schoolId> --roles admin=<id>,principal=<id>,…` from the §3.1 default table
- [x] `userAccess/{uid}` `{permissions, campusIds, all, roleIds, personType, personErpId, wardStudentIds, updatedAt}`
- [x] `requests/{requestId}` `{uid, fn, result, expireAt}`, TTL on `expireAt` (7 days) in `firestore.indexes.json`
- [x] `auditLogs/{auto}`, `counters/{type_fy}`, `uniqueKeys/{kind_value}`, `outbox/{eventKey}`, `notifications/{eventKey__uid}`
- [x] `devices/{uid}` (`mute`) and `devices/{uid}/tokens/{sha256(token)}` `{token, platform, app, updatedAt}` (root level)

Functions (`firebase/functions`, TypeScript, Node 22, `asia-south1`, zod):

- [x] `src/shared/callable.ts`: wrapper — auth, reject parents, load `userAccess`, permission + campus check, zod input, `requests` replay, one transaction with queued writes, audit helper
- [x] `src/shared/permissions.ts`: permission keys, default role table, `resolvePerms(rolePermissions, roleIds)`
- [x] `src/shared/keys.ts`: `fyOf(date)`, `nextNumber` (counters), `claimUniqueKey` (uniqueKeys)
- [x] `src/shared/outbox.ts`: `enqueue` (in-transaction, skips existing key) and `outboxSend` trigger (recipients by permission+campus / personErpId / wardStudentIds, mute, `notifications` copy, `sendEach`, dead-token cleanup)
- [x] `src/session.ts`: `session-sync` callable, `onRolePermissionsChange` trigger
- [x] Tests (vitest): unit for `resolvePerms`, `fyOf`; emulator for wrapper (idempotent replay, rollback on failure, permission/campus/parent rejection), counters, uniqueKeys, outbox enqueue + recipient resolution, session-sync, onRolePermissionsChange recompute

Rules:

- [x] `firestore.rules`: helpers (§8.1), deny all client writes, own `userAccess` / `notifications` read, `config` read in school, `devices` owner read/write (token doc keys checked)
- [x] `storage.rules`: `schools/{schoolId}/{module}/…` read by school + module view permission; writes denied until `files.getUploadPath` exists
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

Collections: `inventoryCategories`, `inventoryUnits` (doc ID = code), `inventoryItems` (+ `variants`), `inventoryStores`.

Functions (`firebase/functions/src/inventory/masters.ts`):

- [x] `inventory-category-upsert`, `inventory-category-setStatus`, `inventory-unit-upsert`, `inventory-item-upsert`, `inventory-item-setStatus`, `inventory-variant-upsert`, `inventory-store-upsert`, `inventory-store-setStatus`
- [x] `inventory-seedDefaults` (FRS default categories and units, idempotent)
- [x] Unique codes via `uniqueKeys`; inactive category/subcategory rejected for new use; stock unit/tracking locked once `inventoryMovements` exist
- [x] Item search: `syncItemSearch` trigger mirrors items into the `search` database, `inventory-item-search` callable (`inventory/search.ts`, `runQuery` in `shared/callable.ts`)
- [x] Tests: `test/masters.test.ts`, `test/search.test.ts` (emulator; text search itself is emulated by a whole-word scan)

Rules and indexes:

- [x] `firestore.rules`: reads for categories/units/items/variants (`inventory.items.view`), stores (`inventory.stock.view` or `inventory.settings`, campus-scoped)
- [x] `firestore.indexes.json`: `inventoryItems` (`categoryId`, `name`); `search.rules` denies all client access to the `search` database
- [x] Rules tests for all of the above

Flutter:

- [x] `features/inventory`: models, `InventoryService` (reads + callables), `InventoryProvider`, DI, model tests
- [x] `icueadmin` screens under `features/inventory/` (home, categories, units, stores, items, item form, item details with variants); routes `/layout.inventory/...`; dashboard card opens it when Node's action `routeState` contains `inventory`
- [x] `melos run lint` passes; functions and rules tests pass

### Inv-2

Collections: `inventoryBalances`, `inventoryMovements`, `inventoryReceipts`, `inventoryIssueRequests`, `inventoryIssues`, `inventoryReturns`, `inventoryTransfers`, `inventoryAdjustments`, `inventoryUnavailableStock`.

Functions (`firebase/functions/src/inventory/stock.ts` ledger helper, `stock-ops.ts` callables):

- [x] `inventory-receipt-confirm`; `inventory-issueRequest-submit` / `-decide`; `inventory-issue-create` / `-acknowledge`; `inventory-return-create`; `inventory-transfer-request` / `-dispatch` / `-receive`; `inventory-adjustment-create`; `inventory-unavailable-report` / `-resolve`
- [x] One balance per store × item × variant × batch; append-only `inventoryMovements`; never below zero; expired batches never issued; FEFO allocation; weighted-average cost; low-stock outbox event
- [x] Returns bounded by outstanding issued quantity, damaged goes to the register; transfers track in-transit, partial receipt, discrepancy
- [x] Tests: `test/stock.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: stock collections read with `inventory.stock.view` on the campus; issue requests also by their requester; transfers by either campus; requesters (`inventory.issue.request`) may read items and stores; stores readable school-wide
- [x] `firestore.indexes.json`: balances, movements, documents by campus + `createdAt`, requests, transfers, unavailable
- [x] Rules tests

Flutter:

- [x] `features/inventory`: `inv_stock.dart` models, `StockService`, `StockProvider`, DI, model tests
- [x] `icueadmin` screens under `features/inventory/stock/` (stock overview with movement history / adjust / report, receive, issue requests with approve / issue / acknowledge / return, transfers, damaged-expired register); routes `/layout.inventory/{stock,requests,transfers,unavailable}`
- [x] `melos run lint` passes (inventory, icueadmin); functions and rules tests pass

### Inv-3

Collections: `inventoryVendors`, `inventoryPurchaseRequests` (approval history kept in `history`).

Functions (`firebase/functions/src/inventory/procurement.ts`):

- [x] `inventory-vendor-upsert`, `inventory-vendor-setStatus` (`inventory.vendors.manage`); unique code via `uniqueKeys`; deactivated vendors rejected as an item's preferred vendor
- [x] `inventory-purchaseRequest-save` (create / edit draft or returned request, optional `submit`), `inventory-purchaseRequest-submit`, `inventory-purchaseRequest-decide` (approve / reject / revise; comment required unless approving), `inventory-purchaseRequest-cancel` (request is kept; blocked once quantity is ordered)
- [x] Numbering `PR/<financialYear>/<seq>`; only the requester edits, submits and cancels; campus scoped; outbox events to approvers (on submit), requester (on decision) and procurement (on approval)
- [x] Tests: `test/procurement.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: vendors readable with `inventory.vendors.manage` or `inventory.procure.operate`; purchase requests by their requester, or by approvers / procurement on the campus; `inventory.purchaseRequest.request` may browse items
- [x] `firestore.indexes.json`: purchase requests by campus + status + `createdAt`, by `createdBy` + `createdAt`
- [x] Rules tests

Flutter:

- [x] `features/inventory`: `inv_procurement.dart` models, `ProcurementService`, `ProcurementProvider`, DI, model tests
- [x] `icueadmin` screens under `features/inventory/procurement/` (vendors with form, purchase requests with filter / detail / approve actions, request form); routes `/layout.inventory/{vendors,purchase-requests}`
- [x] `melos run lint` passes; functions and rules tests pass

### Inv-4

Collections: `inventoryQuotations`, `inventoryPurchaseOrders` (+ `revisions` subcollection).

Client writes in `ProcurementWrites` (`inventory.procure.operate`; the callables in `orders.ts` were removed):

- [x] `inventory-quotation-save` (draft or final; lines must be approved-request lines, quantity within the request, totals computed; numbering `QT/<financialYear>/<seq>`), `inventory-quotation-select` (final, unexpired, reason required; one selected per request, blocked while a live PO uses the previous one)
- [x] `inventory-purchaseOrder-save` (now a client write in `ProcurementWrites`, no callable or audit log; draft against an approved / partially ordered request; with a quotation the vendor and unit prices come from it; numbering `PO/<financialYear>/<seq>`), `inventory-purchaseOrder-issue` (now a client transaction in `ProcurementWrites`; reserves `quantityOrdered` on the request, sets `partially_ordered` / `ordered`), `inventory-purchaseOrder-revise` (header and unit prices; previous version kept in `revisions`; resets acknowledgement), `inventory-purchaseOrder-acknowledge`, `inventory-purchaseOrder-cancel` (releases ordered quantity), `inventory-purchaseOrder-close` (reason unless fully received)
- [x] Tests: none for the client writes (the `orders.test.ts` callable tests were removed); `seedPurchaseOrder` / `issuePurchaseOrder` in `test/fixtures.ts` set up orders for the receiving and asset tests

Rules and indexes:

- [x] `firestore.rules`: quotations, POs and revisions readable with `inventory.procure.operate` on the campus (POs also by delivery campus)
- [x] `firestore.indexes.json`: POs by campus + status + `createdAt`
- [x] Rules tests

Flutter:

- [x] `features/inventory`: `inv_orders.dart` models, `ProcurementService` / `ProcurementProvider` extended, model tests
- [x] `icueadmin` screens under `features/inventory/procurement/` (quotations comparison + select, quotation form, purchase orders list / detail / actions, PO form, PO PDF via `pdf` + `printing`); routes `/layout.inventory/{quotations,quotations/form,purchase-orders,purchase-orders/form}`; opened from the purchase request sheet and the Inventory home
- [x] `melos run lint` passes (inventory, icueadmin); functions and rules tests pass

### Inv-5

Collections: `inventoryReceipts` (PO deliveries, `source: purchase_order`), `inventoryInvoices`.

Functions (`firebase/functions/src/inventory/receiving.ts`):

- [x] `inventory-purchaseOrder-receive` (now a client transaction in `StockWrites`, no audit log; `inventory.stock.operate`, store on the PO's delivery campus): one delivery per call, accepted ≤ still due per line, accepted enters stock at the PO unit price (batch rules as Inv-2), rejected is recorded only; PO becomes `partially_received` / `fully_received`; request becomes `completed` when its last live PO is fully received; cancelled / closed / draft / fully received POs reject
- [x] `inventory-invoice-save` (against a non-draft, non-cancelled PO; vendor from the PO; `receiptIds` must belong to it; invoice number unique per vendor via `uniqueKeys`; editable while unpaid), `inventory-invoice-setPayment` (cumulative paid amount ≤ total; `unpaid` / `partially_paid` / `paid`), `inventory-invoice-cancel` (unpaid only, releases the number) — all `inventory.procure.operate`, campus scoped
- [x] Tests: `test/receiving.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: POs also readable with `inventory.stock.operate` on the delivery campus; invoices with `inventory.procure.operate` on the campus
- [x] `firestore.indexes.json`: POs by delivery campus + status, invoices by campus + `createdAt` / `purchaseOrderId` / `paymentStatus`
- [x] Rules tests

Flutter:

- [x] `features/inventory`: `inv_receiving.dart` models (`InvGrn`, `InvInvoice`), `ProcurementService` / `ProcurementProvider` extended, model tests
- [x] `icueadmin` screens under `features/inventory/procurement/` (receive-goods page, deliveries list and "Record invoice" on the PO sheet, invoices list + sheet with payment update / cancel); routes `/layout.inventory/{purchase-orders/receive,invoices}`; Inventory home shows Purchase orders to receiving staff and a Vendor invoices tile
- [x] `melos run lint` passes (inventory, icueadmin); functions and rules tests pass

### Inv-6

Collections: `inventoryAssets` (+ `history` subcollection), `inventoryAssetAssignments`, `inventoryMaintenanceJobs`.

Functions (`firebase/functions/src/inventory/assets.ts`, all `inventory.assets.manage`, campus scoped):

- [x] `inventory-asset-register` (asset-tracked item, active store; ID `AST/<financialYear>/<seq>` claimed in `uniqueKeys`; with a PO the vendor and price come from the order and units are capped at the line's accepted quantity), `inventory-asset-assign` (only `available`), `inventory-asset-transfer` (custodian to custodian; closes and keeps the previous assignment), `inventory-asset-return` (damaged return makes it `damaged`), `inventory-asset-setCondition` (also `available` / `damaged` / `lost`; lost closes an active assignment), `inventory-asset-retire` (`retired`, then `disposed`; never from assigned or in maintenance)
- [x] `inventory-maintenance-save` (one live request per asset; asset becomes `under_maintenance`), `inventory-maintenance-setStatus` (status drives asset status: `in_progress` → `under_repair`, completed / cancelled restore it; completing needs the repair cost; parts drawn from a store as `issue` movements, needs `inventory.stock.operate`)
- [x] `inventory-purchaseOrder-receive` accepts asset-tracked lines: counted on the order, no stock
- [x] Tests: `test/assets.test.ts`, `test/receiving.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: assets, history and maintenance with `inventory.assets.view` on the campus; assignments also to the assignee (`personErpId`)
- [x] `firestore.indexes.json`: assets and maintenance by campus (+ status) + `createdAt`, maintenance by asset, assignments by asset / person + `assignedAt`
- [x] Rules tests

Flutter:

- [x] `features/inventory`: `inv_assets.dart` models, `AssetsService` / `AssetsProvider`, DI, model tests
- [x] `icueadmin` screens under `features/inventory/assets/` (register form, asset list + sheet with custody history, timeline, actions and QR label via `pdf` + `printing`; maintenance list + sheet, report/edit and status/parts forms); routes `/layout.inventory/{assets,assets/form,maintenance}`; Assets tile on the Inventory home
- [x] `melos run lint` passes (inventory, icueadmin); functions and rules tests pass

### Inv-7

Collections: `inventoryBalances.earliestExpiryDate` (expiry of usable stock, null when empty).

Functions (`firebase/functions/src/inventory/daily.ts`):

- [x] `dailyInventory` (06:00 IST, every school; `runDailyInventory` is the testable core): expired batches to `quantityExpired` with `expire` movements and an `inventoryUnavailableStock` entry, near-expiry digest per store (weekly), expired stock, overdue PO delivery (weekly), warranty ending (30 days), maintenance due (7 days)
- [x] Out-of-stock event from `Stock.finish`; `earliestExpiryDate` maintained there; new permission `inventory.adjustment.approve` (admin, principal, inventory manager)

Rules and indexes:

- [x] `firestore.rules`: `inventory.reports.view` reads every report collection on the campus and vendors
- [x] `firestore.indexes.json`: balances by campus (+ store) + `earliestExpiryDate`, PRs / POs / issue requests / unavailable / movements by campus + `createdAt`, assignments by campus + `assignedAt`, POs by status + `expectedDate` (daily job)
- [x] Rules tests

Flutter:

- [x] `features/inventory`: `inv_insights.dart` (`toCsv`, the `ReportDef`s, dashboard stat list), `InsightsService` / `InsightsProvider`, DI, model tests
- [x] `icueadmin` screens under `features/inventory/insights/` (dashboard with store filter, report catalogue + report view with date range, status, search, totals, CSV copy and PDF); routes `/layout.inventory/{dashboard,reports,reports/view}`; Dashboard and Reports tiles on the Inventory home
- [x] `melos run lint` passes (inventory, icueadmin); functions and rules tests pass

### Inv-8

Functions (`firebase/functions/src/inventory/`):

- [x] `inventory-asset-setRfid` (`inventory.assets.manage`; tag unique per school via `uniqueKeys` `inventoryRfid`, moving or clearing releases the old one)
- [x] `inventory-import-run` (`import.ts`; plain callable: each CSV row runs the single-record callable with request ID `<importId>-<row>`, so every rule and permission applies; types categories, stores, items, vendors; 200 rows per call)
- [x] Tests: `test/import.test.ts` (emulator)

Rules:

- [x] Rules tests

Flutter:

- [x] `features/inventory`: `parseCsv` + `importColumns`, `InvAsset.rfidTag`, `AssetsService.findByCode` (asset ID or RFID tag), `InsightsService.saveCounts` (direct line writes), model tests
- [x] `icueadmin`: `widgets/scan_field.dart` (keyboard-wedge field + camera via `mobile_scanner`), scan/search on the asset list, RFID sheet, Import page (`/layout.inventory/import`, Import tile); `NSCameraUsageDescription` added
- [x] `melos run lint` passes (inventory, icueadmin); functions and rules tests pass

### Lib-1

Collections: `libraries`, `libraryCategories`, `libraryCatalogue` (title-level; copies arrive in Lib-2).

Functions (`firebase/functions/src/library/`):

- [x] `library-library-upsert`, `library-library-setStatus` (`library.settings`); `library-category-upsert`, `library-category-setStatus`, `library-catalogue-upsert`, `library-catalogue-setStatus` (`library.catalogue`)
- [x] Libraries and library categories have no code (see the 2026-11-06 decisions); campus fixed after creation; one level of subcategories; inactive category rejected for new use
- [x] Catalogue duplicate detection: `identityKey` = ISBN-13 (ISBN-10 converted) or normalized title + first author + edition + publisher + year, claimed in `uniqueKeys` and moved on edit; ISBN check digits validated; books without ISBN supported
- [x] Catalogue search: `syncCatalogueSearch` mirrors into the `search` database, `library-catalogue-search` (whole-word title/subtitle/author/publisher/keywords, category filter; a query that is a valid ISBN is an exact lookup on `(default)`)
- [x] Shared master helpers moved to `shared/masters.ts` (used by inventory and library); `Ctx.delete` added
- [x] Tests: `test/library.test.ts` (emulator; text search itself is emulated by a whole-word scan)

Rules and indexes:

- [x] `firestore.rules`: reads for libraries/categories/catalogue with `library.catalogue`
- [x] `firestore.indexes.json`: `libraryCatalogue` (`categoryId`, `title`); `create-search-index.sh` also creates the `libraryCatalogue` text index
- [x] Rules tests

Flutter:

- [x] `features/library` (`school_library`): models, `LibraryService`, `LibraryProvider`, DI, model tests
- [x] `icueadmin` screens under `features/library/` (home, libraries, categories, catalogue, book form, book details); routes `/layout.Library/...`; dashboard card opens it when Node's action `routeState` contains `library`
- [x] `melos run lint` passes; functions and rules tests pass

### Lib-2

Collections: `libraryCopies` (doc ID = barcode), `libraryBooks`.

Functions (`firebase/functions/src/library/copies.ts`, all `library.catalogue`, campus scoped through the library / copy):

- [x] `library-book-create` (purchase, donation or opening stock; 1–100 copies per call; purchase needs a price, donation may be 0; active title and library only; numbering `ACQ/<financialYear>/<seq>`; creates one copy per unit; each copy's document ID is its required, scanned barcode, so a repeated barcode fails with `already-exists`)
- [x] `library-copy-update` (shelf, condition, remarks, RFID tag unique per school via `uniqueKeys` `libraryRfid`), `library-copy-move` (available copies only, to another active library on an allowed campus), `library-copy-setStatus` (available / under maintenance / damaged / lost / withdrawn; reason for damaged, lost, withdrawn; lost and withdrawn are final; issued, reserved, in-transit untouchable)
- [x] Tests: `test/copies.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: `libraryCopies` readable with `library.catalogue`; `libraryBooks` with `library.catalogue`
- [x] Indexes: none needed (copies by `catalogueId`, barcode and RFID tag are single-field queries; books by `createdAt`)
- [x] Rules tests

Flutter:

- [x] `features/library`: `lib_copies.dart` models (`LibCopy`, `LibBook`), `LibraryService` / `LibraryProvider` extended (copies of a title, find by accession / barcode / RFID, books, writes), model test
- [x] `icueadmin` screens under `features/library/` (copies section on the book page with add-copies sheet and label printing, copy sheet with edit / move / status; the standalone Copies & books page was removed (copies live on the book page)); labels are Code 128 barcodes on a 50×25 mm thermal label (`labelFormat` in `copy_labels.dart`) via `pdf` + `printing`, printable per copy, for all copies of a title, and right after copies are added
- [x] `melos run lint` passes (library, icueadmin); functions and rules tests pass

### Lib-3

Collections: `libraryMembers` (doc ID `<student|teacher>_<personErpId>`), `libraryBorrowingPolicies` (doc ID `<libraryId>_<student|teacher>`). Members are created on first use, not enrolled (see the 2026-11-06 decision).

Functions (`firebase/functions/src/library/members.ts`):

- [x] Borrowing policies are client writes (`LibraryWrites.savePolicy/setPolicyActive`, was `library-policy-upsert/setStatus`; several per library and person type, each for chosen categories or the catch-all (no overlap among active ones); library campus scoped; fine needs an amount; categories must exist; inactive library only for existing policies)
- [x] `library-member-setBlocked` (`library.circulation.operate`); the member record itself is written by issue and reserve (`writeBorrower`)
- [x] Tests: `test/members.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: `libraryMembers` and `libraryBorrowingPolicies` readable with `library.members.view`
- [x] `firestore.indexes.json`: `libraryMembers` by `memberType` + `personErpId`
- [x] Rules tests

Flutter:

- [x] `features/library`: `lib_members.dart` models (`LibPolicy`, `LibMember`), `LibraryService` / `LibraryProvider` extended (policies, paged members, exact lookup, writes), model test
- [x] `icueadmin` screens under `features/library/` (Members page: list of people who have borrowed, with block and unblock; Borrowing policies page with edit sheet); routes `/layout.Library/{members,policies}`; Members and Borrowing policies tiles
- [x] `melos run lint` passes (library, icueadmin); functions and rules tests pass

### Lib-4

Collection: `libraryLoans` (`personErpId` is the flat owner field for rules). Counters `ISS`, `RET`.

Functions (`firebase/functions/src/library/loans.ts`, all `library.circulation.operate`, campus scoped through the copy / loan):

- [x] Loan issue, now a client transaction (`LoanWrites.issue`, was `library-loan-issue`; member active, not blocked, within dates, library access; policy for the book's category (category, parent, catch-all); limit counted per policy; copy `available`; policy frozen as `policySnapshot`)
- [x] Loan return, now `LoanWrites.returnLoan` (only an active loan; `good` → `available`, `damaged` → `damaged`; overdue days stored; `activeLoans` decremented)
- [x] Loan renew, now `LoanWrites.renew` (snapshot `maxRenewals`, `loanDays`; overdue loans refused)
- [x] Tests: `test/loans.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: `libraryLoans` readable by circulation staff on the campus or the borrower / parent (`own()`)
- [x] `firestore.indexes.json`: `libraryLoans` by `status`+`dueDate`, and `memberId` / `barcode` / `personErpId` + `issuedDate`
- [x] Rules test

Flutter:

- [x] `features/library`: `lib_loans.dart` (`LibLoan`), service / provider (paged active loans, `activeLoanOf`, issue / return / renew), model test
- [x] `icueadmin`: Circulation page (member + scan to issue, scan to return or renew, active loans list) and loan sheet; route `/layout.Library/circulation`; Circulation tile
- [x] Lint passes (library, icueadmin); functions and rules tests pass

### Lib-5

Collection: `libraryReservations` (`personErpId` is the flat owner field for rules). Counter `RSV`.

Functions (`firebase/functions/src/library/reservations.ts`, all `library.circulation.operate`, campus scoped through the library):

- [x] Reservation create, now `LoanWrites.reserve` (only when no shelf copy; eligible member; active policy allows reserve; category not restricted; one live reservation per title/member)
- [x] Reservation cancel, now `LoanWrites.cancelReservation` (waiting or ready; held copy released to next in queue)
- [x] Waiting list integrated into `createBook`, `loanReturn`, `loanRenew`, `copySetStatus` (copies freeing up serve the waiting queue)
- [x] Tests: `test/reservations.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: `libraryReservations` readable by circulation staff on the campus or the member / parent (`own()`)
- [x] `firestore.indexes.json`: `libraryReservations` composite indexes (status + catalogueId + libraryId + createdAt, status + createdAt, personErpId + createdAt)
- [x] Rules test in `rules-tests/rules.test.js`

Flutter:

- [x] `features/library`: `lib_reservations.dart` (`LibReservation`), service / provider (paged reservations, create / cancel reservation), model test
- [x] `icueadmin`: Reservations page (status filter: waiting/ready/fulfilled/cancelled/expired, queue position, cancel reservation with confirmation) and reservation sheet; Book details reserve button; route `/layout.Library/reservations`; Reservations tile
- [x] Lint passes (library, icueadmin); functions build and rules tests pass

### Lib-6

Collections: `libraryFines` (`{loanId__type}` or `inc_{incidentId}__{type}`), `libraryIncidents`. Counters `FIN`, `INC`.

Functions (`firebase/functions/src/library/fines.ts`, `incidents.ts`, `loans.ts`):

- [x] Fine waive, now `LoanWrites.waiveFine` (waives partial or full fine; unblocks member when balance is settled; `library.fines.waive`)
- [x] Fine payment, now `LoanWrites.recordFinePayment` (records fine payment reference; unblocks member when balance is settled; `library.circulation.operate`)
- [x] Incident report, now `LoanWrites.reportIncident` (reports lost or damaged copy; updates copy status; assesses penalty/fine if member responsible; `library.circulation.operate`)
- [x] Incident resolve, now `LoanWrites.resolveIncident` (resolves incident: repaired releases copy to shelf/reservation queue, replaced, written off marks withdrawn; assesses charge; `library.circulation.operate`)
- [x] Mark lost, now `LoanWrites.markLost` (marks loan and copy lost, assesses replacement charge, blocks member, creates incident; `library.circulation.operate`)
- [x] Overdue fine and damaged incident integrated into `loanReturn` (calculates overdue fine per loan snapshot policy, creates fine doc, blocks member; damaged return creates open incident)
- [x] Tests: `test/fines.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: `libraryFines` readable by circulation staff or fine waivers on campus, or borrower / parent (`own()`). `libraryIncidents` readable by circulation staff on campus or member (`own()`)
- [x] `firestore.indexes.json`: `libraryFines` composite indexes (status + createdAt, campusId + status + createdAt, personErpId + createdAt, memberId + status), `libraryIncidents` composite indexes (status + createdAt, campusId + status + createdAt, personErpId + createdAt, copyId + createdAt)
- [x] Rules test in `rules-tests/rules.test.js`

Flutter:

- [x] `features/library`: `lib_fines.dart` (`LibFine`), `lib_incidents.dart` (`LibIncident`), service and provider methods (fines, incidents, waiveFine, setFinePayment, reportIncident, resolveIncident, markLoanLost), unit tests
- [x] `icueadmin`: Fines page (status filter: outstanding/partially_paid/paid/waived/all) and fine sheet (waive and record payment actions); Incidents page (status filter: open/resolved/all), incident sheet (resolve action) and incident report sheet; loan sheet `Mark lost` action; routes `/layout.Library/fines` and `/layout.Library/incidents`; home page tiles for Fines & Penalties and Lost & Damaged
- [x] Lint passes (library, icueadmin); functions build and tests pass

### Lib-7

Collections: `libraryTransfers` (counter `LTR`), `libraryVerifications` (counter `LVR`).

Functions (`firebase/functions/src/library/transfers.ts`, `verification.ts`):

- [x] `library-transfer-request` / `-approve` (`library.settings`) / `-dispatch` (copies become `in_transit`) / `-receive` (per copy, partial receipts; arrived copies serve the destination waiting list first)
- [x] `library-verification-create` / `-scan` / `-submit` / `-approve` (`library.settings`; `lost` and `move` corrections)
- [x] Tests: `test/transfers.test.ts` (emulator)

Rules and indexes:

- [x] `firestore.rules`: both collections readable by `library.catalogue` on the campus (transfers: source or destination campus); `firestore.indexes.json`: status + createdAt for each; rules test

Flutter:

- [ ] `features/library`: transfers and stock verifications models, service/provider methods, unit tests
- [ ] `school_library`: Transfers page and Stock verification page; routes `/layout.Library/{transfers,verification}`; home tiles
- [x] Lint passes (library, icueadmin); functions build, 118 emulator tests and 33 rules tests pass

### Lib-8

Functions (`firebase/functions/src/library/`):

- [x] `notify.ts` (member recipients: a student's parents via `wardStudentIds`, a teacher via `personErpId`); outbox events added to `loanIssue`, `loanReturn` (returned, overdue fine, damaged), `loanMarkLost` (fine, lost), `incidentReport`, transfer request / dispatch / receive and verification submit; `post` moved to `shared/outbox.ts` (used by both daily jobs)
- [x] `dailyLibrary` (07:00 IST, every school; `runDailyLibrary` is the testable core): due soon (2 days), overdue (daily), membership ending (7 days), reservation hold ending (1 day)
- [x] `library-import-run` (`import.ts`; same design as `inventory-import-run`: each CSV row runs the single-record callable with request ID `<importId>-<row>`; types catalogue, copies (opening-stock books by ISBN-13), members; 200 rows per call)
- [x] Tests: `test/library-insights.test.ts` (emulator); `reservations.test.ts` outbox assertion narrowed to `rsv-ready`

Rules and indexes:

- [x] `firestore.rules`: new `library.reports.view` reads every report collection on the campus; parents read the catalogue (libraries, categories, titles) and their ward's `libraryMembers` record; loans, reservations, fines and incidents were already readable by `own()`
- [x] `firestore.indexes.json`: campus (+ library) scoped composites for the dashboard and report queries; `libraryMembers` status + end for the daily job
- [x] Rules tests (35 pass)

Flutter:

- [x] `features/library`: `lib_insights.dart` (15 `LibReportDef`s, dashboard stats, import columns, `libraryDay`), `LibraryService.dashboard/report/titlesByIds`, provider methods, `ModuleAccess.all`, model test
- [x] `icueadmin` (`features/library/insights/`): dashboard with library filter, report catalogue and report view (library, date range, status, search, totals, CSV copy, PDF), import page; routes `/layout.Library/{dashboard,reports,reports/view,import}`; Dashboard, Reports and Import tiles
- [x] `melos run lint`, `melos run test`, format check pass; 121 functions tests and 35 rules tests pass (run on a separate emulator port)

## Decisions and deviations

Format: `date · phase · what changed from the architecture doc · why`.

- 2026-10-31 · 0 · Callables deploy as `<group>-<name>` (`session-sync`), not `session.sync` · Cloud Functions names cannot contain dots; every later callable follows the same pattern.
- 2026-10-31 · 0 · Outbox entries are read-then-set inside the business transaction (skip if the key exists), not `create` · a `create` on an existing key aborts the whole transaction, e.g. the second low-stock event of a day would fail the issue itself. Jobs outside transactions may still use `create`.
- 2026-10-31 · 0 · Firestore uses the `(default)` database, not a database named `icueadmin` · prod already has only `(default)`; Storage rules' `firestore.get()` reads `(default)`.
- 2026-10-31 · 0 · Storage writes are denied until `files-getUploadPath` (pending-upload registration) exists; arrives with the first upload (Inv-1 item images) · the design allows uploads only to registered paths.
- 2026-10-31 · 0 · `config.setRolePermissions` deferred to the permission-editor screen; until then the seed script (audited) is the only writer of `rolePermissions` · no caller yet.
- 2026-10-31 · 0 · `userAccess` also stores `roleIds`, `personType`, `personErpId`, `wardStudentIds` · recompute on role-map change needs role IDs; outbox person-based recipients resolve by `personErpId`/`wardStudentIds`.
- 2026-10-31 · 0 · Library Dart package is `school_library` (directory stays `features/library`) · `library` is a Dart reserved word.
- 2026-10-31 · 0 · Callable wrapper queues writes and applies them after the handler · Firestore transactions require all reads before writes; helpers (counters, uniqueKeys, outbox) read lazily. Ceiling: `nextNumber` gives one number per type per transaction.
- 2026-10-31 · 0 · Mute keys are read with `data().mute[category]`, never `get('mute.<category>')` · categories contain dots, which `get()` treats as nested paths.
- 2026-10-31 · 0 · Region is set in `src/region.ts`, imported first by every function file, not in `index.ts` · `setGlobalOptions` only affects functions created after it runs; imports are evaluated first, so callables landed in `us-central1` (found when running the emulator).
- 2026-10-31 · 0 · App emulator mode (`FIREBASE_EMULATOR` dart-define) mints an unsigned custom token locally (claims from the Node user) instead of calling `/v1.0/firebaseToken` · the Node endpoint is not live; ignored in release builds. Android debug manifest allows cleartext for `10.0.2.2`.
- 2026-10-31 · 0 · App emulators run as project `icueadmin-dev` (not `demo-icue`); automated tests still use `demo-icue` · mobile apps take the project ID from `google-services.json` and ignore a Dart override, so the app called `/icueadmin-dev/...` and the Functions emulator answered 404. Real FCM is skipped inside the emulator (`FUNCTIONS_EMULATOR`).
- 2026-10-31 · 0 · Emulator ports moved off the defaults (Firestore 8190, Auth 9109, Functions 5011, Storage 9209, UI 4010) · avoids clashing with other local emulator suites.
- 2026-10-31 · Inv-1 · Item image upload and `files-getUploadPath` deferred (`imagePath` is stored as null) · no item screen needs it yet; arrives with the first mandatory upload (Inv-5 attachments) or earlier on request.
- 2026-10-31 · Inv-1 · Codes (category, item, SKU, store) cannot change after creation · their `uniqueKeys` entry is never released; renaming is a new record plus deactivating the old one.
- 2026-10-31 · Inv-1 · Preferred vendor is not set from the item form · `inventoryVendors` arrives in Inv-3.
- 2026-10-31 · Inv-1 · Store storekeepers are entered as ERP staff IDs, campuses shown as "Campus <id>" · the Node staff and branch-name endpoints are not confirmed yet.
- 2026-11-01 · Inv-1 · Item search uses the Enterprise `search` database (trigger mirror + `inventory-item-search`) instead of `searchTokens` · whole-word matching only, no prefix/type-ahead (verified on dev); search and category filter combine. Emulator falls back to a whole-word scan, so the real text-search path is untested locally.
- 2026-10-31 · Inv-1 · Seeding defaults is the `inventory-seedDefaults` callable (button on empty categories/units screens), not a script · works per project without credentials and is covered by emulator tests.
- 2026-10-31 · Inv-1 · Item "stock across locations / history" (FRS 10.3) and import/export wait for Inv-2 balances and Inv-8 · nothing to show or import yet.
- 2026-11-01 · Lib-1 · Added `library-category-setStatus` (not in the architecture's callable list) · categories carry a status (FRS 11.3) and inactive ones are rejected for new titles, so they need a way to be deactivated.
- 2026-11-01 · Lib-1 · Book cover upload deferred (`coverPath` stored as null) and "view physical copies" on the book page waits for Lib-2 · same reason as Inv-1 item images; no copies exist yet. Catalogue import/export waits for Lib-8.
- 2026-11-01 · Lib-1 · A duplicate title is a hard `already-exists` error, not a warning · the identity key (ISBN-13, or title/author/edition/publisher/year) is claimed in `uniqueKeys`; editing the identity moves the key. Two genuinely different books with identical details must differ in edition or year.
- 2026-11-01 · Lib-1 · Libraries and catalogue are readable by anyone with `library.catalogue` (no campus filter) · the catalogue is school-wide and teachers need to see where books are; writes stay campus-scoped through the callable wrapper.
- 2026-11-01 · Lib-1 · Librarian staff are entered as ERP staff IDs, campuses shown as "Campus <id>" · same as Inv-1 stores; Node staff and branch-name endpoints are not confirmed.
- 2026-11-01 · Inv-2 · Receiving sources exclude purchase orders; PO-linked receiving with quantity validation arrives in Inv-5 · POs do not exist yet. Attachments on receipts are stored as an empty list until uploads exist.
- 2026-11-01 · Inv-2 · Asset-tracked items are rejected by every stock callable · individual assets, serials and assignment belong to Inv-6.
- 2026-11-01 · Inv-2 · Adjustments apply immediately; no `inventory.adjustment.approve` yet, and damage/expiry are reported under `inventory-unavailable-report` instead of adjustment reasons · count-driven approval arrives with Inv-7 verification; `approval` is stored as null.
- 2026-11-01 · Inv-2 · The `dailyInventory` job that moves expired batches to `quantityExpired` is not built; expired stock is reported manually and is never issuable regardless · the issue check does not depend on the job; the job arrives with Inv-7 notifications.
- 2026-11-01 · Inv-2 · Issue requests cannot be cancelled and transfers cannot be cancelled before dispatch · not in the callable list; add when users ask.
- 2026-11-01 · Inv-2 · `isBelowReorderLevel` compares one balance's available quantity with the item's reorder level (per batch, not per item) · ceiling; Inv-7 dashboards can aggregate per item.
- 2026-11-01 · Inv-2 · `inventoryStores` is readable school-wide (no campus filter) · a transfer must name a destination store on another campus; writes stay campus-scoped.
- 2026-11-01 · Inv-2 · Recipients, returning persons and requesters are entered as ERP IDs; receipts, returns and adjustments have no list screen (their movements show in stock history) · Node person pickers are not confirmed; documents are retained in Firestore.
- 2026-11-01 · Inv-3 · Vendor purchase history, quotations, POs and invoices (FRS 10.14 "view") wait for Inv-4/5 · those records do not exist yet. Vendor documents are stored as an empty list until uploads exist; vendors are listed and filtered client-side (no `search` mirror) · the list is small.
- 2026-11-01 · Inv-3 · Requesting department and request attachments are not captured in the app (`departmentId` is accepted by `inventory-purchaseRequest-save`, `attachments` stored empty) · no department picker (Node endpoint unconfirmed) and no uploads yet.
- 2026-11-01 · Inv-3 · The item form does not set the preferred vendor yet; `inventory-item-upsert` validates it when sent · deferred from Inv-1, add a vendor dropdown when asked.
- 2026-11-01 · Inv-3 · An approver may decide a request they raised themselves; there is no second approval level · matches the single-level issue approval; add a self-approval block if the school asks.
- 2026-11-01 · Inv-3 · Purchase requests may include asset-tracked items (unlike stock callables) · assets are bought like anything else; only stock movements reject them. Statuses `partially_ordered`, `ordered`, `completed` are set by Inv-4/5 (`quantityOrdered` per line).
- 2026-11-01 · Inv-4 · Quotation attachments are stored empty and the quotation "number" is the system number with the vendor's own number in `vendorRef` · no uploads yet.
- 2026-11-01 · Inv-4 · A PO covers one request (`purchaseRequestIds` holds one ID) and may be raised without a quotation (vendor and prices entered) · FRS requires only an approved request; multi-request POs wait for a need.
- 2026-11-01 · Inv-4 · Post-issue revisions change header terms and unit prices only; quantities are fixed (cancel and re-issue) · quantity changes would have to re-balance the request's `quantityOrdered`.
- 2026-11-01 · Inv-4 · Closing a PO short does not release its unreceived quantity on the request · decide with Inv-5 receiving. Receiving history, `partially_received` / `fully_received` and `quantityReceived` updates arrive with Inv-5; the PO screen already shows received vs ordered.
- 2026-11-01 · Inv-4 · Purchase orders and quotations are readable only by `inventory.procure.operate`; approvers and receiving staff get read access in Inv-5 if needed.
- 2026-11-01 · Inv-4 · PO PDF is built in the app with `pdf` + `printing` (`layoutPdf`: preview, print, share, save); no school letterhead until the ERP school profile is available.
- 2026-11-01 · Inv-5 · Receiving uses `inventory-purchaseOrder-receive`, not `inventory-receipt-confirm` with a PO source · PO validation and PO status updates need their own callable; both write `inventoryReceipts` and share the `GRN` numbering.
- 2026-11-01 · Inv-5 · Rejected goods are recorded on the receipt and PO line only (no `inventoryUnavailableStock` entry, no stock) · they never entered the store; returns to the vendor are not tracked. Stock cost is the PO unit price, with no discount/tax/delivery apportioned.
- 2026-11-01 · Inv-5 · Asset-tracked PO lines are received (counted on the order, no stock) from Inv-6 · stock callables still reject assets; units are registered individually.
- 2026-11-01 · Inv-5 · Closing a PO short still leaves its unreceived quantity counted as ordered on the request (carried from Inv-4) · decide with the first user complaint.
- 2026-11-01 · Inv-5 · `overdue` payment status is derived in the app from `dueDate` (unpaid or partially paid), not stored · no scheduled job to flip it; invoice and receipt attachments and the Finance payment reference input are deferred until uploads exist (payment reference is accepted by the callable and shown when present).
- 2026-11-01 · Inv-5 · Invoice amounts are entered as subtotal / tax / discount totals, not per line, and are not checked against the PO or receipts · traceability is the PO and receipt references; add three-way matching if Finance asks. Vendor invoices tile reuses the purchase-orders artwork.
- 2026-11-01 · Inv-6 · Custodians are entered as ERP IDs (shown "staff #id") and acknowledgement is recorded by the assigner at handover · no person/department pickers (Node endpoints not confirmed); no custodian-side acknowledge callable.
- 2026-11-01 · Inv-6 · Transfer moves custody between people / departments only · moving an unassigned asset to another store or campus is not built; add when asked.
- 2026-11-01 · Inv-6 · An asset in maintenance keeps its custodian and cannot be returned, transferred or retired until the job ends · maintenance status drives asset status (architecture §6). Maintenance attachments are stored empty (no uploads yet) and the technician is free text.
- 2026-11-01 · Inv-6 · Maintenance parts are drawn once per status update and never reversed; part cost is not added to the repair cost · keep the repair cost as the all-in figure.
- 2026-11-01 · Inv-6 · QR label (asset ID) is built in the app with `pdf` + `printing`; barcode scanning, `rfidTag` and `imagePath` stay null until Inv-8. Warranty / next-service notifications arrive with Inv-7 (`dailyInventory`). The Assets tile reuses the stock artwork.
- 2026-11-01 · Inv-6 · Teachers with `inventory.assets.view` see the whole campus register; a "my assets" view is not built (rules already let an assignee read their own assignments).
- 2026-11-01 · Inv-7 · Dashboard has store filter only (campus follows the store); category, date range and academic year filters are not built · balances carry no category and counts are live aggregation queries. Low / out-of-stock count balance lines (item × batch), not items; expiring is the next 30 days. "Pending approvals" = pending purchase requests + issue requests; "pending goods receipts" = orders issued / acknowledged with nothing received.
- 2026-11-01 · Inv-7 · Reports are one generic screen over the campus-scoped collection: server filters are date range (`createdAt`; expiry uses the expiry date) and status, other filters (item, store, vendor, person, type) are the search box over the loaded rows (500 max) · avoids a composite index per filter. Export is CSV copied to the clipboard and PDF through the print dialog; no Excel file. Vendors and recipients show IDs where documents store no name. Item-wise stock is a per-balance view, not a date-pinned snapshot.
- 2026-11-01 · Inv-7 · Notifications: "inventory manager" and "storekeeper" are everyone with `inventory.stock.operate` on the campus, "asset manager" `inventory.assets.manage`, "procurement officer" `inventory.procure.operate` · permissions, not role names. Near-expiry and overdue-PO reminders repeat weekly, warranty once per end date, service-due once per date. The 60-day token cleanup from §7.2 is not built.
- 2026-11-01 · Inv-8 · Import is `inventory-import-run` over CSV rows pasted in the app, not `import.validate` / `import.commit` + `importWorker` + xlsx · no staged preview, import history or overwrite; existing codes are rejected per row. Types: categories, stores, items (by `categoryCode`), vendors; opening stock, assets and library types are not importable. Re-run safety comes from the per-row request ID.
- 2026-11-01 · Inv-8 · Scanning resolves item code (counting) and asset ID / RFID tag (asset list); items have no separate barcode field, and library copies wait for Lib-2. Fixed RFID gate readers and RFID inventory-by-reader are not built (tags are read as keyboard input). Camera scanning is untested on a device (no native build run).
- 2026-11-01 · Inv-8 · Export is unchanged from Inv-7 (report CSV / PDF); list-level CSV/XLSX export and downloadable import templates are not built (the import page copies the header row).
- 2026-11-08 · Lib-2 · A copy's document ID is its barcode · uniqueness is structural and one identifier is enough for labels, scanning and loans.
- 2026-11-10 · Lib-2 · Barcodes are issued by the system by default: `library-book-create` without `barcodes` assigns `LB000001`… from `counters/libraryCopy` (per school, no financial year); a toggle still accepts scanned barcodes for pre-labelled books, which may not use the `LB` + digits shape · schools without labelled books need nothing to scan, and generated and scanned codes never collide. Copies can be added to an existing title from its page.
- 2026-11-01 · Lib-2 · Book types are purchase, donation and opening stock; transfer arrives with Lib-7 · transfers create no book record. Book attachments are not stored (no uploads) and a new book starts from a book's page, not from the Copies page.
- 2026-11-01 · Lib-2 · `library-copy-setStatus` is not in the architecture's callable list; damage, loss and withdrawal can be set by hand here, while incidents and fines arrive with Lib-6 · FRS 11.5 needs these statuses now.
- 2026-11-01 · Lib-2 · Copy issue and transfer history are not shown on the copy sheet · loans arrive with Lib-4, transfers with Lib-7; changes are in `auditLogs`.
- 2026-11-01 · Lib-2 · Copies are readable school-wide with `library.catalogue` (like the catalogue) so teachers can see where a book is; writes are campus scoped. Camera scanning of labels uses the Inventory `IcueScanField` and is untested on a device (no native build run).
- 2026-11-01 · Lib-3 · Members and policies are readable school-wide with `library.members.view` (librarian, principal, admin); writes are campus scoped through the library · teachers do not see the member list.
- 2026-11-01 · Lib-4 · Return stores `overdueDays` but raises no fine · fines, lost/damaged incidents and the damage penalty arrive with Lib-6, which reads the loan's frozen `policySnapshot`. A damaged return sets the copy `damaged` and creates no incident yet.
- 2026-11-01 · Lib-4 · Renewal does not check reservations, and a returned copy goes straight to `available` · reservations and the hold queue arrive with Lib-5. A copy `reserved` for the member cannot be issued until then.
- 2026-11-01 · Lib-4 · `library.loan.markLost` is not built (Lib-6). Renewal extends from the later of the due date and today by the loan's snapshot `loanDays`; inactive or blocked members cannot renew. Issue/return numbers are `ISS/…` and `RET/…`; no printable issue slip yet.
- 2026-11-01 · Lib-4 · The circulation screen lists active loans only (earliest due first); borrowing history on the member sheet (FRS 11.7) is not shown yet. Camera scanning is untested on a device (no native build run).
- 2026-11-01 · Lib-5 · Reservations can only be placed when all copies are unavailable (issued, reserved, under maintenance or damaged); available copies must be issued directly · prevents members queuing when a book is ready on the shelf. Queue position is computed as index in the created-ordered waiting list, not stored.
- 2026-11-01 · Lib-6 · Unblocking member is evaluated when fines are settled (waived in full or paid in full) · if no other outstanding fines exist for the member, the member is unblocked immediately in the same transaction.
- 2026-11-01 · Lib-6 · Incident resolution 'repaired' triggers reservation queue release · if reservations are waiting for that title, the repaired copy fulfills the next waiting reservation rather than going idle on the shelf.
- 2026-11-01 · Lib-6 · `library-incident-report` refuses a copy that is on loan or held, or that already has an open incident; `repaired` is only for damaged copies; `dismissed` (no fault, or the lost book turned up) sends a damaged or lost copy back through the reservation queue/shelf; the charge cannot be lowered on resolve (waive the fine instead) · closes orphaned-loan and duplicate-incident holes found in review. Damage on a held copy cannot be reported until the hold is released.
- 2026-11-01 · Lib-7 · Transfer approval needs `library.settings`, request/dispatch/receive need `library.catalogue`; there is no reject or cancel, and a copy not received stays `in_transit` (no lost-in-transit closure) · keeps the workflow to the four FRS steps; use `library-copy-setStatus` after investigation once that path is needed. Copies are only locked at dispatch, so an approved transfer fails at dispatch if a copy left the shelf.
- 2026-11-01 · Lib-7 · Verification keeps copy IDs as arrays on the session doc (expected, onLoanCopyIds, scanned, missing, unexpected), capped at 2000 copies per session, and scans go through `library-verification-scan` (not client-written lines) · no offline counting; scope by shelf for bigger libraries. Issued copies are listed apart and not expected; a scanned copy that is not expected, or is shown as issued, is `unexpected`.
- 2026-11-01 · Lib-7 · Approving a verification can mark missing copies `lost` or `move` available unexpected copies into the library; missing copies left alone are stored as `investigate`. No rejection step; destination/source staff notifications arrive with Lib-8.
- 2026-11-01 · Lib-8 · Dashboard filters are library and member type (the member tiles) only; no category or date-range filter · every tile is a current-state count, so a date range has nothing to filter, and copies carry no category ID. Dashboard counts and indexes are unverified against a real project (emulators do not enforce indexes).
- 2026-11-08 · Lib-8 · Reports are four loan reports (issues by date range, monthly issue & return, student-wise, staff-wise), computed client-side over up to 5000 loans of the period; the date-range list shows 500 rows · same ceiling as Inventory reports. Member names come from the loan's `memberName`.
- 2026-11-01 · Lib-8 · Import takes pasted CSV (catalogue, copies, members), not an uploaded file or a staged preview, and rejects existing titles and members instead of updating them · existing accession numbers cannot be imported (numbers come from one counter), so copies arrive as opening-stock books by ISBN-13. List export is the report CSV / PDF; list-level XLSX export is not built.
- 2026-11-01 · Lib-8 · Issue, return and fine notices go to the member's parents or teacher when they happen; overdue repeats daily, due-soon / membership / hold-ending once per loan, member or reservation · deterministic outbox keys. Notifications respect the per-category mute (`library.loan`, `library.fine`, `library.reservation`, `library.member`, `library.incident`, `library.transfer`, `library.verification`); no preferences screen.
- 2026-11-01 · Lib-8 · Parent view is rules only: parents read their ward's loans, reservations, fines, incidents and membership, and browse the catalogue; the parent app screens arrive when it joins the monorepo · there is no parent UI here to build. Parents cannot see copies or availability.
- 2026-11-02 · cleanup · Removed the callables that client Firestore writes replaced: inventory category/unit/item/variant/store/vendor upserts and setStatus, library library/category upserts and setStatus, and purchase request, quotation and invoice callables. The importer keeps the category, store, item and vendor upsert handlers internally; deployed functions no longer include them. Tests seed those documents directly (`firebase/functions/test/fixtures.ts`). No legacy-client support.
- 2026-11-03 · audit fixes · Workflow changes: only accepted PO units fill an order (rejected ones leave it open); closing a short PO releases the remainder to its request; a short final inventory transfer receipt writes a resolved `lost` unavailable entry; inventory transfers now go requested → approved (`inventory.adjustment.approve`) → dispatched; transfers (both modules) and issue requests can be cancelled/closed; library transfers can close short (copies marked lost + incident); members can be blocked by hand (`blockedBy`); `inventory.asset.register` takes `quantity` (1–50, no serial number); library loans/returns number as `LIS`/`LRT` (no longer share `ISS`/`RET` with inventory); renewing an overdue loan fines the overdue days.
- 2026-11-06 · library permissions · `library.catalogue.manage` and `library.catalogue.view` merged into one `library.catalogue` (view, add, edit; Node action id 332 dropped, 331 kept) · Library has a single Librarian role, so a read-only catalogue permission had no holder. The other Library permissions are unchanged.
- 2026-11-08 · library permissions · all `library.*` permissions removed: the Library tile from Node is the only gate. Callables and rules require only a signed-in non-parent staff user (campus scope still applies); lost/damaged incident notices now go to the member only (librarian fan-out was permission-based)
- 2026-11-08 · library client writes · `library-catalogue-upsert/setStatus`, `library-copy-update/move` and `library-member-setBlocked` callables replaced by client writes (`LibraryWrites`), stamped with `lastWrite` and audited by `onDocumentWritten` triggers; title uniqueness keys (`uniqueKeys/libraryTitle_*`) are client create-only
- 2026-11-08 · borrowing policies · `library-policy-upsert/setStatus` callables replaced by client writes (`LibraryWrites`), stamped with `lastWrite`, audited by `auditLibraryPolicies`, rules fix library/person type/campus; the no-overlap check runs before the write (client transactions cannot query), so two simultaneous saves could overlap.
- 2026-11-08 · circulation · `library-loan-issue/return/renew/markLost` callables replaced by client transactions (`LoanWrites`): loans are stamped `lastWrite` and audited by `auditLibraryLoans`; fines, incidents, copy/member/reservation changes and `LIS/LRT/FIN/INC` counters are plain writes guarded by `firestore.rules`; the member's notices (issued, returned, fine, lost/damaged, hold ready) come from triggers in `notices.ts`. Policy lookup, borrowing-limit count and the reservation queue run just before the transaction, so simultaneous desks could exceed a limit; numbers may skip. `test/circulation.ts` keeps callable mirrors only so other tests can build state.
- 2026-11-08 · reservations · `library-reservation-create/cancel` callables replaced by client transactions (`LoanWrites.reserve/cancelReservation`), stamped `lastWrite` and audited by `auditLibraryReservations`; `RSV` counter and reservation create/cancel are guarded by `firestore.rules`. The duplicate-reservation, loan and shelf checks run just before the transaction. `test/circulation.ts` mirrors both for tests.
- 2026-11-08 · fines · `library-fine-waive/setPayment` callables replaced by client transactions (`LoanWrites.waiveFine/recordFinePayment`), stamped `lastWrite` and audited by `auditLibraryFines`; rules allow only the amount, status and history fields to change. The member's fine block is lifted when no other fine of theirs is open (checked just before the transaction). `test/circulation.ts` mirrors both for tests.
- 2026-11-08 · incidents · `library-incident-report/resolve` callables replaced by client transactions (`LoanWrites.reportIncident/resolveIncident`), stamped `lastWrite` and audited by `auditLibraryIncidents`; the member notice comes from `noticeIncidents` for every incident with a member. The open-incident check for a copy runs just before the transaction. `src/library/fines.ts` and `incidents.ts` are gone: no callable is left in them, and `test/circulation.ts` mirrors the fine, incident and circulation callables for tests.
- 2026-11-06 · library categories · Library categories have no code: the document ID is automatic, a name must be unique under the same parent (checked in the app, ignoring case), the catalogue import takes `category` (the name) instead of `categoryCode` · codes added nothing the name does not give; categories are chosen from a list and never typed. Inventory categories keep their codes.
- 2026-11-06 · libraries · A library has no code and no librarian staff IDs, and its single contact field became `phone` and `email` (validated in the form): the document ID is automatic, the name must be unique among libraries (checked in the app, ignoring case), the campus field is hidden when the user has one campus, and the copies and members imports take `library` / `libraries` (names) instead of `libraryCode` / `libraryCodes` · there is one Librarian role, so listing staff per library served nothing; codes added nothing a name does not give.
- 2026-11-06 · members · The Library keeps no list of students or teachers and nobody is enrolled: the desk finds a person in Node (`searchStudent` through the `routes` package) and `library-loan-issue` / `library-reservation-create` take that `person` (type, ERP ID, name, class). The `libraryMembers` record (`<type>_<erpId>`: name, class, campuses seen, `activeLoans`, `blocked`) is created on first use and its name and class refreshed on each later use; it exists to carry the loan count and the fine or manual block. Borrowing policies are per library and person type (student or teacher), so member categories, membership dates, allowed libraries, member active status, the membership-ending notice and the members CSV import are gone. Loans, reservations, fines and incidents also store `memberName`. Teachers cannot be found yet: `LibraryPeopleService.searchTeachers` is a placeholder (TODO) until Node's teacher endpoint is known, so the desk cannot lend to teachers. The dashboard tiles count borrowers (people who borrowed or reserved), not enrolled members. · the ERP is the source of truth for people, so keeping a second enrolled list only duplicated it.
- 2026-11-07 · library categories and classes · A book has optional `classIds` (ERP class IDs, no sections; empty = any class) and the catalogue filters by one class; categories stay two levels (rules reject a third). Filtering or restricting a parent category covers its subcategories (browse `whereIn`, search `categoryIds`, `applicablePolicy` in loans/reservations). Class names come from the ERP at display time; a class gone from the ERP shows as `Class <id>`. · books are curriculum- or general-use, and a class is a property of a book, not a place in the category tree. Needs the new `libraryCatalogue` composite indexes deployed.
- 2026-11-07 · borrowing policies · A policy now names the book categories it applies to (none = every category no other active policy covers), so a library can have several per person type; the ID is automatic, library and person type cannot change after creation, and an active category (or catch-all) belongs to one policy only. A loan uses the policy of the book's category, else its parent's, else the catch-all, and the borrowing limit counts only loans under that same policy (`policySnapshot.policyId`). `canReserve`, `overdueRenewal` and `restrictedCategoryIds` are gone: anyone with a policy for the book's category can reserve, and overdue loans are never renewed (so renewal no longer raises a fine). · rules per category (e.g. shorter loans for reference books) cannot be expressed by a deny-list, and the two switches were not needed.

## Open items

- `icueadmin` Firebase config is on the `prod` flavor; `dev` uses the real `icueadmin-dev` config (Android `src/dev/google-services.json`, iOS `ios/config/dev/GoogleService-Info.plist`, `lib/firebase_options_dev.dart`). Still to do on the Firebase side: confirm `icueadmin-dev` has Firestore (Standard, Native, `asia-south1`), Blaze plan and Auth enabled; upload the APNs key; add the dev Android SHA-1/SHA-256 if needed.
- iOS now builds for both flavors (CocoaPods only, SPM off). To get there: Firebase plugins pinned to `firebase_core 5.0.0` / `firebase_analytics 13.0.0` / `firebase_crashlytics 6.0.0` / `firebase_messaging 17.0.0` (iOS SDK 12.19.0, the newest on CocoaPods trunk; `5.1.0` needs 12.19.3), `icue_face_sdk` on ML Kit 7, iOS minimum raised to 15.5, pods linked statically, and flavor xcconfigs fixed. Unpin Firebase once trunk has 12.19.3. Re-test face recognition on a device after the ML Kit 6→7 upgrade.
- `ios/Podfile.lock` is untracked; decide whether to commit it.
- Dev Node push credentials must be switched to `icueadmin-dev`; APNs key must be uploaded to `icueadmin-dev`.
- Node `POST /v1.0/firebaseToken`: the app assumes response `{ "token": "<custom token>" }`, uid = the ERP user ID as a string, no prefix, claims per architecture §2. Until it is live the exchange fails silently, and `registerPushToken` re-calls Node `updateRegTokens` on each launch (its "already registered" mark is set only after both writes).
- `icueadmin-dev`: enable Firestore (`(default)`, Standard, Native, `asia-south1`) and Blaze, then deploy rules, indexes (incl. `requests.expireAt` TTL) and functions (`firebase deploy --project dev` from `firebase/`), then seed: `npm --prefix firebase/functions run seed -- --project dev --school <schoolId> --roles admin=<id>,…` (needs Node role IDs per school).
- Parent app: when it joins the monorepo (or in its current repo before then) it needs the same custom-token exchange (uid = the parent ID as a string, no prefix, `personType: parent`, `wardStudentIds`), `session-sync`, and token dual-write to `devices/{uid}/tokens`.
