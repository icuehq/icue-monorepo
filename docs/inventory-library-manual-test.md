# Inventory & Library – Manual test guide (emulator)

Walk it top to bottom. Every step has an action and an **Expect** line; tick it only when
the expectation holds. Note failures with the step number.

Tags: **[JOB]** needs a scheduled job that the emulator never fires on its own (see Part 0.5).
**[EMU]** behaves differently in the emulator.

---

## Part 0 – Setup

### 0.1 Start the emulators

```bash
melos run emulators:reset
```

```bash
melos run emulators
```

Leave it running (Ctrl-C saves data to `firebase/.emulator-data`). Emulator UI: <http://localhost:4000>.

### 0.2 User Roles & Permissions

Inventory and Library permissions are synced automatically on login from Node `/v1.0/getActionsByRole` via `session-sync` into Firestore under `schools/<schoolId>/userAccess/<uid>` (see `docs/inventory-library-node-actions.md`).

For emulator testing:

- **Full Admin / Testing Access**: Sign in through the app. In the Emulator UI (<http://localhost:4000/firestore>), locate `schools/<schoolId>/userAccess/<your uid>`. Ensure `permissions` contains the required keys (or all permissions below), `campusIds: [31, 32]`, and `hasAllCampuses: true`:
  - Inventory: `inventory.settings`, `inventory.items.manage`, `inventory.items.view`, `inventory.stock.view`, `inventory.stock.operate`, `inventory.issue.request`, `inventory.issue.approve`, `inventory.adjustment.approve`, `inventory.purchaseRequest.request`, `inventory.purchaseRequest.approve`, `inventory.procure.operate`, `inventory.vendors.manage`, `inventory.assets.manage`, `inventory.assets.view`, `inventory.reports.view`.
  - Library: `library.settings`, `library.catalogue`, `library.circulation.operate`, `library.fines.waive`, `library.reports.view`, `library.members.view`.
- **Role Verification (Part 1.7 / 2.9)**: To simulate specific roles (e.g. `storekeeper`, `procurement`, `teacher`, `librarian`), edit the `permissions` array directly in the Emulator UI document or sign in as a user with that role.

### 0.3 Run the app

Launch config **icueadmin [Dev + Emulators · Android]** (or iOS). It signs in with a locally built unsigned token. Open Emulator UI → Firestore → `schools/<schoolId>/userAccess/<your uid>`.

- [ ] 0.3.1 `permissions` is non-empty, `campusIds` lists your campus IDs (or `hasAllCampuses: true`). **Expect** the Dashboard shows Inventory and Library tiles.

### 0.4 Test data you will use

- Campuses: `31` and `32` (or your school's actual campus IDs).
- Person IDs: ERP student IDs `501`, `502`, `503`; ERP staff/teacher IDs `884` (yours), `501` (second staff).

### 0.5 Scheduled jobs

`dailyInventory`, `dailyLibrary` and `holdExpiry` do not run by themselves in the emulator. Steps tagged **[JOB]** can only be checked once triggered. Skip those steps for now and mark them blocked if a scheduled job runner is not invoked.

### 0.6 What to watch in the Emulator UI during the run

- `schools/<schoolId>/auditLogs`: one entry per cloud callable mutation.
- `schools/<schoolId>/outbox`: notification events queued for delivery. (Push notifications are not dispatched to real FCM in emulator **[EMU]**).
- Idempotency: repeating actions (e.g. double-tapping save) uses `requestId` deduplication so duplicate records are not created.

---

## Part 1 – Inventory

Open **Inventory** from the dashboard. The Inventory hub shows 15 option grid tiles: Dashboard, Stock verification, Import, Reports, Items, Categories, Units, Stock, Issue requests, Purchase requests, Purchase orders, Vendor invoices, Assets, Vendors, Stores.

### 1.1 Masters (Inv-1)

#### Categories & Default Seed

- [ ] 1.1.1 **Categories** → tap empty-state seed button (or reload if already seeded). **Expect** 14 standard FRS default categories appear (`STA` - Stationery, `CLS` - Classroom supplies, `FUR` - Furniture, `ITE` - IT equipment, `LAB` - Laboratory equipment, `SPT` - Sports equipment, `KIT` - Kitchen supplies, `MED` - Medical supplies, etc.).
- [ ] 1.1.2 On category card `STA` (`Stationery`), tap **Add Subcategory**:
  - Code: `WRI`
  - Name: `Writing Instruments`
  - Suggested Tracking: `Quantity tracked`
  - Tap **Save**. **Expect** `WRI` is listed nested under `Stationery` with a subcategory badge.
- [ ] 1.1.3 Tap FAB **+ Category** to add a new root category:
  - Code: `ART`
  - Name: `Art & Craft Supplies`
  - Suggested Tracking: `Quantity tracked`
  - Tap **Save**. **Expect** `ART` appears as a root category card.
- [ ] 1.1.4 Negative: Tap FAB **+ Category** and enter Code `STA` again with Name `Duplicate Stationery`. Tap Save. **Expect** rejected with error ("Category code already exists").
- [ ] 1.1.5 Deactivate subcategory `WRI` (toggle Active switch off). Try creating an item under `WRI`. **Expect** inactive subcategory is hidden or rejected. Reactivate subcategory `WRI`.

#### Units

- [ ] 1.1.6 **Units** → tap empty-state seed button (if not already seeded). **Expect** 12 standard units appear (`pcs` - Pieces, `box` - Boxes, `pkt` - Packets, `kg`, `g`, `l`, `ml`, `m`, `set`, `pair`, `doz`, `roll`).
- [ ] 1.1.7 Tap FAB **+ Unit**:
  - Code: `ream`
  - Name: `Ream (500 sheets)`
  - Tap **Save**. **Expect** `ream` saved and appears in unit list and item form dropdowns.

#### Stores

- [ ] 1.1.8 **Stores** → tap FAB **+ Store** to create Store 1:
  - Store Name: `Central Main Store` (Note: Store code `CENTRAL_MAIN_STORE` is auto-generated from the name)
  - Campus: `Campus 31`
  - Location: `Admin Building Ground Floor`
  - Description: `Main central distribution store`
  - Store Keepers: Search and add Staff ERP ID `884`
  - Tap **Save**. **Expect** store card created with Active badge and Campus 31.
- [ ] 1.1.9 Tap FAB **+ Store** to create Store 2:
  - Store Name: `Science Lab Store` (Code auto-generated: `SCIENCE_LAB_STORE`)
  - Campus: `Campus 32`
  - Location: `Science Block 2nd Floor`
  - Description: `Laboratory chemicals and apparatus store`
  - Tap **Save**. **Expect** store card created with Campus 32.
- [ ] 1.1.10 Open `Central Main Store` for editing. Check Campus field. **Expect** Campus dropdown is locked/disabled during edit.

#### Items (Catalog Master)

- [ ] 1.1.11 **Items** → tap FAB **+ Item** to add Item 1 (Quantity-tracked consumable):
  - Code: `PEN-BLU-01`
  - Name: `Ballpoint Pen (Blue, 0.7mm)`
  - Category: `Stationery` (`STA`)
  - Subcategory: `Writing Instruments` (`WRI`)
  - Stock Unit: `Pieces (pcs)`
  - Tracking Method: `Quantity tracked`
  - Reorder Level: `50`
  - Default Price: `15.00`
  - Tap **Save**. **Expect** saved. Item card displays code `PEN-BLU-01`, name, category, unit `pcs`, default price (₹15), and reorder level (50).
- [ ] 1.1.12 Add Item 2 (Batch & Expiry-tracked):
  - Code: `MILK-PAST-01`
  - Name: `Pasteurized Milk (500ml pouch)`
  - Category: `Kitchen supplies` (`KIT`)
  - Stock Unit: `Pieces (pcs)`
  - Tracking Method: `Batch & expiry tracked`
  - Reorder Level: `15`
  - Default Price: `30.00`
  - Tap **Save**. **Expect** saved with Batch tracking badge.
- [ ] 1.1.13 Add Item 3 (Serialized Asset-tracked):
  - Code: `LAP-DELL-15`
  - Name: `Dell Latitude 15 Core i5 Laptop`
  - Category: `IT equipment` (`ITE`)
  - Stock Unit: `Pieces (pcs)`
  - Tracking Method: `Asset tracked (serialized)`
  - Reorder Level: `3`
  - Default Price: `45000.00`
  - Tap **Save**. **Expect** saved with Asset tracking badge.
- [ ] 1.1.14 Negative: Tap **+ Item** and enter Code `PEN-BLU-01` again. Tap Save. **Expect** rejected with error ("Item code already exists").
- [ ] 1.1.15 **Item Details & Navigation**: Tap `PEN-BLU-01` in the catalog list. **Expect** Item details screen opens displaying classification, tracking parameters, description, and an active status switch.
- [ ] 1.1.16 **Items Search & Filter**:
  - In Items list search bar, type `pen`. **Expect** `PEN-BLU-01` is filtered immediately.
  - Filter by Category `Stationery`. **Expect** only items under `STA` are shown. Clear search.

---

### 1.2 Stock (Inv-2)

Open **Stock** from Inventory tiles.

#### 1.2.1 Receive Opening Stock (Consumable)

- [ ] Tap **Receive stock** FAB (or quick-action chip "Receive"):
  - Store: `Central Main Store`
  - Source: `Opening stock`
  - Reference: `OP-2024-PEN`
  - Tap **+ Add item**: Search and select `PEN-BLU-01`. Enter Quantity: `100`, Unit Cost: `15.00`.
  - Tap **Receive stock** at bottom.
- [ ] **Expect** in Stock Overview for `Central Main Store`:
  - Available balance for `PEN-BLU-01` = `100`.
  - Store Valuation banner updates by +₹1,500.00.
  - Tap balance card → select **Movement history**: displays `receive` movement with +100 units, bucket `available`, reference `OP-2024-PEN`.

#### 1.2.2 Receive Batch Stock (FEFO Preparation)

- [ ] Tap **Receive stock**:
  - Store: `Central Main Store`
  - Source: `Opening stock`
  - Reference: `OP-2024-MILK`
  - Line 1: Tap **+ Add item** → select `MILK-PAST-01`. Enter Quantity: `20`, Unit Cost: `30.00`, Batch Number: `BATCH-M1`, Expiry Date: Today + 5 days (`YYYY-MM-DD`).
  - Line 2: Tap **+ Add item** → select `MILK-PAST-01`. Enter Quantity: `10`, Unit Cost: `30.00`, Batch Number: `BATCH-M2`, Expiry Date: Today + 25 days (`YYYY-MM-DD`).
  - Tap **Receive stock**.
- [ ] **Expect** in `Central Main Store`:
  - `MILK-PAST-01` shows total Available = `30`.
  - Balance cards list batch entries: `BATCH-M1` (20 units) and `BATCH-M2` (10 units) with respective expiry dates.

#### 1.2.3 Negative: Expired Batch Receipt Rejected

- [ ] Tap **Receive stock** with `MILK-PAST-01`, Batch `BATCH-OLD`, Expiry: Yesterday (`YYYY-MM-DD`), Quantity: `5`. Tap Receive stock.
- [ ] **Expect** rejected with validation error (expired batches cannot be received into active stock).

#### 1.2.4 Negative: Asset-Tracked Items Excluded from Stock Receive

- [ ] In **Receive stock**, tap **+ Add item** to open the item picker dialog. Type `LAP-DELL-15` or `Laptop`.
- [ ] **Expect** `LAP-DELL-15` does NOT appear in the item picker (asset-tracked items are managed through the Assets module and PO receiving, and are excluded from direct stock receive).

#### 1.2.5 Create Issue Request (Requisition)

- [ ] Open **Issue requests** (from tile or Stock quick-action chip) → tap FAB **New request**:
  - Issue from store: `Central Main Store`
  - Purpose: `Exam Hall Supplies for Midterms`
  - Destination: `Main Exam Hall - Block A`
  - Line items: Tap **+ Add item** → select `PEN-BLU-01`, Quantity: `30`.
  - Tap **Submit request**.
- [ ] **Expect** request created with number `ISR/<financialYear>/<seq>`. Status is `Pending`. Appears under `All` and `Pending` filter chips with count badge `1`.

#### 1.2.6 Approve Issue Request

- [ ] As Approver (`inventory.issue.approve`), tap the pending request card to open the request screen.
- [ ] **Expect** the progress strip shows `Requested` done, and the Items section has the Approve quantity field pre-filled with `30`.
- [ ] Change it to `31` and tap **Approve**. **Expect** blocked: cannot approve more than the requested `30`. Set it back to `30`.
- [ ] Tap **Approve**.
- [ ] **Expect** the same screen refreshes to `Approved` (blue) with `Approved 30 · Issued 0` under the item. The request card moves under the `Approved` filter chip; requester receives outbox event `issuerequest__approved`.

#### 1.2.7 Negative: Rejection Reason Required

- [ ] Create a dummy request for `10` pens. Open as Approver and tap **Reject**.
- [ ] A dialog asks for a reason. Tap **Reject** with it empty. **Expect** "A reason is required".
- [ ] Type "Department monthly quota exceeded" and tap **Reject**. **Expect** status changes to `Rejected` and the reason shows on the request screen.

#### 1.2.8 Stock Issuance & Recipient Auto-Fill

- [ ] Open the approved 30-unit request as Storekeeper.
- [ ] In the **Issue stock** card:
  - Recipient: `Staff`, pre-filled with the requester (ERP ID `884`, shown as a chip marked `requester`).
  - Quantity to issue now: pre-filled with the remaining `30`. (It can be lowered to issue in parts.)
- [ ] Tap **Issue stock**.
- [ ] **Expect**:
  - Request status becomes `Issued`; an **Issuances** card for `ISS/...` appears on the same screen.
  - In `Central Main Store` stock overview, `PEN-BLU-01` Available balance drops from `100` to `70`.

#### 1.2.9 Negative: Issue Beyond Available Balance

- [ ] Create and approve an issue request for `500` pens from `Central Main Store`. Try to issue it.
- [ ] **Expect** refused with error (insufficient available balance; balance cannot drop below zero).

#### 1.2.10 Recipient Receipt Acknowledgement

- [ ] In the **Issuances** card for the 30-unit issue, notice `Awaiting receipt`.
- [ ] Tap **Confirm receipt** and confirm in the dialog.
- [ ] **Expect** the label changes to `Receipt confirmed` (green) and the **Confirm receipt** button disappears.

#### 1.2.11 Return Inspection (Usable vs. Damaged Split)

- [ ] On the issuance card tap **Return items** (opens the return screen):
  - `PEN-BLU-01` shows `30 to return`.
  - Returned by: pre-filled with `884`.
  - Enter Usable: `10`, Damaged: `5`.
  - Tap **Record return**.
- [ ] **Expect**:
  - Back on the request screen, the issuance line shows `30 · returned 15`.
  - `Central Main Store` Available balance for `PEN-BLU-01` increases from `70` to `80` (only usable units return to available stock).
  - The `5` damaged units are routed to Damaged / Expired stock (`inventoryUnavailable`).
  - Remaining outstanding on the issue is `15` (30 − 15).

#### 1.2.12 Negative: Return Exceeding Outstanding Quantity

- [ ] On the return screen again, try to return Usable: `20` units (remaining outstanding is only 15).
- [ ] **Expect** blocked: only 15 can still be returned.

#### 1.2.13 Inter-Store Transfer Request

- [ ] Open **Transfers** (from tile or Stock quick-action chip) → tap FAB **New Transfer**:
  - Source store: `Central Main Store` (Campus 31)
  - Destination store: `Science Lab Store` (Campus 32)
  - Remarks: `Transfer surplus stationery to science faculty`
  - Tap **+ Add item**: select `PEN-BLU-01`, Quantity: `20`.
  - Tap **Submit Request** (or **Request Transfer**).
- [ ] **Expect** transfer card created with number `TRF/<year>/<seq>`. Status is `Requested` (amber). Displays route `Central Main Store ➔ Science Lab Store` and `Inter-campus` badge.

#### 1.2.14 Negative: Same Source and Destination Store

- [ ] In **New Transfer**, select `Central Main Store` for both Source and Destination stores. Tap Request.
- [ ] **Expect** blocked with error: "Source and destination stores must differ".

#### 1.2.15 Transfer Dispatch

- [ ] As Storekeeper for `Central Main Store`, the transfer card shows `Ready to dispatch`. Tap it to open the transfer screen.
- [ ] Tap **Dispatch transfer** and confirm in the dialog. (A user on another campus sees only "Waiting for the source store to dispatch the stock" and no button.)
- [ ] **Expect**:
  - Transfer status updates to `In Transit` (blue).
  - `PEN-BLU-01` Available balance in `Central Main Store` drops from `80` to `60` (deducted immediately upon dispatch).
  - `Science Lab Store` balance remains `0` (stock is in transit).

#### 1.2.16 Transfer Partial Receipt & Shortfall Discrepancy Recording

- [ ] Switch Store selector to `Science Lab Store` (or open transfer as receiving storekeeper).
- [ ] Open the transfer card (`Confirm receipt on arrival`). In the Items card:
  - Enter `25` for **Receive now**. **Expect** it is refused: at most 20 can be received. Then enter `15` (5 units short / damaged in transit).
  - Switch ON **"Close transfer after this receipt"** (anything not received is recorded as a permanent shortfall).
  - Tap **Confirm receipt** and confirm the shortfall dialog.
- [ ] **Expect**:
  - Transfer status updates to `Received` (green).
  - `PEN-BLU-01` Available balance in `Science Lab Store` increases from `0` to `15`.
  - Transfer card displays red shortfall badge: *"Shortfall: 5 units"*.
  - Discrepancy of 5 units is logged permanently in transfer audit records.

#### 1.2.17 Stock Adjustment with Reason

- [ ] In `Central Main Store`, tap `PEN-BLU-01` balance card → select **Adjust quantity**:
  - Change (+ adds, − removes): `-3`
  - Reason: `Physical count correction`
  - Note: `Physical count audit discrepancy`
  - Tap **Confirm** / submit.
- [ ] **Expect** `PEN-BLU-01` Available balance drops from `60` to `57`. Movement history logs an `adjust` movement with -3 units and the audit reason.

#### 1.2.18 Damaged / Expired Resolution Flow

- [ ] In Stock Overview, tap quick-action chip **Damaged / Expired** (`unavailable_page`).
- [ ] **Expect** Filter chip `Open (1)` lists the `5` damaged units of `PEN-BLU-01` recorded from step 1.2.11.
- [ ] **Resolution Case A (Restoration)**:
  - Tap the damaged card to open `UnavailableResolveSheet`.
  - Enter remarks: `Replaced leaking caps; inspected and usable`.
  - Select **Return to usable stock**.
  - **Expect**: Status updates to `Resolved`. In `Central Main Store`, `PEN-BLU-01` Available balance increases from `57` to `62`.
- [ ] **Resolution Case B (Reporting & Permanent Write-Off)**:
  - In Stock Overview for `Central Main Store`, tap `PEN-BLU-01` → select **Report damaged / expired / lost**:
    - What happened: `Damaged`
    - Quantity: `2`
    - Details: `Crushed in storage bin`
    - Tap **Report**.
  - `PEN-BLU-01` Available balance drops from `62` to `60`.
  - In **Damaged / Expired** page, open the new 2-unit entry → tap **Write off**.
  - Confirmation dialog prompts: *"Write off? This will permanently resolve 2 units... Action cannot be undone"*. Tap **Confirm**.
  - **Expect**: Entry status becomes `Resolved: Write off`. Stock Available remains `60`.

#### 1.2.19 Low Stock Alert & Filter Chip

- [ ] Open `PEN-BLU-01` in Items → Edit. Update reorder level to `70` (higher than current available `60`). Save.
- [ ] Return to **Stock** for `Central Main Store`.
- [ ] **Expect**:
  - Balance card for `PEN-BLU-01` displays high-visibility warning pill: *"Low Stock: Below reorder level (70)"*.
  - Header filter chip **"Low stock only (1)"** appears.
  - Tapping **"Low stock only"** filters the list to show only `PEN-BLU-01`.
  - Low-stock event generated in outbox.

#### 1.2.20 FEFO Batch Issuance (Earliest Expiry First)

- [ ] In `Central Main Store`, create and approve an issue request for `15` units of `MILK-PAST-01`. Issue it.
- [ ] **Expect**: FEFO allocation consumes 15 units from `BATCH-M1` (expiring in 5 days). `BATCH-M1` balance drops from 20 to `5`. `BATCH-M2` remains untouched at `10`.
- [ ] Create and approve a second issue request for `10` units of `MILK-PAST-01`. Issue it.
- [ ] **Expect**: Remaining 5 units are drawn from `BATCH-M1` (depleting it to 0), and the next 5 units are drawn from `BATCH-M2` (balance drops from 10 to `5`). Earliest-expiry batch is always exhausted first.

---

### 1.3 Procurement (Inv-3, Inv-4, Inv-5)

#### Vendors Master (Inv-3)

- [ ] 1.3.1 **Vendors** → tap FAB **+ Vendor** to add Vendor 1 (Apex):
  - Vendor Name: `Apex Educational Supplies Ltd.`
  - Contact Person: `Sunil Verma`
  - Phone: `9876543210`
  - Email: `sales@apexsupplies.com`
  - Tax / GST: `29ABCDE1234F1Z5`
  - Address: `Plot 14, Industrial Estate, Bangalore`
  - Categories: Tap `Stationery` chip
  - Remarks: `Payment terms: Net 30 days`
  - Tap **Save vendor**. **Expect** the form closes and a vendor card appears with the name, name, contact chips, and GSTIN. Tap the card to open the vendor screen showing address, remarks and categories, with copy buttons.
- [ ] 1.3.2 Add Vendor 2 (Global):
  - Vendor Name: `Global Tech & Lab Instruments`
  - Contact Person: `Priya Nair`
  - Phone: `9845012345`
  - Email: `orders@globaltechlab.in`
  - Categories: Tap `Stationery` chip
  - Tap **Save**. **Expect** Vendor 2 saved.
- [ ] 1.3.3 Negative & Lifecycle:
  - Enter an invalid email (`abc`) and phone (`12`). **Expect** each field shows its own error and nothing is saved.
  - Edit a field and press back. **Expect** a "Discard changes?" dialog.
  - On the Global card menu choose **Deactivate** and confirm. **Expect** an Inactive badge; chip "Active" excludes it, "Inactive" displays it. It no longer appears in the vendor dropdown of new quotations or purchase orders. Reactivate it.
  - Use the search box with a phone number or GST fragment and the category chips. **Expect** the list narrows; with no match **Clear filters** resets it.

#### Purchase Requests (Inv-3)

- [ ] 1.3.4 **Purchase requests** → tap FAB **+ New request**:
  - Delivery campus: `Campus 31`
  - Priority: `High`
  - Purpose: `Annual Examination & Office Supplies Requisition`
  - Required by date: One week from today (`YYYY-MM-DD`)
  - Line 1: Tap **+ Add item** → select `PEN-BLU-01`. Quantity: `120`, Est. Unit Price: `15.00`.
  - Line 2: Tap **+ Add item** → select `LAP-DELL-15` (asset item). Quantity: `5`, Est. Unit Price: `55000.00`.
  - Total Estimated: ₹2,76,800.00.
  - Tap **Save as draft**. **Expect** PR created with status `Draft`, number `PR/<financialYear>/<seq>`.
- [ ] 1.3.5 Edit PR 1:
  - Open the PR (tap its card) → tap **Edit** in the bottom bar.
  - Change `PEN-BLU-01` quantity from `120` to `100` (Estimated total updates to ₹2,76,500.00).
  - Tap **Save as draft**. **Expect** PR card reflects updated quantity 100.
- [ ] 1.3.6 Submit PR 1 (as the requester who created it; PR 1 is still `Draft`):
  - Open the PR (tap its card). The bottom bar shows **Edit** and **Submit**.
  - Tap **Submit**. **Expect** a "Submitted for approval" message and the same screen refreshes in place: status pill `Pending`, a new entry in **History** for the submission, and the bottom bar is gone (the requester has nothing more to do; only the ⋮ menu's **Cancel request** remains).
  - Go back to **Purchase requests**. **Expect** the PR 1 card now shows `Pending`; the line `Draft: submit for approval` is gone.
  - Sign in as a user with `inventory.purchaseRequest.approve` for Campus 31 and open the list. **Expect** the PR 1 card shows `Awaiting your decision`.
- [ ] 1.3.7 Negative: Permissions:
  - Sign in as a user **without** `inventory.purchaseRequest.approve` (e.g. the requester) and open the `Pending` PR 1. **Expect** no **Approve**, **Return** or **Reject** buttons anywhere on the screen, and no `Awaiting your decision` line on its list card.
  - A user who has `inventory.purchaseRequest.approve` does see all three buttons on a `Pending` request (see 1.3.8).

#### PR Revision & Approval Workflow

- [ ] 1.3.8 Approver Review → Return for Revision:
  - Open PR 1 as Approver (with `inventory.purchaseRequest.approve`).
  - Tap **Return**. In the dialog leave the comment empty and tap **Return**. **Expect** "A comment is required".
  - Enter comment: `Please reduce laptop quantity from 5 to 2 due to quarterly budget ceiling.` and tap **Return**.
  - **Expect** status changes to `Returned` (`revision_requested`); the comment shows in a highlighted box under the summary and in History.
- [ ] 1.3.9 Requester Resubmission:
  - As requester, open PR 1 → tap **Edit**.
  - Update `LAP-DELL-15` quantity to `2`.
  - Tap **Submit for approval**.
  - **Expect** status moves back to `Pending`.
- [ ] 1.3.10 Approver Approval:
  - Open PR 1 as Approver → tap **Approve** and confirm (the comment is optional).
  - **Expect** status changes to `Approved`. Action buttons for procurement (`Quotations`, `Direct PO`) become enabled.

#### Quotations & Comparative Analysis (Inv-4)

- [ ] 1.3.11 On the approved PR 1 screen, tap **Quotations** → tap FAB **+ Add quotation**:
  - Vendor: Select `Apex Educational Supplies Ltd.` (Vendor 1)
  - Vendor Ref: `QT-APEX-2026-09`
  - Valid Until: 30 days from today (`YYYY-MM-DD`)
  - Delivery Days: `5`
  - Line 1 (`PEN-BLU-01`, 100 pc): Unit Price `14.50`
  - Line 2 (`LAP-DELL-15`, 2 pc): Unit Price `54000.00`
  - Subtotal: ₹1,09,450.00
  - Tap **Record Quotation** (a quotation saved as draft cannot be selected until recorded; its card then has a **Record Quotation** button).
  - **Expect** Quotation 1 created with status `Final`.
- [ ] 1.3.12 Tap **+ Add quotation** again:
  - Vendor: Select `Global Tech & Lab Instruments` (Vendor 2)
  - Vendor Ref: `QT-GLB-881`
  - Valid Until: 15 days from today (`YYYY-MM-DD`)
  - Delivery Days: `12`
  - Line 1 (`PEN-BLU-01`, 100 pc): Unit Price `15.50`
  - Line 2 (`LAP-DELL-15`, 2 pc): Unit Price `53500.00`
  - Subtotal: ₹1,08,550.00
  - Tap **Record Quotation**.
  - **Expect** Quotation 2 created with status `Final`.
- [ ] 1.3.13 Comparative Matrix & Selection (screen `Quotations · PR/…`):
  - The top card **Price Comparison Table** has one column per vendor (Apex, Global) and rows for each PR item (unit price), `Total Amount`, `Delivery Lead Time` and `Validity`. **Expect** Apex: `₹14.50`, `₹54,000.00`, total `₹1,09,450.00`, `5 days`; Global: `₹15.50`, `₹53,500.00`, total `₹1,08,550.00`, `12 days`. Only the `Total Amount` of the cheapest quote (Global) is green; unit prices are not highlighted.
  - Under **Quotation Details** there is one card per quotation. **Expect** the Global card has a `Lowest Quote` badge and neither card is selected yet. Each card lists its dates, lead time, line items (`100 × ₹14.50` = `₹1,450.00`, …), subtotal and total, and has a **Select this Quote** button at the bottom right.
  - On the Apex card tap **Select this Quote**. A dialog `Select QT/…?` opens with a `Selection reason *` field.
    - Tap **Select Quotation** with the field empty. **Expect** the dialog stays open with "A reason is required".
    - Enter `Shorter lead time of 5 days and local support warranty.` and tap **Select Quotation**.
  - **Expect** the Apex card gets a green border and a green `SELECTED` badge, shows `Reason: Shorter lead time of 5 days and local support warranty.`, and its button becomes **Create PO from Quote**. The Global card is unselected and still shows **Select this Quote**.

#### Purchase Orders (Inv-4)

- [ ] 1.3.14 Create PO from Selected Quotation:
  - On the Apex card tap **Create PO from Quote** (the PR screen's **Direct PO** creates a PO without a quotation; do not use it here).
  - **Expect** form pre-filled with Vendor `Apex Educational Supplies Ltd.`, Campus `Campus 31`, lines (`100` pens @ ₹14.50, `2` laptops @ ₹54,000.00), Subtotal ₹1,09,450.00.
  - Tax (₹): Enter amount `19701.00` (18% tax amount). Total updates to ₹1,29,151.00.
  - Expected Delivery Date: Next week (`YYYY-MM-DD`).
  - Delivery Terms: `Door delivery to Central Main Store`.
  - Tap **Save as draft**. **Expect** PO created with number `PO/<financialYear>/<seq>`, status `Draft`.
- [ ] 1.3.15 Issue and Acknowledge PO:
  - Open PO sheet → tap **Issue Purchase Order**.
  - **Expect** status changes to `Issued`; PR records ordered quantities.
  - Tap **Acknowledge** (supplier acknowledgement):
    - Enter Supplier Reference: `ACK-APEX-9921`.
    - Tap Save. **Expect** status updates to `Acknowledged`.
- [ ] 1.3.16 PO PDF Preview & Share:
  - Tap **Download / Share PDF**.
  - **Expect** system share sheet / PDF preview opens displaying formatted purchase order with institution header, PO Number, vendor details, line items, tax breakdown, and terms.
- [ ] 1.3.17 PO Revision with Audit Trail:
  - On PO sheet, tap **Revise PO**:
    - Revision reason *: `Negotiated educational volume discount on pens`
    - Update `PEN-BLU-01` unit price from `14.50` to `14.00`.
    - Tap **Save Revision**.
  - **Expect** revision incremented (`Rev 1`); status resets to `Issued`. Tap **Acknowledge** again with reference `ACK-APEX-9921-R1`.

#### PO Goods Receiving (GRN & Inspection) (Inv-5)

- [ ] 1.3.18 Partial Goods Receiving:
  - On PO sheet, tap **Receive goods**:
    - Destination store: Select `Central Main Store`.
    - Delivery note / Challan no.: `DC-APEX-7741`.
    - Line 1 (`PEN-BLU-01`): Enter Accepted: `80`, Rejected: `5`, Rejection condition: `5 broken tips during transit`.
    - Line 2 (`LAP-DELL-15`): Leave Accepted: `0`, Rejected: `0` (scheduled for next delivery).
    - Remarks: `First consignment received; 5 pens rejected at inspection.`
    - Tap **Confirm receiving (1 item)**.
  - **Expect**:
    - GRN generated (`GRN/<financialYear>/<seq>`).
    - PO status updates to `Partially received` (`in_delivery`).
    - `Central Main Store` stock balance of `PEN-BLU-01` increases by `80`.
    - Rejected count (5) logged in inspection records without entering available stock.
- [ ] 1.3.19 Negative: Exceeding Due Quantity:
  - On PO sheet, tap **Receive goods** again.
  - Remaining due for `PEN-BLU-01` is `15` (`100 ordered - 80 accepted - 5 rejected`).
  - Enter Accepted `25`.
  - **Expect** inline validation error: "Only 15 due".
- [ ] 1.3.20 Quick Action "Accept all due" & Full Receiving:
  - Start on the **Receive goods** screen of the same PO (open it again if you left it after 1.3.19). Clear the `25` typed in 1.3.19 first: tap **Clear quantities** (the clear-all icon next to **Accept all due**).
  - Tap **Accept all due** (above the line list). It fills every line that still has quantity due with that due quantity and clears Rejected:
    - Line 1 (`PEN-BLU-01`): Accepted becomes `15` (what is still due: `100 ordered - 80 accepted - 5 rejected`).
    - Line 2 (`LAP-DELL-15`): Accepted becomes `2` (nothing received yet, so all `2` ordered are due).
    - Rejected stays empty on both lines.
  - Select Destination store: `Central Main Store`. Enter Delivery note / Challan no.: `DC-APEX-7742`.
  - Tap **Confirm receiving (2 items)** (the number is the lines with an Accepted quantity).
  - **Expect**:
    - A second GRN is generated (`GRN/<financialYear>/<seq>`); the PO now lists two GRNs.
    - Nothing is due on any line, and the PO status becomes `Received` (`fully_received`).
    - The linked purchase request status becomes `Completed`.
    - `PEN-BLU-01` stock in `Central Main Store` rises by `15` (total `95`). `LAP-DELL-15` is asset-tracked, so it does not enter stock; register it in 1.4.1.

#### Vendor Invoices & Payment (Inv-5)

- [ ] 1.3.21 Record Vendor Invoice:
  - Open PO sheet for the received PO → tap **Record Invoice**:
    - **Expect** Vendor pre-filled as `Apex Educational Supplies Ltd.`, subtotal and tax pre-filled.
    - Enter Invoice Number: `INV-APEX-2026-104`.
    - Invoice Date: Today (`YYYY-MM-DD`).
    - Due Date: 30 days from today (`YYYY-MM-DD`).
    - Link Goods Receipts: Check both generated GRN chips.
    - Tap **Record Invoice**.
  - **Expect** Invoice saved with status `Unpaid`, outstanding equals total ₹1,29,033.00 (or matching PO total).
- [ ] 1.3.22 Negative: Duplicate Invoice Number per Vendor:
  - On the PO sheet, tap **Record Invoice** again with the identical Invoice Number `INV-APEX-2026-104`.
  - Tap Record Invoice. **Expect** rejected with error ("Invoice number already exists for this vendor").
- [ ] 1.3.23 Payment Recording & Status Transitions:
  - Open **Vendor invoices** from Inventory tiles. Tap the invoice card to open `InvoiceSheet`.
  - Tap **Update payment**:
    - Paid Amount: `50000.00`
    - Payment Reference: `NEFT/HDFC/9931023`
    - Tap Save. **Expect** payment status transitions to `Partially paid`; Outstanding updates.
  - Tap **Update payment** again → enter Paid Amount exceeding total. **Expect** rejected ("Paid amount cannot exceed invoice total").
  - Enter remaining balance. **Expect** status transitions to `Paid`; Outstanding becomes ₹0.00.
- [ ] 1.3.24 Negative: Cancellation Safeguards:
  - Try cancelling a `Paid` invoice. **Expect** cancellation prohibited / action disabled.
  - Cancel an `Unpaid` invoice. **Expect** invoice cancelled; status moves to `Cancelled`.

---

### 1.4 Assets (Inv-6)

Open **Assets** from Inventory tiles.

#### Asset Registration & PO Integration

- [ ] 1.4.1 **Asset Registration (Unit 1)**:
  - In Assets, tap FAB **Register asset**:
    - Asset item: Tap search and select `LAP-DELL-15` (`Dell Latitude 15 Core i5 Laptop`).
    - Store: Select `Central Main Store`.
    - Linked PO: Select `PO/<financialYear>/<seq>` (the PO received in step 1.3.20).
    - Asset Name: `Dell Latitude 15 - Admin 01`.
    - Serial Number: `DELL-SN-78491`.
    - Make: `Dell`, Model: `Latitude 3520`.
    - Location: `Admin Building Ground Floor - Room 102`.
    - Condition: `new`.
    - Purchase Date: Today (`YYYY-MM-DD`).
    - Purchase Price: `54000.00`.
    - Warranty: Start: Today, End: 3 years from today (`YYYY-MM-DD`).
    - Tap **Register asset**.
  - **Expect** Asset created with status `Available` (green pill), identifier `AST/<financialYear>/<seq>`. Linked PO and item code displayed on card.
- [ ] 1.4.2 **Asset Registration (Unit 2)**:
  - Register second asset for same item `LAP-DELL-15`:
    - Linked PO: Same `PO/...`.
    - Asset Name: `Dell Latitude 15 - Lab 01`.
    - Serial Number: `DELL-SN-78492`.
    - Store: `Science Lab Store`.
    - Make: `Dell`, Model: `Latitude 3520`.
    - Location: `Science Block 2nd Floor - Room 204`.
    - Condition: `new`.
    - Purchase Price: `54000.00`.
    - Tap **Register asset**. **Expect** Asset 2 registered with status `Available`.
- [ ] 1.4.3 Negative: PO Quantity Cap Enforcement:
  - Attempt to register a 3rd asset unit linked to the same PO.
  - **Expect** rejected with error (cannot register more asset units than the accepted quantity of 2 on the purchase order).

#### Asset Labels & Identification

- [ ] 1.4.4 **QR Code Label Generation**:
  - Open Asset 1 sheet → tap **Label** button.
  - **Expect** system share sheet / preview renders printable asset label with QR code encoding asset identifier (`AST/...`), serial number, item name, and school branding.
- [ ] 1.4.5 **RFID Tag Assignment & Uniqueness**:
  - Open Asset 1 sheet → tap **RFID tag**:
    - Enter RFID Tag: `RFID-LAP-001`. Tap Save. **Expect** RFID tag saved and shown on Asset 1 card.
  - Open Asset 2 sheet → tap **RFID tag**:
    - Enter identical RFID Tag: `RFID-LAP-001`. Tap Save.
    - **Expect** rejected with error ("RFID tag already assigned to another asset").
    - Enter unique RFID Tag: `RFID-LAP-002`. Tap Save. **Expect** saved.

#### Asset Custody Lifecycle (Assign, Transfer, Return)

- [ ] 1.4.6 **Custody Assignment**:
  - Open Asset 1 sheet → tap **Assign**:
    - Type: `Staff`
    - ERP ID: `884`.
    - Location: `Faculty Room 204`.
    - Expected return: End of current term (`YYYY-MM-DD`).
    - Tap **Save**.
  - **Expect** Asset status transitions to `Assigned` (blue pill); custodian displays Staff `884`; Custody section logs assignment record.
- [ ] 1.4.7 Negative: Assigning an Unavailable Asset:
  - On Asset 1 (currently `Assigned`), inspect action buttons.
  - **Expect** `Assign` button is hidden/disabled (only `Available` assets can be assigned).
- [ ] 1.4.8 **Custody Transfer (Handover)**:
  - Open Asset 1 sheet → tap **Transfer**:
    - Type: `Staff`
    - New ERP ID: `501`.
    - Location: `Physics Lab Prep Room`.
    - Tap **Save**.
  - **Expect** prior custody assignment for Staff `884` is closed; new active custody is opened for Staff `501`; custody history timeline shows complete audit trail.
- [ ] 1.4.9 **Return Asset with Damage**:
  - Open Asset 1 sheet → tap **Return**:
    - Condition: `Damaged`.
    - Location: `Central Main Store`.
    - Remarks: `Display backlight flickering; cracked hinge casing`.
    - Tap **Save**.
  - **Expect** Custody assignment closed; Asset status changes to `Damaged` (red pill); condition recorded as `Damaged`.

#### Asset Maintenance & Repair Workflow

- [ ] 1.4.10 **Report Fault**:
  - Open Asset 1 sheet → tap **Report fault**:
    - Issue *: `Screen hinge fracture and backlight repair`.
    - Priority: `High`.
    - Technician / service provider: `Apex Educational Supplies Ltd.`.
    - Tap **Save**.
  - **Expect** Maintenance ticket created (`MNT/<financialYear>/<seq>`); Asset status transitions to `Under maintenance` (amber pill).
- [ ] 1.4.11 Negative: Concurrent Maintenance Prevention:
  - On Asset 1, inspect action buttons.
  - **Expect** `Report fault` button is hidden while an active maintenance job is in progress.
- [ ] 1.4.12 **Move Maintenance to In-Progress**:
  - Open Maintenance view (from Assets app bar icon or Maintenance page).
  - Tap the maintenance ticket → update status to `in_progress`. Tap Save.
  - **Expect** maintenance status updates to `In Progress`.
- [ ] 1.4.13 **Complete Maintenance with Parts Consumption**:
  - On the maintenance job, tap **Complete**:
    - Technician: `Sunil Verma (Apex)`
    - Repair Details: `Hinge casing replaced; screen tested operational`.
    - Actual repair cost (₹): `4200.00`.
    - Post-repair condition: `Good`.
    - Spare parts: Tap **+ Add part** → select `PEN-BLU-01`, Store: `Central Main Store`, Quantity: `1`.
    - Tap **Save**.
  - **Expect**:
    - Maintenance ticket status moves to `Completed`.
    - Asset status restores to `Available` (green pill); condition updated to `Good`.
    - Store stock balance of spare part in `Central Main Store` is deducted by 1 unit.

#### Asset Retirement / Decommissioning

- [ ] 1.4.14 **Retire Asset**:
  - Open Asset 2 (`Dell Latitude 15 - Lab 01`).
  - Tap **Retire / dispose**:
    - Status: `Retired` (or `Disposed`).
    - Reason: `Damaged beyond economic repair; salvageable RAM removed`.
    - Tap **Save**.
  - **Expect** Asset status transitions to `Retired` (grey pill); asset is locked from custody assignments and maintenance; excluded from active valuation and store stock.

---

### 1.5 Verification, Scanning & Import (Inv-7, Inv-8)

#### Stock Verification & Reconciliation (Inv-7)

- [ ] 1.5.1 **Create Stock Verification Session**:
  - Open **Stock verification** from Inventory tiles.
  - Tap FAB **+ New**:
    - Store: Select `Central Main Store`.
    - Categories: Leave empty (whole store) or select `Stationery`.
    - Tap **Generate expected stock**.
  - **Expect** Verification session created (`STK/<financialYear>/<seq>`) with status `Counting`. Book balances are snapshotted (`PEN-BLU-01`, `MILK-PAST-01`, etc.).
- [ ] 1.5.2 **Physical Counting & Line Entry**:
  - Tap the verification session to open `VerificationPage`.
  - For `PEN-BLU-01`: Enter Counted: `56` (1 unit variance vs book balance `57`).
  - For `MILK-PAST-01`: Enter Counted matching current book balance.
  - Tap **Save counts**. **Expect** confirmation "Counts saved".
- [ ] 1.5.3 **Submit Verification**:
  - Tap **Submit** button at bottom.
  - **Expect** Session status moves to `Submitted`; pending review by inventory approver (`inventory.adjustment.approve`).
- [ ] 1.5.4 **Approver Review & Recount Workflow**:
  - Open session as Approver (`inventory.adjustment.approve`).
  - Tap **Send back**:
    - Reason: `Please recount stationery shelf B-3 for missing pen`.
    - Tap Confirm.
  - **Expect** Session status reverts to `Counting` for recount.
- [ ] 1.5.5 **Recount & Final Approval**:
  - In counting view, verify count and tap **Submit** again.
  - As Approver, tap **Approve**:
    - Dialog prompts: *"Apply adjustments?"*
    - Enter optional comment: `Variance approved after physical recount`.
    - Tap Confirm.
  - **Expect**:
    - Session status transitions to `Approved`.
    - Automatic stock adjustment movement is logged in `Central Main Store` ledger.
    - Available balance for `PEN-BLU-01` updates to the counted balance `56`.

#### Barcode & Code Scanning

- [ ] 1.5.6 **Item Code Scanning**:
  - In `VerificationPage` counting view, focus the scan input field at the top (`ScanField`).
  - Type item code `PEN-BLU-01` and press enter (simulating a barcode scan).
  - **Expect** the count for `PEN-BLU-01` increments by 1 with toast confirmation displaying item name and new count. **[EMU]**

#### Data Import (Inv-8)

- [ ] 1.5.7 **Catalog CSV Import**:
  - Open **Import** from Inventory tiles.
  - Select import kind: **Items**.
  - In the CSV text area, paste CSV with header:

    ```csv
    code,name,categoryCode,stockUnit,tracking,reorderLevel,defaultPrice
    NOTE-RULE-01,Ruled Notebook (200 pages),STA,pcs,quantity,20,45.00
    CALC-SCI-01,Scientific Calculator,INVALID_CAT,pcs,quantity,5,650.00
    PEN-BLU-01,Duplicate Blue Pen,STA,pcs,quantity,10,15.00
    ```

  - Tap **Run import**.
  - **Expect** row-level summary:
    - Row 1: `Success` (created in catalog).
    - Row 2: `Error: Category with code "INVALID_CAT" does not exist`.
    - Row 3: `Error: Item code "PEN-BLU-01" already exists`.
- [ ] 1.5.8 Negative: Idempotent Re-Import:
  - Tap Run import again with the same data.
  - **Expect** 0 imported; Row 1 now fails with duplicate code error; no duplicates created.

---

### 1.6 Dashboard and Reports (Inv-7)

#### Executive Dashboard

- [ ] 1.6.1 **Dashboard KPI Validation**:
  - Open **Dashboard** from Inventory tiles.
  - Switch store filter dropdown between **All Stores** and `Central Main Store`.
  - **Expect** 13 metric cards update dynamically:
    1. **Active items**: matches master items count.
    2. **Available stock**: reflects on-hand quantities.
    3. **Stock value**: reflects total financial worth based on unit costs.
    4. **Low-stock lines**: displays count `1` (`PEN-BLU-01` below reorder level `70`).
    5. **Out-of-stock lines**: displays count of depleted items.
    6. **Expiring in 30 days**: displays alert count for `MILK-PAST-01`.
    7. **Expired lines**: displays count of expired items.
    8. **Pending purchase requests**: displays pending PR count.
    9. **Pending approvals**: displays pending approval counts.
    10. **Open purchase orders**: displays active PO count.
    11. **Pending goods receipts**: displays POs awaiting delivery.
    12. **Registered assets**: displays registered assets count.
    13. **Assets under maintenance**: displays `0` (after completing step 1.4.13).

#### Reports Suite (All 17 Inventory Reports)

- [ ] 1.6.2 **Execute and Validate All 17 Inventory Reports**:
  - Open **Reports** from Inventory tiles. Open and verify each report:
    1. **Stock summary**: current on-hand, allocated, and available balances per item.
    2. **Item-wise stock**: item, store, batch, available, received, and issued totals.
    3. **Stock movement**: chronological movements (`receive`, `issue`, `return`, `transfer`, `adjust`) with timestamps and reference IDs.
    4. **Stock valuation**: unit cost and total value per balance; verify **Totals Row** at bottom.
    5. **Low stock**: items where available balance is below reorder level (`PEN-BLU-01`).
    6. **Expiry**: batch-tracked items sorted by earliest expiry date (`MILK-PAST-01`).
    7. **Purchase history**: fulfilled purchase orders with vendor names and amounts.
    8. **Vendors**: supplier register (Apex, Global) with codes, names, and active status.
    9. **Purchase requests**: requisitions with dates, numbers, statuses, and priorities.
    10. **Purchase orders**: orders with numbers, vendors, statuses, and total amounts.
    11. **Goods receiving**: GRN register with dates, sources, and line counts.
    12. **Issuance**: departmental consumption and staff issue records (`Staff 884`).
    13. **Transfers**: inter-store transfers with from/to stores, dates, and statuses.
    14. **Asset register**: serialized assets with asset IDs, serials, locations, and conditions.
    15. **Asset assignment**: staff custody history with assigned/returned dates and closed status.
    16. **Maintenance**: maintenance tickets with numbers, asset codes, statuses, and repair costs.
    17. **Stock verification**: audit sessions with stores, line counts, and differences.
- [ ] 1.6.3 **Report Export (CSV & PDF)**:
  - On **Stock valuation** and **Stock movement** reports:
    - Tap **Copy CSV** → **Expect** formatted CSV copied to clipboard.
    - Tap **PDF** (or print action) → **Expect** PDF viewer opens with structured tabular layout and formatted currency totals.

---

### 1.7 Permissions & Cross-Campus Security (Inventory)

Edit permissions in `schools/<schoolId>/userAccess/<uid>` via Emulator UI (or sign in as matching role):

- [ ] 1.7.1 **Role: `teacher`**:
  - Set permissions: `inventory.issue.request`, `inventory.purchaseRequest.request`, `inventory.assets.view`.
  - Restart / reload app.
  - **Expect**: Only Issue requests, Purchase requests, and Assets tiles are visible. Stores, Stock management, Vendors, Quotations, Invoices, and Reports are hidden.
- [ ] 1.7.2 **Role: `storekeeper`**:
  - Set permissions: `inventory.items.view`, `inventory.stock.view`, `inventory.stock.operate`, `inventory.issue.request`, `inventory.purchaseRequest.request`, `inventory.assets.manage`, `inventory.assets.view`.
  - **Expect**: Full operational access to Stock (Receive, Issue, Transfers, Damaged/Expired, Verification). Vendor management, Quotation selection, PO creation, and Invoices are hidden.
- [ ] 1.7.3 **Role: `procurement`**:
  - Set permissions: `inventory.items.view`, `inventory.stock.view`, `inventory.purchaseRequest.request`, `inventory.procure.operate`, `inventory.vendors.manage`, `inventory.assets.view`.
  - **Expect**: Full access to Vendors, Purchase requests, Quotations, POs, and Invoices. Prohibited from executing physical store receipts, stock issues, or manual balance adjustments.
- [ ] 1.7.4 **Campus Isolation**:
  - In `userAccess/<uid>`, set `campusIds: [32]` (Campus 32 only) and `hasAllCampuses: false`.
  - Open Stock Overview.
  - **Expect**: Only Campus 32 stores (`Science Lab Store`) and records are visible. Campus 31 stores (`Central Main Store`) are excluded.

---

## Part 2 – Library

Open **Library** from the dashboard. The Library hub displays 15 option grid tiles: Dashboard, Catalogue, Copies, Categories, Libraries, Circulation, Reservations, Members, Borrowing policies, Fines & Penalties, Lost & Damaged, Transfers, Stock verification, Reports, Import.

### 2.1 Masters (Lib-1)

#### Library Facilities Master

- [ ] 2.1.1 **Libraries** → tap FAB **+ Library** to add Library 1:
  - Library Code: `L1`
  - Library Name: `Central High School Library`
  - Campus: `Campus 31`
  - Location: `Academic Block A, 1st Floor`
  - Hours: `08:00 - 17:00`
  - Staff IDs: `884`
  - Tap **Save**. **Expect** Library 1 created with Active status chip.
- [ ] 2.1.2 Add Library 2:
  - Library Code: `L2`
  - Library Name: `Junior School Library`
  - Campus: `Campus 32`
  - Location: `Primary Wing Ground Floor`
  - Hours: `08:30 - 15:30`
  - Tap **Save**. **Expect** Library 2 created.

#### Classification Categories

- [ ] 2.1.3 **Categories** → tap empty-state seed button (or view seeded categories).
  - **Expect** 14 standard classification categories created:
    - Code `FIC`: `Fiction`
    - Code `NFC`: `Non-fiction`
    - Code `SCI`: `Science`
    - Code `MAT`: `Mathematics`
    - Code `HIS`: `History`
    - Code `GEO`: `Geography`
    - Code `LIT`: `Literature`
    - Code `LNG`: `Languages`
    - Code `REF`: `Reference`
    - Code `ENC`: `Encyclopedias`
    - Code `BIO`: `Biographies`
    - Code `CHL`: `Children's books`
    - Code `TXT`: `Textbooks`
    - Code `GKN`: `General knowledge`
- [ ] 2.1.4 Negative: Category Deactivation Protection:
  - On category `HIS` (`History`), toggle Active switch off.
  - Try to create a catalogue title under category `HIS`.
  - **Expect** inactive category is excluded from selection or creation is rejected. Reactivate category `HIS`.

#### Title Catalogue Management

- [ ] 2.1.5 **Catalogue** → tap FAB **+ Book** to add Title 1:
  - Title: `Wings of Fire: An Autobiography`
  - Authors: `A.P.J. Abdul Kalam, Arun Tiwari` (comma-separated)
  - Category: `History` (`HIS`)
  - Publisher: `Universities Press`
  - Edition: `1st Edition`
  - Publication Year: `1999`
  - ISBN-13: `9788173711466` (valid check digit)
  - Tap **Save**. **Expect** Title saved and listed in catalogue.
- [ ] 2.1.6 Add Title 2:
  - Title: `Pride and Prejudice`
  - Authors: `Jane Austen`
  - Category: `Fiction` (`FIC`)
  - Publisher: `Penguin Classics`
  - Publication Year: `2003`
  - ISBN-13: `9780141439518`
  - Tap **Save**. **Expect** Title saved.
- [ ] 2.1.7 Add Title 3 (Without ISBN):
  - Title: `School Annual Magazine 2025-26`
  - Authors: `Editorial Board`
  - Category: `Non-fiction` (`NFC`)
  - ISBN-13: Leave blank
  - Tap **Save**. **Expect** Title saved successfully without ISBN.
- [ ] 2.1.8 Negative: Duplicate ISBN-13:
  - Add another title with the identical ISBN-13 `9788173711466`.
  - **Expect** rejected with error ("A title with this ISBN-13 already exists in catalogue").
- [ ] 2.1.9 Negative: Invalid ISBN-13 Check Digit:
  - Attempt to add a title with invalid check digit `9788173711460`.
  - **Expect** rejected with validation error ("Invalid ISBN-13 check digit").
- [ ] 2.1.10 **Catalogue Search**:
  - In Catalogue search bar, search `kalam` or `wings`. **Expect** "Wings of Fire" is returned.
  - Search exact ISBN `9780141439518`. **Expect** "Pride and Prejudice" is returned.

---

### 2.2 Copies & Acquisition (Lib-2)

#### Acquisition & Copy Generation

- [ ] 2.2.1 **Acquire Copies for Title 1 ("Wings of Fire")**:
  - Open "Wings of Fire" details → scroll to Physical Copies section → tap **Acquire copies**:
    - Acquisition Type: `Purchase`
    - Target Library: `Central High School Library` (`L1`)
    - Quantity: `3`
    - Unit Price: `320.00`
    - Vendor / donor: `Apex Educational Supplies Ltd.`
    - Invoice / Reference: `INV-BOOK-2026-01`
    - Shelf: `Shelf A-12 / Bay 2`
    - Condition: `good`
    - Tap **Save**.
  - **Expect**:
    - Three physical copies created with sequential accession numbers: `ACC-000001`, `ACC-000002`, `ACC-000003`.
    - All 3 copies have status `Available` (green pill).
    - SnackBar offers "Print labels" action.
- [ ] 2.2.2 **Acquire Copy for Title 2 ("Pride and Prejudice")**:
  - Open "Pride and Prejudice" details → tap **Acquire copies**:
    - Library: `Central High School Library` (`L1`)
    - Quantity: `1`
    - Unit Price: `280.00`
    - Shelf: `Shelf F-03`
    - Tap **Save**.
  - **Expect** Copy created with accession number `ACC-000004`, status `Available`.

#### Copy Attributes, RFID & Spine Labels

- [ ] 2.2.3 **Shelf Location & RFID Assignment**:
  - In Copies list (or from Book Details copies section), tap copy `ACC-000001` to open `CopySheet`:
    - RFID tag: `RFID-BK-0001`
    - Remarks: `Curriculum reference copy`
    - Tap **Save**. **Expect** copy updated.
- [ ] 2.2.4 Negative: Duplicate RFID Tag:
  - Open Copy sheet for `ACC-000002` → enter identical RFID `RFID-BK-0001`. Tap Save.
  - **Expect** rejected with error ("RFID tag already assigned to another copy").
  - Enter unique RFID: `RFID-BK-0002`. Tap Save. **Expect** saved.
- [ ] 2.2.5 **Print Spine & Barcode Labels**:
  - On copy `ACC-000001` sheet, tap **Print label** (or share labels action).
  - **Expect** printable label preview renders accession barcode, call number, title, and library code.
- [ ] 2.2.6 **Inter-Library Copy Move**:
  - Open Copy `ACC-000003` ("Wings of Fire").
  - Tap **Move library** → select `Junior School Library` (`L2`). New shelf: `Junior Shelf J-04`.
  - Tap confirm. **Expect** copy's library updates to `L2`; appears in `L2` copy inventory.
- [ ] 2.2.7 **Copy Maintenance State Transitions**:
  - Open Copy `ACC-000002` → tap **Change status** → select `under_maintenance`.
  - **Expect** status transitions to `Under maintenance` (amber); copy is excluded from available loans.
  - Tap **Change status** → select `available`. **Expect** status restored to `Available`.

---

### 2.3 Members & Borrowing Policies (Lib-3)

#### Borrowing Rules & Policies

- [ ] 2.3.1 **Create Primary Student Policy**:
  - Open **Borrowing policies** → tap FAB **+ Policy**:
    - Library: `Central High School Library` (`L1`)
    - Member category: `primary`
    - Policy name: `Primary Student Policy`
    - Max books allowed: `2`
    - Loan period in days: `7`
    - Max renewals: `1`
    - Fine type: `per_day`
    - Rate per day (₹): `2.00`
    - Grace days: `0`
    - Can reserve titles: switch ON (`true`)
    - Tap **Save**. **Expect** Policy created for `L1` · `primary`.
- [ ] 2.3.2 **Create Teacher Policy**:
  - Add Policy 2:
    - Library: `Central High School Library` (`L1`)
    - Member category: `teacher`
    - Policy name: `Teacher Borrowing Policy`
    - Max books allowed: `5`
    - Loan period in days: `30`
    - Max renewals: `2`
    - Fine type: `none`
    - Grace days: `3`
    - Can reserve titles: switch ON (`true`)
    - Tap **Save**. **Expect** Policy created for `L1` · `teacher`.
- [ ] 2.3.3 Negative: Validation:
  - Create policy with Fine type `per_day` and empty or negative fine rate.
  - **Expect** blocked with validation error.

#### Member Enrollment

- [ ] 2.3.4 **Enrol Students**:
  - Open **Members** → tap FAB **+ Member**:
    - Member Type: `Student`
    - ERP ID: `501`
    - Member Category: `primary`
    - Library assignment: Tap `Central High School Library` chip
    - Start Date: Today (`YYYY-MM-DD`)
    - Tap **Save**.
  - Enrol Student 2 (ERP ID `502`, category `primary`, library `L1`).
  - Enrol Student 3 (ERP ID `503`, category `primary`, library `L1`).
  - **Expect** All 3 students enrolled with status `Active`, category `primary`, showing 0 active loans.
- [ ] 2.3.5 **Enrol Staff / Teacher**:
  - Enrol Teacher: Member Type: `Teacher`, ERP ID `884`, Category: `teacher`, Library: `L1`.
  - **Expect** Enrolled with matching teacher policy.
- [ ] 2.3.6 **Member Status & Search**:
  - Search member by ERP ID `501`. **Expect** Student 501 profile returned.
  - Edit Member 503 → toggle Active off. **Expect** status shows `Inactive`; attempts to issue books are rejected. Reactivate Member 503.

---

### 2.4 Circulation (Loans, Renewals, Returns) (Lib-4)

Open **Circulation** from Library tiles.

#### Book Issuance

- [ ] 2.4.1 **Issue Book to Student 501**:
  - Member type toggle: `Student`
  - ERP ID: Enter `501`
  - In the field **"Scan book to ISSUE to this member"**, enter or scan accession number `ACC-000001` ("Wings of Fire").
  - Press enter / confirm.
  - **Expect**:
    - Toast confirmation: `ACC-000001 issued`.
    - Active loan appears in the loans list below showing `ACC-000001 · Student #501`, due in 7 days.
    - Copy `ACC-000001` status transitions from `Available` to `Issued` (blue pill).
    - Outbox records notification event `library-issued__...`.
- [ ] 2.4.2 **Issue Second Book to Student 501**:
  - With ERP ID `501` selected, enter `ACC-000004` ("Pride and Prejudice") in the issue scan field.
  - **Expect** Issue succeeds; Student 501 active loan count becomes `2` (reaching the policy limit).
- [ ] 2.4.3 Negative: Borrowing Quota Limit Exceeded:
  - Attempt to issue Copy `ACC-000002` to Student 501.
  - **Expect** rejected with error ("Member has reached maximum borrowing limit of 2 books").
- [ ] 2.4.4 Negative: Issuing an Already Issued Copy:
  - With ERP ID set to `502`, enter `ACC-000001` into the issue scan field.
  - **Expect** rejected with error ("Copy is currently issued and unavailable").

#### Loan Renewal

- [ ] 2.4.5 **Renew Active Loan**:
  - Tap the loan card for `ACC-000001` (or enter `ACC-000001` in "Scan book to RETURN or RENEW") to open `LoanSheet`.
  - Tap **Renew** button.
  - **Expect** Due date advances by 7 days; loan sheet shows `Renewed 1 of 1`.
- [ ] 2.4.6 Negative: Renewal Limit Reached:
  - On the same loan sheet, check the Renew button.
  - **Expect** `Renew` button is disabled (renewals reached policy max limit of 1).

#### Book Returns

- [ ] 2.4.7 **Return Book in Good Condition**:
  - Open `LoanSheet` for `ACC-000004` ("Pride and Prejudice").
  - Enter optional return remarks: `Returned on time in clean condition`.
  - Tap **Return** button.
  - **Expect**:
    - Loan is closed and removed from active loans list.
    - Copy `ACC-000004` status restores to `Available`.
    - Student 501 active loans count drops from `2` to `1`.
    - Outbox records notification `library-returned__...`.

---

### 2.5 Reservations & Hold Queue (Lib-5)

Setup: Copy `ACC-000001` is currently on loan to Student 501. No other copies of "Wings of Fire" are available at Library `L1` (Copy 2 is under maintenance/quarantined, Copy 3 was moved to `L2`).

- [ ] 2.5.1 **Queue Reservation 1 (Student 502)**:
  - Open Catalogue → open "Wings of Fire" details → tap AppBar bookmark icon (tooltip: "Reserve book"):
    - Member type: `Student`
    - ERP ID: `502`
    - Library: `Central High School Library` (`L1`)
    - Tap **Reserve book**.
  - **Expect** Reservation created with status `Waiting`; Queue Position is `1`.
- [ ] 2.5.2 **Queue Reservation 2 (Student 503)**:
  - Open **Reservations** from Library tiles → tap FAB **New reservation**:
    - Member type: `Student`, ERP ID: `503`
    - Select Book: `Wings of Fire`
    - Library: `Central High School Library` (`L1`)
    - Tap **Reserve book**.
  - **Expect** Reservation created with status `Waiting`; Queue Position is `2`.
- [ ] 2.5.3 Negative: Reserving a Title with Available Shelf Copies:
  - Attempt to place a reservation on "Pride and Prejudice" (which has available copy `ACC-000004`).
  - **Expect** rejected with error ("Reservations cannot be placed while shelf copies are available in this library").
- [ ] 2.5.4 Negative: Duplicate Active Reservation:
  - Attempt to place another reservation for Student 502 on "Wings of Fire".
  - **Expect** rejected with error ("Member already has an active reservation for this title").
- [ ] 2.5.5 **Fulfill Reservation on Return (Hold Activation)**:
  - In Circulation, return copy `ACC-000001` (issued to Student 501) by entering `ACC-000001` in the Return/Renew field → tap **Return**.
  - **Expect**:
    - Copy status does NOT become available to general circulation; status transitions to `Reserved` (purple pill).
    - Student 502's reservation status changes from `Waiting` to `Ready`.
    - Hold Expiry Date is automatically set to Today + 3 days.
    - Outbox records notification `library-rsv-ready__...` notifying Student 502.
- [ ] 2.5.6 Negative: Issuing a Held Copy to Another Member:
  - In Circulation, set ERP ID to `503` (queue position 2). Enter held copy `ACC-000001` in issue field.
  - **Expect** rejected with error ("Copy is currently held on reservation for Member 502").
- [ ] 2.5.7 **Issue Held Copy to Target Member**:
  - In Circulation, set ERP ID to `502`. Enter `ACC-000001` in issue field.
  - **Expect** Issue allowed; reservation status updates to `Fulfilled`; Student 502 has active loan.
- [ ] 2.5.8 **Reservation Cancellation**:
  - Open **Reservations** → tap Student 503's waiting reservation → tap **Cancel reservation**.
  - **Expect** Reservation status moves to `Cancelled`.
- [ ] 2.5.9 **Hold Expiry Job [JOB]**:
  - For a reservation in `Ready` status whose hold date has passed, execute `runHoldExpiry`.
  - **Expect** Reservation status transitions to `Expired`; copy re-allocates to next member in queue or reverts to `Available`.

---

### 2.6 Fines, Penalties, Lost & Damaged Incidents (Lib-6)

#### Overdue Fine Calculation & Enforcement

- [ ] 2.6.1 **Overdue Fine Generation**:
  - In Emulator Firestore UI, locate loan for `ACC-000001` (issued to Student 502): edit `dueDate` to 3 days in the past (`today - 3 days`).
  - In Circulation, scan `ACC-000001` into Return/Renew field → tap **Return**.
  - **Expect**:
    - Overdue fine generated: 3 days × ₹2.00/day = `₹6.00`.
    - Fine record created with status `Outstanding` (`outstanding` = `₹6.00`).
    - Member Student 502 is flagged as blocked due to unpaid fines.
    - Outbox records notification event `library-fine__...`.
- [ ] 2.6.2 Negative: Blocked Member Borrowing Prevention:
  - Attempt to issue any book to Student 502 in Circulation.
  - **Expect** rejected with error ("Member is blocked due to outstanding unpaid fines").

#### Fine Waivers & Payments

- [ ] 2.6.3 **Partial Fine Waiver**:
  - Open **Fines & Penalties** from Library tiles → tap Student 502's ₹6.00 fine to open `FineSheet`.
  - Tap **Waive fine**:
    - Amount to waive (₹): `3.00`
    - Reason for waiver: `Medical illness leave with certificate`
    - Tap **Confirm waive**.
  - **Expect** Fine status updates to `Partially paid`; Outstanding drops to `₹3.00`; member remains blocked.
- [ ] 2.6.4 **Fine Payment Collection**:
  - On the same fine sheet, tap **Record fine payment**:
    - Paid amount (₹): `3.00`
    - Payment receipt / reference: `RCP-LIB-2026-441`
    - Tap **Record payment**.
  - **Expect** Fine status updates to `Paid`; Outstanding becomes `₹0.00`; Student 502 status is automatically unblocked.

#### Damaged and Lost Incidents

- [ ] 2.6.5 **Return Copy as Damaged**:
  - Issue copy `ACC-000004` to Student 501.
  - Open loan sheet for `ACC-000004` → enter remarks `Water stains and ripped pages from chapter 3` → tap **Return damaged**.
  - **Expect**:
    - Incident ticket created (`INC/<financialYear>/<seq>`); status is `Reported`, type `damaged`.
    - Copy status transitions to `Damaged` (red pill); removed from circulation.
- [ ] 2.6.6 **Resolve Damaged Incident**:
  - Open **Lost & Damaged** from Library tiles → tap incident for `ACC-000004` to open `IncidentSheet`.
  - Tap **Resolve incident**:
    - Resolution: `Repaired (return to shelf)`
    - Repair cost (₹): `150.00`
    - Resolution remarks: `Rebound and dried by bookbinder`
    - Tap Confirm.
  - **Expect** Incident status marked `Resolved`; Copy status restored to `Available`.
- [ ] 2.6.7 **Mark Book as Lost**:
  - Issue copy `ACC-000004` to Student 501.
  - Open loan sheet → tap **Mark lost**:
    - Reason for loss: `Misplaced during inter-school tour`
    - Replacement charge (₹): `350.00`
    - Tap **Confirm lost**.
  - **Expect** Loan closed with status `Lost`; Copy status marked `Lost`; fine of `₹350.00` assessed against Student 501; member blocked pending settlement.

---

### 2.7 Inter-Library Transfers & Verification (Lib-7)

#### Inter-Library Transfers

- [ ] 2.7.1 **Request Inter-Library Transfer**:
  - Open **Transfers** from Library tiles → tap FAB **New transfer**:
    - In the scan field, scan or enter accession no. `ACC-000001` (From library auto-populates as `Central High School Library`; with one eligible library it is pre-selected).
    - To library: Select `Junior School Library` (`L2`). The From library is not offered.
    - Scan a copy from another library or an issued copy. **Expect** a message naming why it was refused.
    - Remarks: `Required for Class 8 literature workshop`.
    - Tap **Request transfer**.
  - **Expect** the screen closes; the list shows `LTR/<financialYear>/<seq>` with status `Requested`.
- [ ] 2.7.2 **Approve and Dispatch Transfer**:
  - Tap the transfer card to open the transfer screen (a card with `Needs your approval` is waiting on you):
    - Tap **Approve transfer** and confirm (requires `library.settings`). Status becomes `Approved`.
    - Tap **Dispatch copies** and confirm (requires `library.catalogue` on the source campus).
  - **Expect** the progress strip reaches `In transit`; copy `ACC-000001` marked `In Transit`.
- [ ] 2.7.3 Negative: Issuing an In-Transit Copy:
  - In Circulation, attempt to issue `ACC-000001` while in transit.
  - **Expect** rejected with error ("Copy is currently in transit between libraries").
- [ ] 2.7.4 **Receive Transfer at Destination Library**:
  - Open the transfer as a receiving librarian (`L2` campus; card shows `Confirm receipt on arrival`).
  - Copies are ticked by default; set `ACC-000001` condition (Good / Fair / Poor), optionally enter a shelf and remarks.
  - Tap **Confirm receipt (1)**.
  - **Expect** Transfer marked `Received`; copy `ACC-000001` now belongs to `L2` with the chosen condition and is available for circulation at `L2`. Unticking a copy leaves it in transit (`Partly received`) and it can be received later.
- [ ] 2.7.4a **Filters and visibility**:
  - Use the status chips on the Transfers list. **Expect** the list narrows and an empty filter offers **Show all transfers**.
  - As a librarian limited to one campus, **Expect** both outgoing and incoming transfers are listed.

#### Library Stock Verification

- [ ] 2.7.5 **Initiate Library Stock Verification**:
  - Open **Stock verification** from Library tiles → tap FAB **New verification**:
    - Library: Select `Central High School Library` (`L1`).
    - Shelf: Leave blank (whole library) or enter shelf code.
    - Tap **Start counting**.
  - **Expect** Session created (`STK/...`); status `Counting`. Active loans are flagged as on loan and excluded from shelf discrepancies.
- [ ] 2.7.6 **Barcode Scanning & Reconciliation**:
  - In `VerificationSheet`, scan expected accession numbers into the scan field.
  - Scan an unexpected copy (e.g. belonging to `L2`).
  - Leave one shelf copy unscanned (simulating a missing book).
  - Tap **Submit count**. Status moves to `Submitted`.
  - Review corrections (as user with `library.settings`):
    - Under Missing: tick checkbox **"Mark as lost"** for missing copy (unticked copies stay recorded for investigation).
    - Under Unexpected: tick checkbox **"Move into this library"**.
    - Tap **Approve corrections**.
  - **Expect** Session status becomes `Approved`; copy records and catalogue counts update accordingly.

---

### 2.8 Dashboard, Reports, Import & Automation (Lib-8)

#### Library Executive Dashboard

- [ ] 2.8.1 **Dashboard KPI Validation**:
  - Open **Dashboard** from Library tiles. Toggle between **All Libraries** and `Central High School Library`.
  - **Expect** 12 KPI cards match database counts:
    1. **Book titles**: catalogue titles count.
    2. **Physical copies**: total copies across selected scope.
    3. **Available copies**: copies currently on shelf.
    4. **Issued copies**: books currently on loan.
    5. **Overdue books**: loans past their due date.
    6. **Reserved books**: waiting and held reservations.
    7. **Lost books**: copies marked lost.
    8. **Damaged books**: copies in damaged state.
    9. **Active student members**: enrolled active students.
    10. **Active teacher members**: enrolled active teachers.
    11. **Pending returns**: loans due today.
    12. **Outstanding fines**: total uncollected fines balance (₹).

#### Reports Suite (All 15 Library Reports)

- [ ] 2.8.2 **Execute and Validate All 15 Library Reports**:
  - Open **Reports** from Library tiles. Open each report and verify table columns:
    1. **Book catalogue**: titles, authors, publishers, editions, years, ISBNs, categories.
    2. **Accession register**: accession numbers, titles, libraries, shelves, acquired dates, prices.
    3. **Library stock**: accession numbers, titles, shelves, statuses, conditions.
    4. **Available books**: copies currently available on shelf.
    5. **Issued books**: active loans, members, titles, accession numbers, issue/due dates.
    6. **Overdue books**: active loans past due date, days overdue count.
    7. **Member history**: historical issue, due, and return dates with statuses.
    8. **Fine report**: fine numbers, members, types, amounts, waived, paid, outstanding.
    9. **Lost books**: incident tickets, accession numbers, titles, charges.
    10. **Damaged books**: incident tickets, severity, repair status, incident status.
    11. **Acquisition report**: dates, numbers, sources (purchase/donation), copies count, prices.
    12. **Transfer report**: transfers log with from/to libraries, copies count, statuses.
    13. **Verification report**: audit sessions, shelves, expected, missing, unexpected counts.
    14. **Popular books**: titles ranked by borrowing frequency in period.
    15. **Inactive books**: titles with copies but zero loans in period.
- [ ] 2.8.3 **Export Capabilities**:
  - On **Accession register** and **Fine report**:
    - Tap **Copy CSV** → **Expect** formatted CSV copied to clipboard.
    - Tap **PDF** (or print action) → **Expect** PDF preview renders with library header and totals.

#### Batch Import (CSV)

- [ ] 2.8.4 **Import Catalogue CSV**:
  - In **Import** from Library tiles, select **Catalogue**.
  - Paste CSV with header:

    ```csv
    title,authors,categoryCode,isbn13,publisher,year
    Discovery of India,Jawaharlal Nehru,HIS,9780143031031,Penguin,2004
    Modern Physics,H.C. Verma,INVALID_CAT,9788177091878,Bharti,2018
    Wings of Fire: An Autobiography,A.P.J. Abdul Kalam,HIS,9788173711466,Universities Press,1999
    ```

  - Tap **Run import**.
  - **Expect** summary shows 1 of 3 imported:
    - Row 1: `Success`
    - Row 2: `Error: Category code 'INVALID_CAT' does not exist`
    - Row 3: `Error: Title with this ISBN-13 already exists`
- [ ] 2.8.5 **Import Copies CSV**:
  - Select **Copies** import.
  - Paste CSV:

    ```csv
    isbn13,libraryCode,quantity,price,shelf,condition,date
    9780143031031,L1,2,400.00,Shelf H-01,good,2026-01-15
    ```

  - Tap **Run import**.
  - **Expect** Accession numbers generated and copies created as `Available`.

#### Scheduled Notification Automation [JOB]

- [ ] 2.8.6 **Execute `runDailyLibrary`**:
  - Trigger scheduled library callable.
  - **Expect**:
    - Loans due in 2 days receive `library-due-soon__...` outbox event.
    - Overdue loans past due date receive `library-overdue__...__<date>` outbox event.
    - Memberships expiring within 7 days receive `library-member-expiring__...`.
    - Reservation holds expiring within 24 hours receive `library-rsv-expiring__...`.
    - Re-executing on the same day produces no duplicate outbox events.

---

### 2.9 Permissions & Role Security (Library)

Edit permissions in `schools/<schoolId>/userAccess/<uid>`:

- [ ] 2.9.1 **Role: `teacher`** (no Library permissions):
  - Set permissions: none of `library.*`.
  - Restart / reload app.
  - **Expect**: No Library tile and no Library data readable.
- [ ] 2.9.2 **Catalogue only**:
  - Set permissions: `library.catalogue`.
  - **Expect**: Catalogue, Copies, Categories, Libraries, Transfers, Stock verification, Import tiles; Circulation, Members, Borrowing policies, Fines, Incidents and Reports are hidden.
- [ ] 2.9.3 **Role: `librarian` (Campus Scoping)**:
  - In `userAccess/<uid>`, set `campusIds: [32]` (Campus 32 only) and `hasAllCampuses: false`.
  - **Expect**: Library views and circulation default to `Junior School Library` (`L2`); queries exclude Campus 31 (`L1`) loans and copies.

---

## Part 3 – Cross-cutting

- [ ] 3.1 **Idempotency**: Double-tap any save/issue/return button. **Expect** one record only created.
- [ ] 3.2 **Connection handling**: Stop the emulator mid-action, then act. **Expect** clear error prompt, no half-saved or corrupted state.
- [ ] 3.3 **Empty states**: Open any master, stock, circulation, or report list with no data. **Expect** clean empty state with icon and message, no infinite spinner or crash.
- [ ] 3.4 **Audit logging**: Every mutation via Cloud Functions creates a corresponding record in `schools/<schoolId>/auditLogs`.
- [ ] 3.5 **Automated test suite**: `melos run firebase:test` passes with all functions and rules tests green.
