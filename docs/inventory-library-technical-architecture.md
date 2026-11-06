# Inventory & Library – Firebase Technical Architecture

**Status:** Draft for review  
**Source:** `docs/inventory-and-library-management-prd-frs.md` (FRS 1.0, baseline 1.1)  
**Firebase project:** `icueadmin` · **Region:** `asia-south1` (Mumbai) for Firestore, Storage and Functions · **Firestore:** `(default)` database, Standard edition, Native mode (Core operations only; no Pipelines, no MongoDB mode)

This document decides *how* the FRS is built. Functional behaviour stays defined by the FRS; section numbers like "FRS 10.8" refer to it.

---

## 1. Decisions at a glance

| # | Decision |
| --- | --- |
| D1 | Node issues a **Firebase custom token** after its own login; Flutter calls `signInWithCustomToken`. No second login. |
| D2 | Tenant = Node `organizationId` (school). Campus = `branchId`. `zoneId` = campus group (used only to resolve a user's campuses). |
| D3 | Roles come from Node. A Firestore permission map (role → permissions) per school makes the §12 matrix configurable. |
| D4 | **All writes go through callable Cloud Functions** (Admin SDK, transactions). Security Rules are read-only for clients, with two exceptions: offline verification counts (§8) and the code-keyed masters (inventory categories, units, stores, items, variants, vendors; library libraries and categories) and inventory purchase requests, quotations and invoices (`ProcurementWrites`): plain client CRUD guarded only by the managing permission, no validation, audit log, `requestId`, approver notification or campus check in rules; `counters` is client-writable for any user holding a permission (PR/QT numbering). |
| D5 | Every transaction is an **append-only movement/event** plus a **balance/status** update in the same Firestore transaction. |
| D6 | Every mutating callable takes a client-generated `requestId`; replays return the first result (idempotency). |
| D7 | ERP records (students, staff, departments, roles, academic years) are fetched from **Node APIs by the client** and stored in Firestore **as IDs only**. Functions never call Node. |
| D8 | Notifications: Functions send FCM directly, through an outbox collection, to tokens stored in Firestore (registered alongside Node). |
| D9 | Teachers use `icueadmin`. Parents use the parent app (same `icueadmin` Firebase project, moving into this monorepo) and get **read-only** access to their wardStudentIds' records. Students never sign in. |
| D11 | Two Firebase projects: `icueadmin-dev` and `icueadmin` (prod), with dev/prod app flavors (§14). |
| D12 | Text search runs on a second **Enterprise-edition** Firestore database `search`, mirrored from `(default)` by a trigger and queried only through a callable (§10). `(default)` stays Standard. |
| D10 | Code lives in `firebase/` (rules, indexes, functions) and `features/inventory`, `features/library` (Dart models/services/providers/UI and routes; apps only mount `inventoryRoutes()` / `libraryRoutes()`). |

---

## 2. Authentication bridge

```sh
Flutter ──login──▶ Node (/v2.0/login) ──▶ Node token
Flutter ──POST /v1.0/firebaseToken (Node token)──▶ Node
          Node: verify session, resolve user, firebase-admin createCustomToken(uid, claims)
Flutter ──signInWithCustomToken──▶ Firebase Auth ──▶ ID token (claims) used by Firestore/Storage/Functions
```

**Node endpoint (new, owned by the Node team):** `POST /v1.0/firebaseToken`, authenticated by the existing session token. Uses a service account for project `icueadmin`.

**UID:** the ERP user ID as a string, used as it is (for example `"884"`), with no prefix; the `personType` claim says whether it is staff, teacher or parent. Stable, so Firestore references survive re-login. Open point for Node: a staff `userId` and a parent `parentId` must never be equal, because both would map to one Firebase account.

**Custom claims** (must stay under 1000 bytes):

| Claim | Meaning | Example |
| --- | --- | --- |
| `schoolId` | School (`organizationId`) | `12` |
| `campusIds` | Allowed campus IDs (`branchId`s; all branches of the zone for zone users) | `[31, 32]` |
| `hasAllCampuses` | Consolidated school access (all campuses, present and future) | `true` |
| `roleIds` | Node role IDs | `[4, 9]` |
| `personType` | Person type: `staff`, `teacher`, `parent` (students never sign in) | `"teacher"` |
| `personErpId` | ERP person ID (staff ID for staff/teachers) | `884` |
| `wardStudentIds` | Student IDs (parents only) | `[5521, 5522]` |

**Lifecycle**

- Flutter exchanges the token after every Node login and on app start when a Node session exists but Firebase has no user.
- Node logout → Flutter also calls `FirebaseAuth.signOut()`.
- Role/campus change in Node takes effect on next exchange. Node may call `revokeRefreshTokens(uid)` to force it immediately.
- Claims carry *identity*; *permissions* are resolved in Firestore (§3) so permission edits apply without re-issuing tokens.

**Flutter placement:** `features/auth` gains the exchange step inside the existing login/restore flow; `packages/icue_firebase` gains `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage`.

---

## 3. Authorization model

### 3.1 Permissions

Fixed permission keys (code), configurable role mapping (data):

| Key | Default roles (FRS §12) |
| --- | --- |
| `inventory.settings` | Admin, Inventory Manager |
| `inventory.items.manage` / `inventory.items.view` | Admin, Inv. Mgr / + Principal, Storekeeper, Procurement |
| `inventory.stock.view` / `inventory.stock.operate` | as above / Admin, Inv. Mgr, Storekeeper |
| `inventory.issue.request` / `inventory.issue.approve` | + Teacher / Principal (configurable) |
| `inventory.purchaseRequest.request` / `inventory.purchaseRequest.approve` | + Teacher, Storekeeper, Procurement / Principal |
| `inventory.adjustment.approve` | Admin, Principal, Inv. Mgr |
| `inventory.procure.operate` | Admin, Inv. Mgr, Procurement |
| `inventory.vendors.manage` | Admin, Inv. Mgr, Procurement |
| `inventory.assets.manage` / `inventory.assets.view` | Admin, Inv. Mgr, Storekeeper / + Teacher, Principal |
| `inventory.reports.view` | Admin, Principal, Inv. Mgr |
| `library.settings` | Admin, Librarian |
| `library.catalogue` (view, add, edit) | Admin, Librarian |
| `library.circulation.operate` | Admin, Librarian |
| `library.fines.waive` | Admin, Librarian (configurable) |
| `library.reports.view` | Admin, Principal, Librarian |
| `library.members.view` | Admin, Principal, Librarian |

Own records (teacher's loans, parent's wardStudentIds) need no permission; they are matched by `personErpId` / `wardStudentIds`. Parents (`personType == parent`) are **read-only**: no callable accepts a parent caller, and rules grant them reads on own-ward records only.

### 3.2 Where permissions are stored

- Permissions are not stored per school: Node's `getActionsByRole` Ids reach Functions as the `actionIds` token claim and map to permission keys in code (`ACTION_PERMISSIONS`); see `docs/inventory-library-node-actions.md`.
- `schools/{schoolId}/userAccess/{uid}` — resolved `{ permissions: [...], campusIds: [...], all, roleIds, personType, personErpId, wardStudentIds, updatedAt }` (`roleIds` for recompute, `personErpId`/`wardStudentIds` for notification recipients). Written by the `session.sync` callable after every sign-in (permission changes in Node apply at the next token exchange).

Rules read one `userAccess` doc per request (`get()` is cached within a request). Functions read the same doc, so rules and Functions can never disagree.

### 3.3 Scope checks

Every operational document carries `campusId`. A user may touch a document only if `all == true` or `campusId in campusIds`. Library documents also carry `libraryId`; librarian access to specific libraries is via `libraries/{id}.staffIds` (FRS 11.2 "assign librarians").

Client list queries must include the same campus filter (`where campusId in campusIds`, ≤30 values), otherwise rules reject them.

---

## 4. Firestore data model

All module data lives under the school: `schools/{schoolId}/<collection>/{docId}`. Inventory collections are prefixed `inv`, Library `lib`, so the modules share nothing except `config`, `userAccess`, `counters`, `auditLogs`, `outbox`, `imports`, `requests`.

Common fields on every document: `campusId`, `createdAt`, `createdBy` (uid), `updatedAt`, `status`.

**ERP references are IDs only** (D7): `personErpId`, `classId`, `departmentId`. Screens resolve names through the existing Node APIs, batching the IDs of the visible page. Consequences, accepted:

- The server trusts the ERP IDs it receives from users holding the operating permission; it cannot check that a student ID belongs to the school. Every such write is audited with the actor.
- Search by person name happens in Node (pick the person), then Firestore is queried by `personErpId`.
- Report exports run in Flutter (§9) so name columns can be filled from Node. Transactions also carry `transactionDate`, `financialYear` (financial year, derived from date: Apr–Mar, e.g. `2026-27`) — stamped once, never rewritten (FRS 13).

### 4.1 Shared

| Collection | Purpose |
| --- | --- |
| `config/{doc}` | `rolePermissions`, `inventorySettings` (expiry warning days, approval toggles), `librarySettings` (hold days, blocking rules) |
| `userAccess/{uid}` | Resolved permissions (§3.2) |
| `counters/{type_year}` | Sequential numbers: `PR/2026-27/000123`. Incremented inside the owning transaction. |
| `uniqueKeys/{kind_value}` | Uniqueness guard (item code, vendor code, inventory category code, library code, accession no., asset ID). Created in the same transaction as the record; existing key → `already-exists`. |
| `requests/{requestId}` | Idempotency: stored result of a completed callable, TTL 7 days. |
| `auditLogs/{id}` | `{actor, action, ref, before, after, reason, at}`. Function-written only (FRS 16). |
| `outbox/{eventKey}` | Pending notifications (§7). |
| `imports/{importId}` (+`rows`) | Import jobs (§9). |
| `devices/{uid}/tokens/{tokenHash}` | FCM tokens (§7.2). |

### 4.2 Inventory

| Collection | Key fields | Notes |
| --- | --- | --- |
| `inventoryCategories` | code, name, parentId, suggestedTracking, status | Subcategory = `parentId` set |
| `inventoryUnits` | code, name | Defaults seeded (FRS 10.4) |
| `inventoryItems` | code, name, categoryId, subcategoryId, stockUnit, purchaseUnits `[{unit, factor}]`, tracking `quantity | batch | asset`, variantAttrs, minLevel, reorderLevel, defaultPrice, preferredVendorId, defaultLocation, imagePath | `categoryHistory` via audit log |
| `inventoryItems/{id}/variants` | attrs `{size, color}`, sku, status | Uniforms etc. |
| `inventoryStores` | code, name, campusId, location, storekeeperIds, status | Department/location is a field on the store or balance |
| `inventoryBalances/{storeId__itemId__variantId__batchId}` | quantityAvailable, quantityReserved, quantityDamaged, quantityExpired, totalQuantityReceived, totalQuantityIssued, unitCost, value, batchNumber, manufacturingDate, expiryDate, isBelowReorderLevel | **The only stock balance.** One doc per store × item × variant × batch (`-` when not applicable). |
| `inventoryMovements` | type (`receive`, `issue`, `return`, `transfer_out`, `transfer_in`, `adjust`, `expire`, `damage`, `writeoff`, `restore`), balanceId, itemId, storeId, quantity (signed), bucket, refType, refId, unitCost | Append-only ledger. Never updated. |
| `inventoryIssueRequests` | lineItems `[{itemId, variantId, quantityRequested, quantityApproved, quantityIssued}]`, itemIds, requester, purpose, status, approval `{by, at, comment}` | FRS 10.8 |
| `inventoryIssues` | requestId, lineItems `[{balanceId, quantity}]`, recipient `{type, personErpId}`, issuedBy, recipientAck | One per issuance (partials allowed) |
| `inventoryReturns` | issueId, lineItems `[{balanceId, quantityUsable, quantityDamaged}]`, inspection | `quantityReturned ≤ issued − returned` |
| `inventoryTransfers` | from `{campusId, storeId}`, to, `campusId` (source) + `toCampusId` for rules, `requested` `[{itemId, variantId, quantity}]`, lines (set at dispatch, one per batch) `[{balanceId, quantityDispatched, quantityReceived, discrepancy}]`, status `requested | dispatched | partially_received | received` | In-transit = dispatched − received on open transfers |
| `inventoryAdjustments` | balanceId, before, delta, after, reason, evidence, verificationId, approval | Immutable after `completed` |
| `inventoryUnavailableStock` | balanceId or assetId, quantity, reason, evidence, resolution, resolvedAt | FRS 10.12 register |
| `inventoryPurchaseRequests` | lineItems `[{itemId, quantity, estimatedPrice, quantityOrdered}]`, itemIds, priority, requiredDate, status (FRS 10.13), approval | |
| `inventoryVendors` | code, name, contacts, tax, categories, documents, status | Searchable via the `search` mirror (§10) |
| `inventoryQuotations` | vendorId, purchaseRequestId, lines (quantity, unitPrice in item stock unit), discount, tax, delivery, total, validUntil, selected, selectionReason | Comparison is a query by `purchaseRequestId` |
| `inventoryPurchaseOrders` | vendorId, purchaseRequestIds, quotationId, deliveryCampusId, lineItems `[{itemId, variantId, quantityOrdered, quantityReceived, quantityAccepted, quantityRejected, unitPrice}]`, totals, terms, status (FRS 10.16), ack | |
| `inventoryPurchaseOrders/{id}/revisions` | snapshot, changedBy, reason | Post-issue changes (FRS 10.16) |
| `inventoryReceipts` (GRN) | source, purchaseOrderId, storeId, lineItems `[{itemId, variantId, quantityReceived, quantityAccepted, quantityRejected, condition, batchNumber, manufacturingDate, expiryDate, serials[]}]`, attachments, inspection | Covers FRS 10.7 and 10.17 |
| `inventoryInvoices` | vendorId, invoiceNumber, purchaseOrderId, receiptIds, subtotal, tax, discount, total, paidAmount, paymentStatus, attachments | Record only; no payments (FRS 10.18) |
| `inventoryAssets` | assetId, itemId, serialNumber, make, model, purchaseOrderId, vendorId, purchaseDate, price, warranty `{start, end}`, condition, campusId, storeId, location, status (FRS 10.19), activeAssignmentId, rfidTag, imagePath | One doc per physical object |
| `inventoryAssetAssignments` | assetId, assignee `{type: staff | student | department, personErpId}`, assignedAt, expectedReturn, conditionOut, ack, returnedAt, conditionIn | Top-level so parents/teachers can query their own |
| `inventoryMaintenanceJobs` | assetId, issue, priority, technician, cost, partsUsed `[{itemId, quantity}]`, status (FRS 10.20), nextServiceDate | Parts used create `issue` movements |
| `inventoryVerifications` | storeId, scope, status `draft | counting | submitted | approved | applied` | |
| `inventoryVerifications/{id}/lines` | balanceId, expected, counted, diff, reason, countedBy | Written by `inventory.verification.count` (client-writable offline counting arrives with Inv-8) |

### 4.3 Library

| Collection | Key fields | Notes |
| --- | --- | --- |
| `libraries` | code, name, campusId, location, staffIds, contact, hours, status | |
| `libraryCategories` | code, name, parentId, status | Defaults seeded (FRS 11.3) |
| `libraryCatalogue` | title, subtitle, authors[], isbn10, isbn13, publisher, edition, year, language, categoryId, classificationNumber, keywords, coverPath, status, identityKey | School-wide; shared across libraries |
| `libraryCopies` | accessionNumber, catalogueId, libraryId, campusId, shelf, barcode, rfidTag, acquisitionId, price, source, condition, status (FRS 11.5 + `in_transit`), activeLoanId, heldReservationId | One doc per physical book |
| `libraryAcquisitions` | type, catalogueId, quantity, libraryId, vendorOrDonor, price, reference, copyIds | |
| `libraryMembers/{memberType_erpId}` | memberType `student | teacher`, personErpId, classId (students), category (policy key), libraryIds, start, end, status, activeLoans, blocked | Deterministic ID → no duplicate members |
| `libraryBorrowingPolicies` | libraryId, memberCategory, maxBooks, loanDays, maxRenewals, fineType, fineAmount, graceDays, maxFine, canReserve, restrictedCategoryIds, overdueRenewal, status | |
| `libraryLoans` | memberId, copyId, catalogueId, libraryId, issuedAt, dueAt, renewals[], policySnapshot, status `active | returned | lost`, returnedAt, condition, overdueDays | `policySnapshot` frozen at issue (FRS 11.8) |
| `libraryReservations` | memberId, catalogueId, libraryId, status (FRS 11.12), createdAt, heldCopyId, holdUntil, fulfilledLoanId | Queue position is computed (count of earlier `waiting`), not stored |
| `libraryFines/{loanId__type}` | memberId, loanId, type, fineCalculation, amount, waived, outstanding, status, waivers[] | Deterministic ID → fines cannot duplicate |
| `libraryIncidents` | kind `lost | damaged`, copyId, memberId, severity, photos, charge, repairStatus, resolution | FRS 11.14 |
| `libraryTransfers` | fromLibraryId, toLibraryId, lineItems `[{copyId, received, condition}]`, status `requested | approved | dispatched | partially_received | received` | |
| `libraryVerifications` (+`lineItems`) | libraryId, scope, expected copy IDs, scanned, missing, unexpected, status | Same pattern as inventory |

Parents and teachers read `libraryLoans`, `libraryFines`, `libraryReservations`, `inventoryAssetAssignments` where `memberErpId`/`assignee.personErpId` matches their claim, so those docs carry a flat `personErpId` field for rule and index use.

---

## 5. Cloud Functions

TypeScript, Node 22, `firebase-functions` v2, region `asia-south1`, input validation with `zod`. Every callable follows one wrapper:

1. Require auth; load `userAccess`; check permission + campus scope.
2. Validate input.
3. Check `requests/{requestId}`; return stored result if present.
4. Run one Firestore transaction: read state → enforce rules → write documents, movements, audit log, outbox entries, `requests/{requestId}`.
5. Return the result.

A failed transaction writes nothing (FRS 22 "no partial updates").

### 5.1 Callables

Names below are logical; they deploy as `<group>-<name>` (`session.sync` → `session-sync`, `inventory.item.upsert` → `inventory-item-upsert`) because function names cannot contain dots.

| Area | Callables |
| --- | --- |
| Session | `session.sync` |
| Settings | `config.setRolePermissions`, `inventory.setSettings`, `library.setSettings` |
| Inventory masters | `inventory.seedDefaults`, `inventory.item.search`. Categories, units, stores, items, variants and vendors are client Firestore writes (`firestore.rules`); the bulk importer reuses their server handlers internally. |
| Stock | Receive Stock, issue request submit/decide, issuing stock, acknowledging an issue, returns, transfer requests, approvals, cancellations, dispatches, receipts, stock adjustments, and unavailable-stock reports and resolutions are client transactions (`StockWrites`). `inventory.adjustment.approve` |
| Procurement | Purchase requests, quotations, draft purchase orders (save, issue, revise, acknowledge, cancel, close, receive goods) and invoices are client Firestore writes (`ProcurementWrites`). |
| Assets | `inventory.asset.register`, `inventory.asset.assign/return/transfer/setCondition/retire`, `inventory.maintenance.save/setStatus` |
| Verification | `inventory.verification.create/count/submit/decide` (approve creates adjustments referencing the session; reject reopens counting) |
| Library masters | `library.catalogue.upsert/setStatus/search`, `library.seedDefaults`, `library.policy.upsert`. Libraries and categories are client Firestore writes. |
| Copies | `library.acquisition.create` (generates accession numbers + copies), `library.copy.update/move` |
| Members | `library.member.upsert/setStatus` |
| Circulation | `library.loan.issue`, `library.loan.return`, `library.loan.renew`, `library.loan.markLost` |
| Reservations | `library.reservation.create/cancel` |
| Fines | `library.fine.waive`, `library.fine.setPayment` (Finance reference only) |
| Incidents | `library.incident.report/resolve` |
| Transfers | `library.transfer.request/approve/dispatch/receive` |
| Verification | `library.verification.create/submit/approve` |
| Files | `files.getUploadPath` (returns an authorised Storage path) |
| Import/Export | `import.validate`, `import.commit` |

### 5.2 Triggers and schedules

| Function | Trigger | Job |
| --- | --- | --- |
| `onRolePermissionsChange` | Firestore update on `config/rolePermissions` | Recompute `userAccess` for that school |
| `outboxSend` | Firestore create on `outbox/*` | Send FCM, mark sent / retry / drop dead tokens |
| `importWorker` | Task queue (`onTaskDispatched`) | Process 400-row chunks of a committed import |
| `dailyInventory` | `onSchedule` 06:00 Asia/Kolkata | Move expired batches to `quantityExpired`; near-expiry, warranty, maintenance-due and PO-overdue notifications |
| `dailyLibrary` | `onSchedule` 07:00 Asia/Kolkata | Due-soon, overdue, membership-expiring notifications |
| `holdExpiry` | `onSchedule` hourly | Expire reservations past `holdUntil`, pass copy to next in queue or release |

Scheduled jobs are idempotent: notification keys are deterministic (§7.1), and expiry movements check current bucket values.

---

## 6. Critical business invariants

These are enforced in Functions transactions and covered by unit tests.

**Inventory**

- `quantityAvailable` never goes below 0. Issue, transfer-dispatch and negative adjustments check it in the same transaction that decrements it.
- Expired batches (`expiryDate < today`) cannot be issued even before the daily job moves them, so the check doesn't depend on the job having run.
- Batch issue suggests FEFO (first-expiry-first-out); the user may override within non-expired batches.
- Receiving against a PO: `quantityAccepted + quantityRejected ≤ quantityOrdered − (already accepted + rejected)` per line. Cancelled/closed POs reject receipts. PO becomes `fully_received` only when every line is accounted for.
- Purchase quantities convert to `stockUnit` via `purchaseUnits.factor` at receipt time; balances are only ever in stock units.
- Issue approval: one level; `quantityApproved ≤ available` at approval time, re-checked at issuance.
- Returns: per issue line, `returned ≤ issued`. Usable → `quantityAvailable`; damaged → `quantityDamaged` + `inventoryUnavailableStock` entry.
- Transfers: dispatch decrements source; receipt increments destination (a new balance doc if needed). Shortfall is stored as `discrepancy`, not silently lost.
- Asset: `activeAssignmentId` set ⇒ cannot assign again. `retired`/`disposed` ⇒ cannot assign. Maintenance status drives asset status.
- Masters with history (`inventoryMovements` exist, PO references) cannot be deleted; only deactivated. Deactivated categories/vendors/items are rejected for new transactions.

**Library**

- Issue transaction: member active and not blocked; applicable policy exists (`libraryId + memberCategory`); `activeLoans < maxBooks`; category not restricted; copy `available` (or `reserved` with `heldReservationId` for this member); copy `activeLoanId` empty. Sets `activeLoanId`, `status=issued`, increments `activeLoans`.
- Due date = issue date + `loanDays` (from the frozen snapshot on renewal too).
- Renewal: `renewals < maxRenewals`; rejected if a `waiting` reservation exists for that catalogue in that library; overdue renewal per `policy.overdueRenewal`.
- Return: only against `activeLoanId`; condition `good` → copy goes to the reservation queue or `available`; `damaged` → `damaged` + incident (never auto-available).
- Fine on return per `policySnapshot`: per-day `min((overdueDays − grace) × amount, maxFine)`, fixed, or none (tracking). Lost → replacement charge; damage → penalty. Fine doc ID `loanId__type` makes duplicates impossible.
- Waiver requires `library.fines.waive`, stores reason, audited.
- Reservation: one active reservation per member × catalogue (deterministic check in transaction); member's policy must allow it; queue ordered by `createdAt`.
- In-transit copies cannot be issued. Lost/withdrawn copies are never available again; replacements get new accession numbers.

**Common**

- Unique codes via `uniqueKeys` in the same transaction.
- Completed transactions are immutable; corrections are new transactions (adjustment, reversal) that reference the original.

---

## 7. Notifications

### 7.1 Outbox

Business transactions write `outbox/{eventKey}` docs inside the same transaction, e.g. `lowstock__{balanceId}__{yyyy-mm-dd}`, `overdue__{loanId}__{yyyy-mm-dd}`, `pr_decided__{purchaseRequestId}`. Because the key is deterministic, an existing event is skipped (read in the transaction, not `create`, which would abort the business write) → no repeated messages (FRS 23). Delivery creates `notifications/{eventKey__uid}` once per recipient, so retries never double-send. `outboxSend` resolves recipients (by permission + campus, or member/requester), loads tokens and sends via `sendEach`.

Recipients:

- **Role-based** (low stock → users with `inventory.stock.operate` on that campus): resolved from `userAccess`.
- **Person-based** (member, requester, assignee): resolved from `personErpId` / ward mapping.

Each outbox doc also keeps a `notifications` copy per recipient (`schools/{schoolId}/notifications/{id}`) for an in-app inbox, readable by that user only.

### 7.2 Token management (Node + Firebase)

The device token is registered in **one client call** that writes both places, so they cannot drift for long:

1. `AuthService.registerPushToken` keeps calling Node `/v1.0/updateRegTokens` (unchanged), **and** writes `devices/{uid}/tokens/{sha256(token)}` `{token, platform, app, updatedAt}`. This one client write is allowed by rules for the owner only.
2. Token refresh: same method (already wired to `onTokenRefresh` in `main.dart`).
3. Logout: `_removePushToken` also deletes the Firestore token doc **before** `FirebaseAuth.signOut()`.
4. Cleanup: when FCM returns `registration-token-not-registered` / `invalid-argument`, `outboxSend` deletes that token doc. Docs not refreshed in 60 days are deleted by `dailyInventory`.
5. The local "already registered" check (`getFcmToken() == token`) moves to after both writes succeed, so a failed Firestore write retries on next launch.

The parent app (moving into this monorepo) needs the same exchange and token dual-write; until it moves, the change is made in its current repo.

### 7.3 Preferences

FRS 10.22 says "respect existing ERP notification preferences". Functions do not call Node (D7), so module preferences live in Firestore: users mute module notifications via `devices/{uid}.mute` per category.

---

## 8. Security Rules

### 8.1 Firestore

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn() { return request.auth != null; }
    function inSchool(schoolId) { return signedIn() && string(request.auth.token.schoolId) == schoolId; }
    function access(schoolId) { return get(/databases/$(db)/documents/schools/$(schoolId)/userAccess/$(request.auth.uid)).data; }
    function can(schoolId, p) { return p in access(schoolId).permissions; }
    function onCampus(schoolId, c) { return access(schoolId).all == true || c in access(schoolId).campusIds; }
    function own() { return resource.data.personErpId == request.auth.token.personErpId
                         || resource.data.personErpId in request.auth.token.get('wardStudentIds', []); }

    match /schools/{schoolId}/{coll}/{id} {
      allow write: if false;                    // Functions (Admin SDK) only
    }
    match /schools/{schoolId}/inventoryItems/{id} {
      allow read: if inSchool(schoolId) && can(schoolId, 'inventory.items.view');
    }
    match /schools/{schoolId}/inventoryBalances/{id} {
      allow read: if inSchool(schoolId) && can(schoolId, 'inventory.stock.view') && onCampus(schoolId, resource.data.campusId);
    }
    match /schools/{schoolId}/libraryLoans/{id} {
      allow read: if inSchool(schoolId) && (own() || (can(schoolId, 'library.circulation.operate')
                                               && onCampus(schoolId, resource.data.campusId)));
    }
    match /schools/{schoolId}/inventoryVerifications/{vid}/lines/{id} {
      allow read: if inSchool(schoolId) && can(schoolId, 'inventory.stock.operate');
      allow create, update: if inSchool(schoolId) && can(schoolId, 'inventory.stock.operate')
        && get(/databases/$(db)/documents/schools/$(schoolId)/inventoryVerifications/$(vid)).data.status == 'counting'
        && request.resource.data.keys().hasOnly(['ref', 'counted', 'reason', 'countedBy', 'countedAt'])
        && request.resource.data.countedBy == request.auth.uid;
    }
    match /devices/{uid}/tokens/{id} {
      allow read, write: if signedIn() && request.auth.uid == uid;
    }
    // ... one read rule per collection following the same pattern
  }
}
```

`auditLogs`, `requests`, `uniqueKeys`, `outbox`, `counters` have **no** client read or write.

### 8.2 Storage

Paths: `schools/{schoolId}/{module}/{collection}/{docId}/{file}`. Rules: `schoolId` claim match, module permission via `firestore.get` of `userAccess`, max 10 MB, content types image/*, application/pdf, spreadsheet types. Uploads are only allowed to a path that `files.getUploadPath` has registered in a pending-upload doc; the owning callable then links the file to its record. Until that callable exists (first phase with uploads), Storage writes are denied.

Ceiling: file read access is per-module, not per-record. Per-record checks would need signed URLs from a Function; add if a record-level leak matters.

---

## 9. Import and export

**Import** (FRS 14)

1. Client downloads the template (static `.xlsx`/`.csv` per type, generated in Flutter from column definitions shared with the Function).
2. Upload to `schools/{schoolId}/imports/{importId}/source.xlsx`.
3. `import.validate {importId, type, columnMap}`: parses (`exceljs` / `csv-parse`), applies the column map, validates each row (required fields, references, duplicates within file and against `uniqueKeys`), writes `imports/{id}/rows` with `ok|error|warning|duplicate` and returns the summary.
4. Client previews rows/errors (paginated).
5. `import.commit {importId, overwrite: false}`: enqueues `importWorker` tasks per 400 rows; each chunk is one transaction through the same code path as the single-record callable (so every rule above applies). `overwrite: true` requires `*.settings` permission.
6. `imports/{id}` keeps the final summary forever (import history).

Types: inventory categories, items, opening stock, stores, assets, vendors; library catalogue, copies, member mapping.

**Export**

- Lists on screen: CSV/XLSX generated client-side from the rows already loaded (current page or "all" up to 5000 rows).
- Reports: Flutter pages through the report query (same rules as the list), resolves person names via Node per page, and writes CSV/XLSX (`excel`) or PDF (`pdf`). A progress indicator keeps the UI responsive. Ceiling: very large exports (100k+ rows) are slow in the browser; move to a Function once names are not needed or Node is callable server-side.
- Purchase orders and labels: PDF generated in Flutter (`pdf` + `printing` packages) from the PO / copy docs.

---

## 10. Search, lists and dashboards

- **Pagination:** cursor-based (`startAfterDocument`), 25–50 rows per page.
- **Search:** Standard Firestore has no full-text search, so searchable collections are mirrored into the Enterprise database `search` (same paths, list-row fields only, `srcUpdatedAt` guards against out-of-order deliveries) by an `onDocumentWritten` trigger (`syncItemSearch`). A read-only callable (`inventory-item-search`) queries the mirror with the `search` pipeline stage, optional `where` filters (e.g. category), `sort`, `offset`/`limit`, and returns list rows; the school comes from the token. The `search` database allows no client access. Exact lookups (code, ISBN, accession, barcode, asset ID, RFID tag) stay equality queries on `(default)`.
  - Matching is whole-word, case-insensitive with stemming; **no prefix or type-ahead matching** (checked on a dev database, 2026-10-31). A mirror update is searchable in about 150 ms.
  - Needs a text index per project (`firebase/scripts/create-search-index.sh`); Flutter has no Pipelines SDK, hence the callable. The emulator has no text search, so in the emulator the callable falls back to a whole-word scan of the mirror and only the real path needs a cloud project to verify.
  - Library catalogue reuses the same trigger/callable pattern (`syncCatalogueSearch`, `library-catalogue-search`; text index on title, subtitle, authors, publisher, keywords); a query that is a valid ISBN is an exact lookup on `(default)` instead. Vendors will follow.
- **Dashboards:** Firestore aggregation queries (`count()`, `sum()`) with the same filters as the lists — e.g. low stock = `count()` where `isBelowReorderLevel == true`; stock value = `sum('value')`. No pre-computed counters.
- **Popular/inactive books:** computed client-side over the selected period's loans. Ceiling: fine for tens of thousands of loans per period; add monthly stat docs if it gets slow.
- **Indexes:** `firebase/firestore.indexes.json`, one composite index per list filter/sort combination, added with each screen.

---

## 11. Scanning, RFID and offline

- One scan input in Flutter: camera (`mobile_scanner`) on mobile; USB/Bluetooth barcode scanners and RFID readers in keyboard-wedge mode on web/desktop (text field with autofocus + Enter). The scanned string is resolved by equality on `barcode`, `accessionNumber`, `assetId` or `rfidTag`.
- RFID: `rfidTag` fields on copies and assets; tag assignment screen. Fixed/gate readers that push events integrate later via an HTTP Function authenticated with a per-school key (FRS Phase 8). Not required for any basic operation.
- Offline:
  - Mobile: Firestore persistence on (default) → previously loaded records readable offline. Web: enable persistent cache.
  - Verification counts and scans are written directly to `…Verifications/{id}/lines`; Firestore queues them offline and syncs later (only client-write path besides device tokens).
  - All callables (issue, return, approvals) require a connection; the UI shows "needs connection" and nothing is queued.

---

## 12. Repository layout

```
firebase/
  firebase.json            # firestore, storage, functions (region asia-south1), emulators
  .firebaserc              # default: icueadmin-dev (alias dev); prod alias icueadmin
  firestore.rules
  firestore.indexes.json
  search.rules             # deny-all rules of the `search` database
  storage.rules
  functions/
    package.json, tsconfig.json
    src/
      index.ts             # exports
      shared/              # callable wrapper, auth/access, counters, uniqueKeys, audit, outbox, years
      inventory/           # one file per area: masters, stock, procurement, assets, verification, jobs
      library/             # masters, copies, members, circulation, reservations, fines, transfers, verification, jobs
      io/                  # import, export
    test/                  # vitest: pure business logic + emulator tests for transactions
  rules-tests/             # @firebase/rules-unit-testing against the emulator
features/
  inventory/lib/src/{models,services,providers,di}
  library/lib/src/{models,services,providers,di}   # Dart package `school_library` (`library` is reserved)
packages/icue_firebase/    # + auth, firestore, functions, storage; callable helper; paged query helper
features/auth/             # + Firebase custom-token exchange, token dual-write
apps/icueadmin/lib/features/{inventory,library}/   # UI
```

- Feature services call Firestore (reads) and callables (writes) through `icue_firebase`. They do not use `api_client`. AGENTS.md will be updated with this rule when the packages are created.
- Business logic that must not drift (fine calculation, due dates, unit conversion, FY derivation) lives in Functions and is unit-tested there. Dart models only parse and display.
- Melos: add `firebase/functions` scripts (`npm test`, `npm run build`), and the emulator suite to CI.

---

## 13. Resolved questions

| # | Answer | Effect |
| --- | --- | --- |
| Q1 | Node APIs only fetch users; Firestore stores ID references | D7, §4 (IDs only), §9 (client-side exports) |
| Q2 | Node provides roles and departments per school | Permission editor lists Node roles |
| Q3 | Parent app uses the `icueadmin` project, is ours, will move into this monorepo; parents view only | D9, §3.1, §7.2 |
| Q4 | Firestore database to be created by the owner: **Standard edition, Native mode, `asia-south1`**, project on Blaze plan | Prerequisite for Phase 0 |
| Q5 | Students never sign in; access only via parents | No `student` person type |

Still needed before the related screens: the exact Node endpoints (request/response) for students by class/section, staff, departments, roles and academic years.

## 14. Environments

| | Dev | Prod |
| --- | --- | --- |
| Firebase project | `icueadmin-dev` (same settings: Standard, Native, `asia-south1`, Blaze) | `icueadmin` |
| Node backend | Existing dev Node | Existing prod Node |
| `firebaseToken` signing account | Service account of `icueadmin-dev` | Service account of `icueadmin` |
| App IDs | Separate dev Android/iOS app IDs (flavor), installs side by side with prod | Current IDs |

- `firebase/.firebaserc` defines aliases `dev` and `prod`; the default is `dev`. Production deploys must name `--project prod` explicitly.
- The Flutter app selects Firebase options and the API environment from the same `ENV` dart-define. Dev gets its own `firebase_options` and per-flavor `google-services.json` / `GoogleService-Info.plist`.
- Rules, indexes and Functions deploy to dev first. Rules tests and function tests run on the emulator and need no project.
- The `search` database (Enterprise, Native, `asia-south1`, ID `search`) is created by the owner in each project, followed by `scripts/create-search-index.sh <project>`.
- Seed data (default categories, units, `rolePermissions`) is created per project by a script; production data is never copied to dev.
- The Node `ENV` and the app's Firebase project must match, or the custom token is rejected.

## 15. Build order

Inventory first (it drives most shared pieces), Library second, following FRS §28/§29 phases. Phase 0 is shared and done once:

| Phase | Deliverable |
| --- | --- |
| 0 | `firebase/` scaffold, emulators, Node `firebaseToken` endpoint, Flutter exchange, `session.sync`, `userAccess`, permission map, callable wrapper (idempotency, audit, counters, uniqueKeys), token dual-write, outbox sender, rules test harness |
| Inv 1–8 | Per FRS §28 |
| Lib 1–8 | Per FRS §29 (reuses Phase 0 and the import/export/verification patterns from Inventory) |

Each phase ships: Functions + rules + rules tests + Function unit tests + Dart models/services + icueadmin screens.
