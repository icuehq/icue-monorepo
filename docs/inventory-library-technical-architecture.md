# Inventory & Library – Firebase Technical Architecture

**Status:** Draft for review  
**Source:** `docs/inventory-and-library-management-prd-frs.md` (FRS 1.0, baseline 1.1)  
**Firebase project:** `icueadmin` · **Region:** `asia-south1` (Mumbai) for Firestore, Storage and Functions · **Firestore:** Standard edition, Native mode (Core operations only; no Pipelines, no MongoDB mode)

This document decides *how* the FRS is built. Functional behaviour stays defined by the FRS; section numbers like "FRS 10.8" refer to it.

---

## 1. Decisions at a glance

| # | Decision |
| --- | --- |
| D1 | Node issues a **Firebase custom token** after its own login; Flutter calls `signInWithCustomToken`. No second login. |
| D2 | Tenant = Node `organizationId` (school). Campus = `branchId`. `zoneId` = campus group (used only to resolve a user's campuses). |
| D3 | Roles come from Node. A Firestore permission map (role → permissions) per school makes the §12 matrix configurable. |
| D4 | **All writes go through callable Cloud Functions** (Admin SDK, transactions). Security Rules are read-only for clients, with one exception: offline verification counts (§8). |
| D5 | Every transaction is an **append-only movement/event** plus a **balance/status** update in the same Firestore transaction. |
| D6 | Every mutating callable takes a client-generated `requestId`; replays return the first result (idempotency). |
| D7 | ERP records (students, staff, departments, roles, academic years) are fetched from **Node APIs by the client** and stored in Firestore **as IDs only**. Functions never call Node. |
| D8 | Notifications: Functions send FCM directly, through an outbox collection, to tokens stored in Firestore (registered alongside Node). |
| D9 | Teachers use `icueadmin`. Parents use the parent app (same `icueadmin` Firebase project, moving into this monorepo) and get **read-only** access to their wards' records. Students never sign in. |
| D11 | Two Firebase projects: `icueadmin-dev` and `icueadmin` (prod), with dev/prod app flavors (§14). |
| D10 | Code lives in `firebase/` (rules, indexes, functions) and `features/inventory`, `features/library` (Dart models/services/providers); UI in `apps/icueadmin`. |

---

## 2. Authentication bridge

```
Flutter ──login──▶ Node (/v2.0/login) ──▶ Node token
Flutter ──POST /v1.0/firebaseToken (Node token)──▶ Node
          Node: verify session, resolve user, firebase-admin createCustomToken(uid, claims)
Flutter ──signInWithCustomToken──▶ Firebase Auth ──▶ ID token (claims) used by Firestore/Storage/Functions
```

**Node endpoint (new, owned by the Node team):** `POST /v1.0/firebaseToken`, authenticated by the existing session token. Uses a service account for project `icueadmin`.

**UID:** `u_<userId>` for staff/admin users, `p_<parentId>` for parents. Stable, so Firestore references survive re-login.

**Custom claims** (must stay under 1000 bytes):

| Claim | Meaning | Example |
| --- | --- | --- |
| `sid` | School (`organizationId`) | `12` |
| `cmp` | Allowed campus IDs (`branchId`s; all branches of the zone for zone users) | `[31, 32]` |
| `all` | Consolidated school access (all campuses, present and future) | `true` |
| `rol` | Node role IDs | `[4, 9]` |
| `pt` | Person type: `staff`, `teacher`, `parent` (students never sign in) | `"teacher"` |
| `eid` | ERP person ID (staff ID for staff/teachers) | `884` |
| `wards` | Student IDs (parents only) | `[5521, 5522]` |

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
| `inv.settings` | Admin, Inventory Manager |
| `inv.items.manage` / `inv.items.view` | Admin, Inv. Mgr / + Principal, Storekeeper, Procurement |
| `inv.stock.view` / `inv.stock.operate` | as above / Admin, Inv. Mgr, Storekeeper |
| `inv.issue.request` / `inv.issue.approve` | + Teacher / Principal (configurable) |
| `inv.pr.request` / `inv.pr.approve` | + Teacher, Storekeeper, Procurement / Principal |
| `inv.procure.operate` | Admin, Inv. Mgr, Procurement |
| `inv.vendors.manage` | Admin, Inv. Mgr, Procurement |
| `inv.assets.manage` / `inv.assets.view` | Admin, Inv. Mgr, Storekeeper / + Teacher, Principal |
| `inv.reports.view` | Admin, Principal, Inv. Mgr |
| `lib.settings` | Admin, Librarian |
| `lib.catalogue.manage` / `lib.catalogue.view` | Admin, Librarian / everyone |
| `lib.circulation.operate` | Admin, Librarian |
| `lib.fines.waive` | Admin, Librarian (configurable) |
| `lib.reports.view` | Admin, Principal, Librarian |
| `lib.members.view` | Admin, Principal, Librarian |

Own records (teacher's loans, parent's wards) need no permission; they are matched by `eid` / `wards`. Parents (`pt == parent`) are **read-only**: no callable accepts a parent caller, and rules grant them reads on own-ward records only.

### 3.2 Where permissions are stored

- `schools/{sid}/config/rolePermissions` — `{ roles: { "<roleId>": ["inv.items.view", ...] } }`. Seeded from the table above, edited by admins (audited).
- `schools/{sid}/userAccess/{uid}` — resolved `{ perms: [...], cmp: [...], all, updatedAt }`. Written by the `session.sync` callable after sign-in, and rewritten for affected users by a trigger when `rolePermissions` changes.

Rules read one `userAccess` doc per request (`get()` is cached within a request). Functions read the same doc, so rules and Functions can never disagree.

### 3.3 Scope checks

Every operational document carries `campusId`. A user may touch a document only if `all == true` or `campusId in cmp`. Library documents also carry `libraryId`; librarian access to specific libraries is via `libraries/{id}.staffIds` (FRS 11.2 "assign librarians").

Client list queries must include the same campus filter (`where campusId in cmp`, ≤30 values), otherwise rules reject them.

---

## 4. Firestore data model

All module data lives under the school: `schools/{sid}/<collection>/{docId}`. Inventory collections are prefixed `inv`, Library `lib`, so the modules share nothing except `config`, `userAccess`, `counters`, `auditLogs`, `outbox`, `imports`, `requests`.

Common fields on every document: `campusId`, `createdAt`, `createdBy` (uid), `updatedAt`, `status`.

**ERP references are IDs only** (D7): `erpId`, `classId`, `departmentId`, `ayId`. Screens resolve names through the existing Node APIs, batching the IDs of the visible page. Consequences, accepted:

- The server trusts the ERP IDs it receives from users holding the operating permission; it cannot check that a student ID belongs to the school. Every such write is audited with the actor.
- Search by person name happens in Node (pick the person), then Firestore is queried by `erpId`.
- Report exports run in Flutter (§9) so name columns can be filled from Node. Transactions also carry `txnDate`, `fy` (financial year, derived from date: Apr–Mar, e.g. `2026-27`) and `ay` (academic year ID from ERP) — stamped once, never rewritten (FRS 13).

### 4.1 Shared

| Collection | Purpose |
| --- | --- |
| `config/{doc}` | `rolePermissions`, `inventorySettings` (expiry warning days, approval toggles), `librarySettings` (hold days, blocking rules) |
| `userAccess/{uid}` | Resolved permissions (§3.2) |
| `counters/{type_year}` | Sequential numbers: `PR/2026-27/000123`. Incremented inside the owning transaction. |
| `uniqueKeys/{kind_value}` | Uniqueness guard (item code, vendor code, category code, library code, accession no., asset ID). Created in the same transaction as the record; existing key → `already-exists`. |
| `requests/{requestId}` | Idempotency: stored result of a completed callable, TTL 7 days. |
| `auditLogs/{id}` | `{actor, action, ref, before, after, reason, at}`. Function-written only (FRS 16). |
| `outbox/{eventKey}` | Pending notifications (§7). |
| `imports/{importId}` (+`rows`) | Import jobs (§9). |
| `devices/{uid}/tokens/{tokenHash}` | FCM tokens (§7.2). |

### 4.2 Inventory

| Collection | Key fields | Notes |
| --- | --- | --- |
| `invCategories` | code, name, parentId, suggestedTracking, status | Subcategory = `parentId` set |
| `invUnits` | code, name | Defaults seeded (FRS 10.4) |
| `invItems` | code, name, categoryId, subcategoryId, stockUnit, purchaseUnits `[{unit, factor}]`, tracking `qty|batch|asset`, variantAttrs, minLevel, reorderLevel, defaultPrice, preferredVendorId, defaultLocation, imagePath, searchTokens | `categoryHistory` via audit log |
| `invItems/{id}/variants` | attrs `{size, color}`, sku, status | Uniforms etc. |
| `invStores` | code, name, campusId, location, storekeeperIds, status | Department/location is a field on the store or balance |
| `invBalances/{storeId__itemId__variantId__batchId}` | qtyAvailable, qtyReserved, qtyDamaged, qtyExpired, qtyReceivedTotal, qtyIssuedTotal, unitCost, value, batchNo, mfgDate, expiryDate, belowReorder | **The only stock balance.** One doc per store × item × variant × batch (`-` when not applicable). |
| `invMovements` | type (`receive`, `issue`, `return`, `transfer_out`, `transfer_in`, `adjust`, `expire`, `damage`, `writeoff`, `restore`), balanceId, itemId, storeId, qty (signed), bucket, refType, refId, unitCost | Append-only ledger. Never updated. |
| `invIssueRequests` | lines `[{itemId, variantId, qtyRequested, qtyApproved, qtyIssued}]`, itemIds, requester, departmentId, purpose, status, approval `{by, at, comment}` | FRS 10.8 |
| `invIssues` | requestId, lines `[{balanceId, qty}]`, recipient `{type, erpId}`, issuedBy, recipientAck | One per issuance (partials allowed) |
| `invReturns` | issueId, lines `[{balanceId, qtyUsable, qtyDamaged}]`, inspection | `qtyReturned ≤ issued − returned` |
| `invTransfers` | from `{campusId, storeId}`, to, lines `[{balanceId, qtyDispatched, qtyReceived, discrepancy}]`, status `requested|dispatched|partially_received|received` | In-transit = dispatched − received on open transfers |
| `invAdjustments` | balanceId, before, delta, after, reason, evidence, verificationId, approval | Immutable after `completed` |
| `invUnavailable` | balanceId or assetId, qty, reason, evidence, resolution, resolvedAt | FRS 10.12 register |
| `invPurchaseRequests` | lines `[{itemId, qty, estPrice, qtyOrdered}]`, itemIds, priority, requiredDate, status (FRS 10.13), approval | |
| `invVendors` | code, name, contacts, tax, categories, documents, status, searchTokens | |
| `invQuotations` | vendorId, prId, lines (qty, unitPrice in item stock unit), discount, tax, delivery, total, validUntil, selected, selectionReason | Comparison is a query by `prId` |
| `invPurchaseOrders` | vendorId, prIds, quotationId, deliveryCampusId, lines `[{itemId, variantId, qtyOrdered, qtyReceived, qtyAccepted, qtyRejected, unitPrice}]`, totals, terms, status (FRS 10.16), ack | |
| `invPurchaseOrders/{id}/revisions` | snapshot, changedBy, reason | Post-issue changes (FRS 10.16) |
| `invReceipts` (GRN) | source, poId, storeId, lines `[{itemId, variantId, qtyReceived, qtyAccepted, qtyRejected, condition, batchNo, mfgDate, expiryDate, serials[]}]`, attachments, inspection | Covers FRS 10.7 and 10.17 |
| `invInvoices` | vendorId, invoiceNo, poId, receiptIds, subtotal, tax, discount, total, paidAmount, paymentStatus, attachments | Record only; no payments (FRS 10.18) |
| `invAssets` | assetId, itemId, serialNo, make, model, poId, vendorId, purchaseDate, price, warranty `{start, end}`, condition, campusId, storeId, location, status (FRS 10.19), activeAssignmentId, rfidTag, imagePath | One doc per physical object |
| `invAssetAssignments` | assetId, assignee `{type: staff|student|department, erpId}`, assignedAt, expectedReturn, conditionOut, ack, returnedAt, conditionIn | Top-level so parents/teachers can query their own |
| `invMaintenance` | assetId, issue, priority, technician, cost, partsUsed `[{itemId, qty}]`, status (FRS 10.20), nextServiceDate | Parts used create `issue` movements |
| `invVerifications` | storeId, scope, status `draft|counting|submitted|approved|applied` | |
| `invVerifications/{id}/lines` | balanceId/assetId, expected, counted, diff, reason, countedBy | Client-writable while `counting` (offline) |

### 4.3 Library

| Collection | Key fields | Notes |
| --- | --- | --- |
| `libLibraries` | code, name, campusId, location, staffIds, contact, hours, status | |
| `libCategories` | code, name, parentId, status | Defaults seeded (FRS 11.3) |
| `libCatalogue` | title, subtitle, authors[], isbn10, isbn13, publisher, edition, year, language, categoryId, classNo, keywords, coverPath, status, searchTokens, dupKey | School-wide; shared across libraries |
| `libCopies` | accessionNo, catalogueId, libraryId, campusId, shelf, barcode, rfidTag, acquisitionId, price, source, condition, status (FRS 11.5 + `in_transit`), activeLoanId, heldReservationId | One doc per physical book |
| `libAcquisitions` | type, catalogueId, qty, libraryId, vendorOrDonor, price, reference, copyIds | |
| `libMembers/{memberType_erpId}` | memberType `student|teacher`, erpId, classId (students), category (policy key), libraryIds, start, end, status, activeLoans, blocked | Deterministic ID → no duplicate members |
| `libPolicies` | libraryId, memberCategory, maxBooks, loanDays, maxRenewals, fineType, fineAmount, graceDays, maxFine, canReserve, restrictedCategoryIds, overdueRenewal, status | |
| `libLoans` | memberId, copyId, catalogueId, libraryId, issuedAt, dueAt, renewals[], policySnapshot, status `active|returned|lost`, returnedAt, condition, overdueDays | `policySnapshot` frozen at issue (FRS 11.8) |
| `libReservations` | memberId, catalogueId, libraryId, status (FRS 11.12), createdAt, heldCopyId, holdUntil, fulfilledLoanId | Queue position is computed (count of earlier `waiting`), not stored |
| `libFines/{loanId__type}` | memberId, loanId, type, calc, amount, waived, outstanding, status, waivals[] | Deterministic ID → fines cannot duplicate |
| `libIncidents` | kind `lost|damaged`, copyId, memberId, severity, photos, charge, repairStatus, resolution | FRS 11.14 |
| `libTransfers` | fromLibraryId, toLibraryId, lines `[{copyId, received, condition}]`, status `requested|approved|dispatched|partially_received|received` | |
| `libVerifications` (+`lines`) | libraryId, scope, expected copy IDs, scanned, missing, unexpected, status | Same pattern as inventory |

Parents and teachers read `libLoans`, `libFines`, `libReservations`, `invAssetAssignments` where `memberErpId`/`assignee.erpId` matches their claim, so those docs carry a flat `personErpId` field for rule and index use.

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

| Area | Callables |
| --- | --- |
| Session | `session.sync` |
| Settings | `config.setRolePermissions`, `inv.setSettings`, `lib.setSettings` |
| Inventory masters | `inv.category.upsert/setStatus`, `inv.unit.upsert`, `inv.item.upsert/setStatus`, `inv.variant.upsert`, `inv.store.upsert/setStatus`, `inv.vendor.upsert/setStatus` |
| Stock | `inv.receipt.confirm`, `inv.issueRequest.submit/decide`, `inv.issue.create`, `inv.issue.acknowledge`, `inv.return.create`, `inv.transfer.request/dispatch/receive`, `inv.adjustment.create/approve`, `inv.unavailable.report/resolve` |
| Procurement | `inv.pr.save/submit/decide/cancel`, `inv.quotation.save/select`, `inv.po.save/issue/revise/acknowledge/cancel/close`, `inv.invoice.save/setPayment` |
| Assets | `inv.asset.register`, `inv.asset.assign/return/transfer/setCondition/retire`, `inv.maintenance.save/setStatus` |
| Verification | `inv.verification.create/submit/approve` (approve creates adjustments referencing the session) |
| Library masters | `lib.library.upsert/setStatus`, `lib.category.upsert`, `lib.catalogue.upsert/setStatus`, `lib.policy.upsert` |
| Copies | `lib.acquisition.create` (generates accession numbers + copies), `lib.copy.update/move` |
| Members | `lib.member.upsert/setStatus` |
| Circulation | `lib.loan.issue`, `lib.loan.return`, `lib.loan.renew`, `lib.loan.markLost` |
| Reservations | `lib.reservation.create/cancel` |
| Fines | `lib.fine.waive`, `lib.fine.setPayment` (Finance reference only) |
| Incidents | `lib.incident.report/resolve` |
| Transfers | `lib.transfer.request/approve/dispatch/receive` |
| Verification | `lib.verification.create/submit/approve` |
| Files | `files.getUploadPath` (returns an authorised Storage path) |
| Import/Export | `import.validate`, `import.commit` |

### 5.2 Triggers and schedules

| Function | Trigger | Job |
| --- | --- | --- |
| `onRolePermissionsChange` | Firestore update on `config/rolePermissions` | Recompute `userAccess` for that school |
| `outboxSend` | Firestore create on `outbox/*` | Send FCM, mark sent / retry / drop dead tokens |
| `importWorker` | Task queue (`onTaskDispatched`) | Process 400-row chunks of a committed import |
| `dailyInventory` | `onSchedule` 06:00 Asia/Kolkata | Move expired batches to `qtyExpired`; near-expiry, warranty, maintenance-due and PO-overdue notifications |
| `dailyLibrary` | `onSchedule` 07:00 Asia/Kolkata | Due-soon, overdue, membership-expiring notifications |
| `holdExpiry` | `onSchedule` hourly | Expire reservations past `holdUntil`, pass copy to next in queue or release |

Scheduled jobs are idempotent: notification keys are deterministic (§7.1), and expiry movements check current bucket values.

---

## 6. Critical business invariants

These are enforced in Functions transactions and covered by unit tests.

**Inventory**

- `qtyAvailable` never goes below 0. Issue, transfer-dispatch and negative adjustments check it in the same transaction that decrements it.
- Expired batches (`expiryDate < today`) cannot be issued even before the daily job moves them, so the check doesn't depend on the job having run.
- Batch issue suggests FEFO (first-expiry-first-out); the user may override within non-expired batches.
- Receiving against a PO: `qtyAccepted + qtyRejected ≤ qtyOrdered − (already accepted + rejected)` per line. Cancelled/closed POs reject receipts. PO becomes `fully_received` only when every line is accounted for.
- Purchase quantities convert to `stockUnit` via `purchaseUnits.factor` at receipt time; balances are only ever in stock units.
- Issue approval: one level; `qtyApproved ≤ available` at approval time, re-checked at issuance.
- Returns: per issue line, `returned ≤ issued`. Usable → `qtyAvailable`; damaged → `qtyDamaged` + `invUnavailable` entry.
- Transfers: dispatch decrements source; receipt increments destination (a new balance doc if needed). Shortfall is stored as `discrepancy`, not silently lost.
- Asset: `activeAssignmentId` set ⇒ cannot assign again. `retired`/`disposed` ⇒ cannot assign. Maintenance status drives asset status.
- Masters with history (`invMovements` exist, PO references) cannot be deleted; only deactivated. Deactivated categories/vendors/items are rejected for new transactions.

**Library**

- Issue transaction: member active and not blocked; applicable policy exists (`libraryId + memberCategory`); `activeLoans < maxBooks`; category not restricted; copy `available` (or `reserved` with `heldReservationId` for this member); copy `activeLoanId` empty. Sets `activeLoanId`, `status=issued`, increments `activeLoans`.
- Due date = issue date + `loanDays` (from the frozen snapshot on renewal too).
- Renewal: `renewals < maxRenewals`; rejected if a `waiting` reservation exists for that catalogue in that library; overdue renewal per `policy.overdueRenewal`.
- Return: only against `activeLoanId`; condition `good` → copy goes to the reservation queue or `available`; `damaged` → `damaged` + incident (never auto-available).
- Fine on return per `policySnapshot`: per-day `min((overdueDays − grace) × amount, maxFine)`, fixed, or none (tracking). Lost → replacement charge; damage → penalty. Fine doc ID `loanId__type` makes duplicates impossible.
- Waiver requires `lib.fines.waive`, stores reason, audited.
- Reservation: one active reservation per member × catalogue (deterministic check in transaction); member's policy must allow it; queue ordered by `createdAt`.
- In-transit copies cannot be issued. Lost/withdrawn copies are never available again; replacements get new accession numbers.

**Common**

- Unique codes via `uniqueKeys` in the same transaction.
- Completed transactions are immutable; corrections are new transactions (adjustment, reversal) that reference the original.

---

## 7. Notifications

### 7.1 Outbox

Business transactions write `outbox/{eventKey}` docs inside the same transaction, e.g. `lowstock__{balanceId}__{yyyy-mm-dd}`, `overdue__{loanId}__{yyyy-mm-dd}`, `pr_decided__{prId}`. Because the key is deterministic, `create` fails for an existing event → no repeated messages (FRS 23). `outboxSend` resolves recipients (by permission + campus, or member/requester), loads tokens and sends via `sendEach`.

Recipients:

- **Role-based** (low stock → users with `inv.stock.operate` on that campus): resolved from `userAccess`.
- **Person-based** (member, requester, assignee): resolved from `eid` / ward mapping.

Each outbox doc also keeps a `notifications` copy per recipient (`schools/{sid}/notifications/{id}`) for an in-app inbox, readable by that user only.

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
    function inSchool(sid) { return signedIn() && string(request.auth.token.sid) == sid; }
    function access(sid) { return get(/databases/$(db)/documents/schools/$(sid)/userAccess/$(request.auth.uid)).data; }
    function can(sid, p) { return p in access(sid).perms; }
    function onCampus(sid, c) { return access(sid).all == true || c in access(sid).cmp; }
    function own() { return resource.data.personErpId == request.auth.token.eid
                         || resource.data.personErpId in request.auth.token.get('wards', []); }

    match /schools/{sid}/{coll}/{id} {
      allow write: if false;                    // Functions (Admin SDK) only
    }
    match /schools/{sid}/invItems/{id} {
      allow read: if inSchool(sid) && can(sid, 'inv.items.view');
    }
    match /schools/{sid}/invBalances/{id} {
      allow read: if inSchool(sid) && can(sid, 'inv.stock.view') && onCampus(sid, resource.data.campusId);
    }
    match /schools/{sid}/libLoans/{id} {
      allow read: if inSchool(sid) && (own() || (can(sid, 'lib.circulation.operate')
                                               && onCampus(sid, resource.data.campusId)));
    }
    match /schools/{sid}/invVerifications/{vid}/lines/{id} {
      allow read: if inSchool(sid) && can(sid, 'inv.stock.operate');
      allow create, update: if inSchool(sid) && can(sid, 'inv.stock.operate')
        && get(/databases/$(db)/documents/schools/$(sid)/invVerifications/$(vid)).data.status == 'counting'
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

Paths: `schools/{sid}/{module}/{collection}/{docId}/{file}`. Rules: `sid` claim match, module permission via `firestore.get` of `userAccess`, max 10 MB, content types image/*, application/pdf, spreadsheet types. Uploads are only allowed to a path that `files.getUploadPath` has registered in a pending-upload doc; the owning callable then links the file to its record.

Ceiling: file read access is per-module, not per-record. Per-record checks would need signed URLs from a Function; add if a record-level leak matters.

---

## 9. Import and export

**Import** (FRS 14)

1. Client downloads the template (static `.xlsx`/`.csv` per type, generated in Flutter from column definitions shared with the Function).
2. Upload to `schools/{sid}/imports/{importId}/source.xlsx`.
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
- **Search:** Firestore has no full-text search. Searchable docs store `searchTokens` (lower-cased words and their prefixes of name, code, title, authors, ISBN, accession number), queried with `array-contains`. Exact lookups (code, ISBN, accession, barcode, asset ID, RFID tag) use equality queries.
  - Ceiling: one search term per query, no fuzzy match. Upgrade path: Typesense/Algolia Firebase extension on `libCatalogue`, `invItems` if catalogues outgrow this.
- **Dashboards:** Firestore aggregation queries (`count()`, `sum()`) with the same filters as the lists — e.g. low stock = `count()` where `belowReorder == true`; stock value = `sum('value')`. No pre-computed counters.
- **Popular/inactive books:** computed client-side over the selected period's loans. Ceiling: fine for tens of thousands of loans per period; add monthly stat docs if it gets slow.
- **Indexes:** `firebase/firestore.indexes.json`, one composite index per list filter/sort combination, added with each screen.

---

## 11. Scanning, RFID and offline

- One scan input in Flutter: camera (`mobile_scanner`) on mobile; USB/Bluetooth barcode scanners and RFID readers in keyboard-wedge mode on web/desktop (text field with autofocus + Enter). The scanned string is resolved by equality on `barcode`, `accessionNo`, `assetId` or `rfidTag`.
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
  .firebaserc              # default: icueadmin
  firestore.rules
  firestore.indexes.json
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
  library/lib/src/{models,services,providers,di}
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
