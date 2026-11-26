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
  - Inventory: `inventory.settings`, `inventory.items.manage`, `inventory.items.view`, `inventory.stock.view`, `inventory.stock.operate`, `inventory.issue.request`, `inventory.issue.approve`, `inventory.adjustment.approve`, `inventory.purchaseRequest.request`, `inventory.purchaseRequest.approve`, `inventory.procure.operate`, `inventory.assets.manage`, `inventory.assets.view`, `inventory.reports.view`.
  - Library: none; any non-parent staff user with the Library tile can do everything.
- **Role Verification (Part 1.7 / 2.9)**: To simulate specific roles (e.g. `storekeeper`, `procurement`, `teacher`, `librarian`), edit the `permissions` array directly in the Emulator UI document or sign in as a user with that role.

### 0.3 Run the app

Launch config **icueadmin [Dev + Emulators · Android]** (or iOS). It signs in with a locally built unsigned token. Open Emulator UI → Firestore → `schools/<schoolId>/userAccess/<your uid>`.

- [ ] 0.3.1 `permissions` is non-empty, `campusIds` lists your campus IDs (or `hasAllCampuses: true`). **Expect** the Dashboard shows Inventory and Library tiles.

### 0.4 Test data you will use

- Campuses: `31` and `32` (or your school's actual campus IDs).
- Person IDs: ERP student IDs `501`, `502`, `503`; ERP staff/teacher IDs `884` (yours), `501` (second staff).

### 0.5 Scheduled jobs

`dailyInventory` and `dailyLibrary` do not run by themselves in the emulator. Steps tagged **[JOB]** can only be checked once triggered. Skip those steps for now and mark them blocked if a scheduled job runner is not invoked.

### 0.6 What to watch in the Emulator UI during the run

- `schools/<schoolId>/auditLogs`: one entry per cloud callable mutation.
- `schools/<schoolId>/outbox`: notification events queued for delivery. (Push notifications are not dispatched to real FCM in emulator **[EMU]**).
- Idempotency: repeating actions (e.g. double-tapping save) uses `requestId` deduplication so duplicate records are not created.

---

## Part 1 – Inventory

Open **Inventory** from the dashboard. The Inventory hub shows 12 option grid tiles: Dashboard, Import, Reports, Items, Categories, Units, Stock, My requests, Issue requests, Purchase requests, Assets, Stores.

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
- [ ] **Expect** `LAP-DELL-15` does NOT appear in the item picker (asset-tracked items are managed through the Assets module, and are excluded from direct stock receive).

#### 1.2.5 Create Issue Request (Requisition)

- [ ] As a requester (`inventory.issue.request`), open **My requests** (only your own requests are listed) → tap FAB **New request**:
  - Issue from store: `Central Main Store`
  - Purpose: `Exam Hall Supplies for Midterms`
  - Destination: `Main Exam Hall - Block A`
  - Line items: Tap **+ Add item** → select `PEN-BLU-01`, Quantity: `30`.
  - Tap **Submit request**.
- [ ] **Expect** request created with number `ISR/<financialYear>/<seq>`. Status is `Pending`. Appears under `All` and `Pending` filter chips with count badge `1`.

#### 1.2.6 Approve Issue Request

- [ ] As Approver (`inventory.issue.approve`), open **Issue requests** (all campus requests, no **New request** button) and tap the pending request card.
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

### 1.3 Purchase requests

A store manager (or branch admin) raises a request for one store; there is no approval. The goods are bought offline and recorded on the request as they arrive. Store managers see only their stores' requests; admins see all.

- [ ] 1.3.4 **Purchase requests** → tap FAB **+ New request**:
  - Store: `Central Main Store` (hidden for a store manager with one store)
  - Priority: `High`
  - Purpose: `Annual Examination & Office Supplies Requisition`
  - Required by date: One week from today
  - Line 1: **Add Item to Request** → `PEN-BLU-01` (only the chosen store's items are listed). Quantity: `120`.
  - Line 2: **Add Item to Request** → `LAP-DELL-15` (asset item). Quantity: `5`. There is no price on a request.
  - Tap **Create request**. **Expect** number `PR/<financialYear>/<seq>`, status `Open`, History `Created`. The Overview's **Open purchase requests** goes up by 1.
- [ ] 1.3.5 Edit before anything arrives: open PR 1 → **Edit** → `PEN-BLU-01` quantity `100` → **Save changes**. **Expect** the line shows 100 and History `Edited`. The store cannot be changed.
- [ ] 1.3.6 Record a delivery: open PR 1 → **Receive goods**.
  - `PEN-BLU-01`: Received in good condition `60`, Damaged `5`. `LAP-DELL-15`: Received `2`.
  - Entering more than is pending (e.g. Damaged `50` for the pen) shows `Only … pending`.
  - Tap **Confirm receipt**. **Expect** status `Partially received`; pen line `Received 60 pcs · damaged 5 pcs · pending 35 pcs`; laptop `Received 2 · pending 3`; History `Goods received` per delivery. There is no unit cost on the receipt.
  - **Stock**: `PEN-BLU-01` in Central Main Store gains 60 available (valued at its default price, ₹15) and 5 damaged. **Assets → Unregistered** lists 2 new `LAP-DELL-15` units.
  - **Expect** **Edit** is gone once anything has arrived.
- [ ] 1.3.7 Finish or close:
  - Receiving everything pending moves the request to `Received` (no more actions).
  - Or ⋮ → **Close request**, reason `Vendor cannot supply the rest`. **Expect** status `Closed`, the reason under the summary, no **Receive goods**; the Overview count drops by 1.
- [ ] 1.3.8 Store scope: sign in as the store manager of another store. **Expect** PR 1 is not listed and the Store dropdown offers only their stores.

### 1.4 Assets (Inv-6)

Open **Assets** from Inventory tiles.

#### Asset Registration

- [ ] 1.4.1 **Asset Registration (Unit 1)**:
  - In Assets, tap FAB **Register asset**:
    - Asset item: Tap search and select `LAP-DELL-15` (`Dell Latitude 15 Core i5 Laptop`).
    - Store: Select `Central Main Store`.
    - Asset Name: `Dell Latitude 15 - Admin 01`.
    - Serial Number: `DELL-SN-78491`.
    - Make: `Dell`, Model: `Latitude 3520`.
    - Location: `Admin Building Ground Floor - Room 102`.
    - Condition: `new`.
    - Purchase Date: Today (`YYYY-MM-DD`).
    - Purchase Price: `54000.00`.
    - Warranty: Start: Today, End: 3 years from today (`YYYY-MM-DD`).
    - Tap **Register asset**.
  - **Expect** Asset created with status `Available` (green pill), identifier = the asset's document ID. Item code displayed on card.
- [ ] 1.4.2 **Asset Registration (Unit 2)**:
  - Register second asset for same item `LAP-DELL-15`:
    - Asset Name: `Dell Latitude 15 - Lab 01`.
    - Serial Number: `DELL-SN-78492`.
    - Store: `Science Lab Store`.
    - Make: `Dell`, Model: `Latitude 3520`.
    - Location: `Science Block 2nd Floor - Room 204`.
    - Condition: `new`.
    - Purchase Price: `54000.00`.
    - Tap **Register asset**. **Expect** Asset 2 registered with status `Available`.

#### Asset Labels & Identification

- [ ] 1.4.4 **Barcode Label Generation**:
  - Open Asset 1 sheet → tap **Label** button.
  - **Expect** system share sheet / preview renders printable 50×25 mm asset label with a Code 128 barcode of the asset's document ID, the item name and the serial number.
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

### 1.5 Scanning & Import (Inv-8)

#### Barcode & Code Scanning

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
    8. **Open purchase requests**: open and partially received requests.
    9. **Pending approvals**: displays pending approval counts.
    10. **Registered assets**: displays registered assets count.
    11. **Assets under maintenance**: displays `0` (after completing step 1.4.13).

#### Reports

- [ ] 1.6.2 **Inventory reports**: open **Reports**; it lists five reports. Each opens in the shared report table: search, sortable columns, pages of 25 (size selectable), Period / Store / Show (or Type) filters, a totals strip for money columns and **Export CSV**. Dated reports open on Current Month.
    1. **Current stock**: one row per item and store (batches summed) with In stock and Minimum stock; items never received show `Out of stock`; Show: In stock / Running low / Out of stock.
    2. **Expiring items**: batches in stock, earliest expiry first; the Expires column reads `Expired 3 days ago`, `Expires today` or `In 12 days` (`MILK-PAST-01` has expired); Show: Already expired / Expiring in 30 days / Expiring in 90 days.
    3. **Stock summary**: per item for the period: Opening stock, Received, Given out, Returned, Damaged / lost, Corrections (±), Closing stock. Opening + in − out = Closing; with a past period, Closing matches the stock on that period's last day.
    4. **Items given out**: one row per issued item with date, Given to (the requester), purpose, quantity, returned and value.
    5. **Stock in & out**: every change to usable stock in date order, one line each (marking stock damaged shows once, as Out), with In / Out columns.

---

### 1.7 Permissions & Cross-Campus Security (Inventory)

Edit permissions in `schools/<schoolId>/userAccess/<uid>` via Emulator UI (or sign in as matching role):

- [ ] 1.7.1 **Role: `teacher`**:
  - Set permissions: `inventory.issue.request`, `inventory.purchaseRequest.request`, `inventory.assets.view`.
  - Restart / reload app.
  - **Expect**: Only My requests, Purchase requests, and Assets tiles are visible. Stores, Stock management and Reports are hidden.
- [ ] 1.7.2 **Role: `storekeeper`**:
  - Set permissions: `inventory.items.view`, `inventory.stock.view`, `inventory.stock.operate`, `inventory.issue.request`, `inventory.purchaseRequest.request`, `inventory.assets.manage`, `inventory.assets.view`.
  - **Expect**: Full operational access to Stock (Receive, Issue, Transfers, Damaged/Expired).
- [ ] 1.7.3 **Role: `procurement`**:
  - Set permissions: `inventory.items.view`, `inventory.stock.view`, `inventory.purchaseRequest.request`, `inventory.procure.operate`, `inventory.assets.view`.
  - **Expect**: Full access to Purchase requests. Prohibited from executing physical store receipts, stock issues, or manual balance adjustments.
- [ ] 1.7.4 **Campus Isolation**:
  - In `userAccess/<uid>`, set `campusIds: [32]` (Campus 32 only) and `hasAllCampuses: false`.
  - Open Stock Overview.
  - **Expect**: Only Campus 32 stores (`Science Lab Store`) and records are visible. Campus 31 stores (`Central Main Store`) are excluded.

---

## Part 2 – Library

Open **Library** from the dashboard. The Library hub displays 15 option grid tiles: Dashboard, Catalogue, Copies, Categories, Libraries, Circulation, Reservations, Members, Borrowing policies, Fines & Penalties, Lost & Damaged, Transfers, Stock verification, Reports, Import.

### 2.1 Masters (Lib-1)

#### Library Facilities Master

- [ ] 2.1.1 **Settings → Libraries** → tap **+ Library** to add Library 1 (there is no code or staff field; with a single campus the Campus field is not shown):
  - Name: `Central High School Library`
  - Campus: `Campus 31`
  - Location: `Academic Block A, 1st Floor`
  - Hours: `08:00 - 17:00`
  - Phone: `+91 98765 43210`
  - Email: `library@school.edu`
  - Tap **Save**. **Expect** Library 1 created with Active status chip.
- [ ] 2.1.2 Add Library 2:
  - Name: `Junior School Library`
  - Campus: `Campus 32`
  - Location: `Primary Wing Ground Floor`
  - Hours: `08:30 - 15:30`
  - Tap **Save**. **Expect** Library 2 created.

#### Classification Categories

- [ ] 2.1.3 **Categories** → tap empty-state seed button (or view seeded categories).
  - **Expect** 14 standard classification categories created:
    - `Fiction`
    - `Non-fiction`
    - `Science`
    - `Mathematics`
    - `History`
    - `Geography`
    - `Literature`
    - `Languages`
    - `Reference`
    - `Encyclopedias`
    - `Biographies`
    - `Children's books`
    - `Textbooks`
    - `General knowledge`
- [ ] 2.1.4 Negative: Category Deactivation Protection:
  - On category `History`, toggle Active switch off.
  - Try to create a catalogue title under category `History`.
  - **Expect** inactive category is excluded from selection or creation is rejected. Reactivate category `History`.

#### Title Catalogue Management

- [ ] 2.1.5 **Catalogue** → tap FAB **+ Book** to add Title 1:
  - Title: `Wings of Fire: An Autobiography`
  - Authors: `A.P.J. Abdul Kalam, Arun Tiwari` (comma-separated)
  - Category: `History`
  - Publisher: `Universities Press`
  - Edition: `1st Edition`
  - Publication Year: `1999`
  - ISBN-13: `9788173711466` (valid check digit)
  - Tap **Save**. **Expect** Title saved and listed in catalogue.
- [ ] 2.1.6 Add Title 2:
  - Title: `Pride and Prejudice`
  - Authors: `Jane Austen`
  - Category: `Fiction`
  - Publisher: `Penguin Classics`
  - Publication Year: `2003`
  - ISBN-13: `9780141439518`
  - Tap **Save**. **Expect** Title saved.
- [ ] 2.1.7 Add Title 3 (Without ISBN):
  - Title: `School Annual Magazine 2025-26`
  - Authors: `Editorial Board`
  - Category: `Non-fiction`
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

### 2.2 Copies & Books (Lib-2)

#### Adding Books & Copy Generation

- [ ] 2.2.1 **Acquire Copies for Title 1 ("Wings of Fire")**:
  - Open "Wings of Fire" details → scroll to Physical Copies section → tap **Acquire copies**:
    - Book Type: `Purchase`
    - Target Library: `Central High School Library` 
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
    - Library: `Central High School Library` 
    - Quantity: `1`
    - Unit Price: `280.00`
    - Shelf: `Shelf F-03`
    - Tap **Save**.
  - **Expect** Copy created with accession number `ACC-000004`, status `Available`.

#### Copy Attributes & Spine Labels

- [ ] 2.2.3 **Shelf Location & Remarks**:
  - In Copies list (or from Book Details copies section), tap copy `ACC-000001` to open `CopyDialog`:
    - Remarks: `Curriculum reference copy`
    - Tap **Save changes**. **Expect** copy updated.
- [ ] 2.2.5 **Print Spine & Barcode Labels**:
  - On copy `ACC-000001` sheet, tap **Print label** (or share labels action).
  - **Expect** printable label preview renders accession barcode, call number, title, and library name.
- [ ] 2.2.6 **Copy Maintenance State Transitions**:
  - Open Copy `ACC-000002` → tap **Change status** → select `under_maintenance`.
  - **Expect** status transitions to `Under maintenance` (amber); copy is excluded from available loans.
  - Tap **Change status** → select `available`. **Expect** status restored to `Available`.

---

### 2.3 Borrowing Policies and Borrowers (Lib-3)

#### Borrowing Rules & Policies

- [ ] 2.3.1 **Create Student Policy**:
  - Open **Settings → Borrowing policies** → tap **+ Policy**:
    - Library: `Central High School Library` 
    - Applies to: `Students`
    - Policy name: `Student Policy`
    - Max books allowed: `2`
    - Loan period in days: `7`
    - Max renewals: `1`
    - Fine type: `per_day`
    - Rate per day (₹): `2.00`
    - Grace days: `0`
    - Book categories: none selected (applies to every category)
    - Tap **Save**. **Expect** Policy created for `Central High School Library` · Students · All other categories.
- [ ] 2.3.2 **Create Teacher Policy**:
  - Add Policy 2:
    - Library: `Central High School Library` 
    - Applies to: `Teachers`
    - Policy name: `Teacher Borrowing Policy`
    - Max books allowed: `5`
    - Loan period in days: `30`
    - Max renewals: `2`
    - Fine type: `none`
    - Grace days: `3`
    - Tap **Save**. **Expect** Policy created for `Central High School Library` · Teachers · All other categories.
- [ ] 2.3.2a **Category policy**: add a Students policy for one category only (e.g. `Reference`, Max books `1`, Loan period `3`). **Expect** it saves next to the catch-all; issuing a `Reference` book uses 3 days, other books use 7. Saving a second Students policy for `Reference`, or a second one with no categories, is refused.
- [ ] 2.3.3 Negative: Validation:
  - Create policy with Fine type `per_day` and empty or negative fine rate.
  - **Expect** blocked with validation error.

#### Borrowers

There is no enrolment: students are found in the ERP (Node) at the desk, and a person appears under **Members** the first time they borrow or reserve.

- [ ] 2.3.4 **First borrow creates the record**:
  - Open **Members** → **Students**. **Expect** it is empty before any loan.
  - After step 2.4.1 (issue to a student found by name), reopen **Members**.
  - **Expect** one row with the student's name, ERP ID, class and `1` on loan; status `Can borrow`.
- [ ] 2.3.5 **Teachers (not connected yet)**:
  - In **Circulation**, switch the person type to `Teacher`.
  - **Expect** the message "Teacher lookup is not connected yet" and no way to choose a teacher. This is a placeholder until Node's teacher search is wired in.
- [ ] 2.3.6 **Block and unblock**:
  - On a member row tap **Block**, enter a reason, confirm. **Expect** status `Blocked`; issuing to that person is rejected.
  - Tap **Unblock**. **Expect** status `Can borrow`. A fine also blocks automatically and clears when the fine is paid or waived.

---

### 2.4 Circulation (Loans, Renewals, Returns) (Lib-4)

Open **Circulation** from Library tiles.

#### Book Issuance

- [ ] 2.4.1 **Issue Book to Student 501**:
  - Person: `Student`; type the first letters of the student's name (ERP ID `501`) and choose them from the list.
  - In the field **"Scan book to ISSUE to this member"**, enter or scan accession number `ACC-000001` ("Wings of Fire").
  - Press enter / confirm.
  - **Expect**:
    - Toast confirmation: `ACC-000001 issued`.
    - Active loan appears in the loans list below showing `ACC-000001 · Student #501`, due in 7 days.
    - Copy `ACC-000001` status transitions from `Available` to `Issued` (blue pill).
    - Outbox records notification event `library-issued__...`.
- [ ] 2.4.2 **Issue Second Book to Student 501**:
  - With student `501` chosen, enter `ACC-000004` ("Pride and Prejudice") in the issue scan field.
  - **Expect** Issue succeeds; Student 501 active loan count becomes `2` (reaching the policy limit).
- [ ] 2.4.3 Negative: Borrowing Quota Limit Exceeded:
  - Attempt to issue Copy `ACC-000002` to Student 501.
  - **Expect** rejected with error ("Member has reached maximum borrowing limit of 2 books").
- [ ] 2.4.4 Negative: Issuing an Already Issued Copy:
  - With student `502` chosen, enter `ACC-000001` into the issue scan field.
  - **Expect** rejected with error ("Copy is currently issued and unavailable").

#### Loan Renewal

- [ ] 2.4.5 **Renew Active Loan**:
  - Tap the loan card for `ACC-000001` (or enter `ACC-000001` in "Scan book to RETURN or RENEW") to open `LoanDialog`.
  - Tap **Renew** button.
  - **Expect** Due date advances by 7 days; loan sheet shows `Renewed 1 of 1`.
- [ ] 2.4.6 Negative: Renewal Limit Reached:
  - On the same loan sheet, check the Renew button.
  - **Expect** `Renew` button is disabled (renewals reached policy max limit of 1).

#### Book Returns

- [ ] 2.4.7 **Return Book in Good Condition**:
  - Open `LoanDialog` for `ACC-000004` ("Pride and Prejudice").
  - Enter optional return remarks: `Returned on time in clean condition`.
  - Tap **Return** button.
  - **Expect**:
    - Loan is closed and removed from active loans list.
    - Copy `ACC-000004` status restores to `Available`.
    - Student 501 active loans count drops from `2` to `1`.
    - Outbox records notification `library-returned__...`.

---

### 2.5 Reservations & Hold Queue (Lib-5)

Setup: Copy `ACC-000001` is currently on loan to Student 501. No other copies of "Wings of Fire" are available at `Central High School Library` (Copy 2 is under maintenance/quarantined, Copy 3 was moved to `Junior School Library`).

- [ ] 2.5.1 **Queue Reservation 1 (Student 502)**:
  - Open Catalogue → open "Wings of Fire" details → tap AppBar bookmark icon (tooltip: "Reserve book"):
    - Person: `Student` `502`, found by name
    - Library: `Central High School Library` 
    - Tap **Reserve book**.
  - **Expect** Reservation created with status `Waiting`; Queue Position is `1`.
- [ ] 2.5.2 **Queue Reservation 2 (Student 503)**:
  - Open **Reservations** from Library tiles → tap FAB **New reservation**:
    - Person: `Student` `503`, found by name
    - Select Book: `Wings of Fire`
    - Library: `Central High School Library` 
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
    - Outbox records notification `library-rsv-ready__...` notifying Student 502.
- [ ] 2.5.6 Negative: Issuing a Held Copy to Another Member:
  - In Circulation, choose student `503` (queue position 2). Enter held copy `ACC-000001` in issue field.
  - **Expect** rejected with error ("Copy is currently held on reservation for Member 502").
- [ ] 2.5.7 **Issue Held Copy to Target Member**:
  - In Circulation, choose student `502`. Enter `ACC-000001` in issue field.
  - **Expect** Issue allowed; reservation status updates to `Fulfilled`; Student 502 has active loan.
- [ ] 2.5.8 **Reservation Cancellation**:
  - Open **Reservations** → tap Student 503's waiting reservation → tap **Cancel reservation**.
  - **Expect** Reservation status moves to `Cancelled`.

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
  - Open **Fines & Penalties** from Library tiles → tap Student 502's ₹6.00 fine to open `FineDialog`.
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
  - Open **Lost & Damaged** from Library tiles → tap incident for `ACC-000004` to open `IncidentDialog`.
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
    - To library: Select `Junior School Library` . The From library is not offered.
    - Scan a copy from another library or an issued copy. **Expect** a message naming why it was refused.
    - Remarks: `Required for Class 8 literature workshop`.
    - Tap **Request transfer**.
  - **Expect** the screen closes; the list shows `LTR/<financialYear>/<seq>` with status `Requested`.
- [ ] 2.7.2 **Approve and Dispatch Transfer**:
  - Tap the transfer card to open the transfer screen (a card with `Needs your approval` is waiting on you):
    - Tap **Approve transfer** and confirm. Status becomes `Approved`.
    - Tap **Dispatch copies** and confirm.
  - **Expect** the progress strip reaches `In transit`; copy `ACC-000001` marked `In Transit`.
- [ ] 2.7.3 Negative: Issuing an In-Transit Copy:
  - In Circulation, attempt to issue `ACC-000001` while in transit.
  - **Expect** rejected with error ("Copy is currently in transit between libraries").
- [ ] 2.7.4 **Receive Transfer at Destination Library**:
  - Open the transfer as a receiving librarian (`Junior School Library` campus; card shows `Confirm receipt on arrival`).
  - Copies are ticked by default; set `ACC-000001` condition (Good / Fair / Poor), optionally enter a shelf and remarks.
  - Tap **Confirm receipt (1)**.
  - **Expect** Transfer marked `Received`; copy `ACC-000001` now belongs to `Junior School Library` with the chosen condition and is available for circulation at `Junior School Library`. Unticking a copy leaves it in transit (`Partly received`) and it can be received later.
- [ ] 2.7.4a **Filters and visibility**:
  - Use the status chips on the Transfers list. **Expect** the list narrows and an empty filter offers **Show all transfers**.
  - As a librarian limited to one campus, **Expect** both outgoing and incoming transfers are listed.

#### Library Stock Verification

- [ ] 2.7.5 **Initiate Library Stock Verification**:
  - Open **Stock verification** from Library tiles → tap FAB **New verification**:
    - Library: Select `Central High School Library` .
    - Shelf: Leave blank (whole library) or enter shelf code.
    - Tap **Start counting**.
  - **Expect** Session created (`STK/...`); status `Counting`. Active loans are flagged as on loan and excluded from shelf discrepancies.
- [ ] 2.7.6 **Barcode Scanning & Reconciliation**:
  - In `VerificationSheet`, scan expected accession numbers into the scan field.
  - Scan an unexpected copy (e.g. belonging to `Junior School Library`).
  - Leave one shelf copy unscanned (simulating a missing book).
  - Tap **Submit count**. Status moves to `Submitted`.
  - Review corrections:
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
    9. **Student borrowers**: students who have borrowed or reserved.
    10. **Teacher borrowers**: teachers who have borrowed or reserved.
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
    11. **Books report**: dates, numbers, sources (purchase/donation), copies count, prices.
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
    title,authors,category,isbn13,publisher,year
    Discovery of India,Jawaharlal Nehru,History,9780143031031,Penguin,2004
    Modern Physics,H.C. Verma,Unknown category,9788177091878,Bharti,2018
    Wings of Fire: An Autobiography,A.P.J. Abdul Kalam,History,9788173711466,Universities Press,1999
    ```

  - Tap **Run import**.
  - **Expect** summary shows 1 of 3 imported:
    - Row 1: `Success`
    - Row 2: `Error: Category "Unknown category" not found`
    - Row 3: `Error: Title with this ISBN-13 already exists`
- [ ] 2.8.5 **Import Copies CSV**:
  - Select **Copies** import.
  - Paste CSV:

    ```csv
    isbn13,library,quantity,price,shelf,condition,date
    9780143031031,Central High School Library,2,400.00,Shelf H-01,good,2026-01-15
    ```

  - Tap **Run import**.
  - **Expect** Accession numbers generated and copies created as `Available`.

#### Scheduled Notification Automation [JOB]

- [ ] 2.8.6 **Execute `runDailyLibrary`**:
  - Trigger scheduled library callable.
  - **Expect**:
    - Loans due in 2 days receive `library-due-soon__...` outbox event.
    - Overdue loans past due date receive `library-overdue__...__<date>` outbox event.
    - Reservation holds expiring within 24 hours receive `library-rsv-expiring__...`.
    - Re-executing on the same day produces no duplicate outbox events.

---

### 2.9 Permissions & Role Security (Library)

Edit permissions in `schools/<schoolId>/userAccess/<uid>`:

- [ ] 2.9.1 **Role: `teacher`** (no Library permissions):
  - Set permissions: none of `library.*`.
  - Restart / reload app.
  - **Expect**: No Library tile and no Library data readable.
- [ ] 2.9.3 **Role: `librarian` (Campus Scoping)**:
  - In `userAccess/<uid>`, set `campusIds: [32]` (Campus 32 only) and `hasAllCampuses: false`.
  - **Expect**: Library views and circulation default to `Junior School Library` ; queries exclude Campus 31  loans and copies.

---

## Part 3 – Cross-cutting

- [ ] 3.1 **Idempotency**: Double-tap any save/issue/return button. **Expect** one record only created.
- [ ] 3.2 **Connection handling**: Stop the emulator mid-action, then act. **Expect** clear error prompt, no half-saved or corrupted state.
- [ ] 3.3 **Empty states**: Open any master, stock, circulation, or report list with no data. **Expect** clean empty state with icon and message, no infinite spinner or crash.
- [ ] 3.4 **Audit logging**: Every mutation via Cloud Functions creates a corresponding record in `schools/<schoolId>/auditLogs`.
- [ ] 3.5 **Automated test suite**: `melos run firebase:test` passes with all functions and rules tests green.
