# Inventory & Library – Manual test guide (emulator)

Walk it top to bottom. Every step has an action and an **Expect** line; tick it only when
the expectation holds. Note failures with the step number.

Tags: **[JOB]** needs a scheduled job that the emulator never fires on its own (see Part 0.5).
**[EMU]** behaves differently in the emulator.

## Part 0 – Setup

### 0.1 Start the emulators

```bash
melos run emulators:reset
```

```bash
melos run emulators
```

Leave it running (Ctrl-C saves data to `firebase/.emulator-data`). Emulator UI: http://localhost:4000.

### 0.2 Seed role permissions

Use the role IDs your test login really has from Node (it is in the login response). One command per extra role is not needed; pass several:

```bash
melos run emulators:seed -- --school <schoolId> --roles admin=<roleId>
```

To test other roles later, re-run with `--force` and a different mapping, for example `--roles librarian=<roleId> --force`. Role names: `admin`, `principal`, `inventoryManager`, `storekeeper`, `procurement`, `librarian`, `teacher`.

### 0.3 Run the app

Launch config **icueadmin [Dev + Emulators · Android]** (or iOS). It signs in with a locally built unsigned token. Open Emulator UI → Firestore → `schools/<schoolId>/userAccess/<your uid>`.

- [ ] 0.3.1 `permissions` is non-empty, `campusIds` lists your campus IDs (or `hasAllCampuses: true`). **Expect** the app shows Inventory and Library tiles. If not, the role ID in the seed does not match your login.

### 0.4 Test data you will type

Use two campuses (31 and 32 below; use your real campus IDs). Keep a scratch list: ERP student IDs 501, 502, 503, ERP teacher/staff ID 884 (yours), a second staff ID.

### 0.5 Scheduled jobs

`dailyInventory`, `dailyLibrary` and `holdExpiry` do not run by themselves in the emulator. Steps tagged **[JOB]** can only be checked once someone triggers them (a small script calling `runDailyInventory` / `runDailyLibrary` / `runHoldExpiry` is not in the repo yet). Skip those steps for now and mark them blocked.

### 0.6 What to watch in the Emulator UI during the whole run

- `schools/<schoolId>/auditLogs`: one entry per change.
- `schools/<schoolId>/outbox` and `notifications`: what would have been pushed. Push itself is never sent from the emulator. **[EMU]**
- `schools/<schoolId>/requests`: repeating the same action (double tap) must not create a second record.

---

## Part 1 – Inventory

Open **Inventory** from the dashboard.

### 1.1 Masters (Inv-1)

#### Master Setup & Categories
- [ ] 1.1.1 **Categories** → tap empty-state seed button (or view seeded categories). **Expect** FRS default categories (Stationery, Laboratory, IT & Electronics, Sports, Maintenance) and standard units appear.
- [ ] 1.1.2 Add a root category with Code `STA`, Name `Stationery & Supplies`. Under `STA`, add subcategory Code `WRI`, Name `Writing Instruments`. **Expect** both saved and listed in the tree.
- [ ] 1.1.3 Negative: Add a category with Code `STA` again. **Expect** rejected with "Category code already exists" (codes are unique and case-insensitive).
- [ ] 1.1.4 Deactivate subcategory `WRI` (switch off Active). Try to select `WRI` in item creation. **Expect** `WRI` is excluded or creation is rejected with inactive category error. Reactivate `WRI`.
- [ ] 1.1.5 **Units** → add Code `ream`, Name `Ream (500 sheets)`. **Expect** unit saved and appears in unit dropdowns.

#### Stores
- [ ] 1.1.6 **Stores** → add Store 1:
  - Code: `S31`
  - Name: `Central Main Store`
  - Campus: `31`
  - Location: `Admin Building Ground Floor`
  - Description: `Main central distribution store`
- [ ] 1.1.7 Add Store 2:
  - Code: `S32`
  - Name: `Science Lab Store`
  - Campus: `32`
  - Location: `Science Block 2nd Floor`
  - Description: `Laboratory chemicals and apparatus store`
- [ ] 1.1.8 In store details / edit, check Campus field. **Expect** both stores listed with Active badges; campus selector is locked / cannot be modified after creation.

#### Items (Simplified Catalog Master)
- [ ] 1.1.9 **Items** → Add Item 1 (Quantity-tracked consumable):
  - Code: `PEN-BLU-01`
  - Name: `Ballpoint Pen (Blue, 0.7mm)`
  - Category: `Writing Instruments` (`WRI`)
  - Stock Unit: `pc`
  - Tracking Method: `Quantity tracked`
  - Reorder Level: `50`
  - Default Price: `15.00`
  - **Expect** saved. Item card displays code, name, category, unit, default price (₹15.00), and reorder level (50).
- [ ] 1.1.10 Add Item 2 (Batch & Expiry-tracked):
  - Code: `MILK-PAST-01`
  - Name: `Pasteurized Milk (500ml pouch)`
  - Category: `Stationery & Supplies` (`STA`)
  - Stock Unit: `pc`
  - Tracking Method: `Batch & expiry tracked`
  - Reorder Level: `15`
  - Default Price: `30.00`
  - **Expect** saved with Batch tracking badge.
- [ ] 1.1.11 Add Item 3 (Serialized Asset-tracked):
  - Code: `LAP-DELL-15`
  - Name: `Dell Latitude 15 Core i5 Laptop`
  - Category: `Stationery & Supplies` (`STA`)
  - Stock Unit: `pc`
  - Tracking Method: `Asset tracked (serialized)`
  - Reorder Level: `3`
  - Default Price: `45000.00`
  - **Expect** saved with Asset tracking badge.
- [ ] 1.1.12 Negative: Add an item with Code `PEN-BLU-01` again. **Expect** rejected with "Item code already exists".
- [ ] 1.1.13 **Item Details & Navigation**: Tap `PEN-BLU-01` in the catalog list. **Expect** dashboard card opens showing classification, tracking parameters, and a direct action button **"View Store Stock"**.
- [ ] 1.1.14 **Items Search & Category Filter**:
  - In Items list search bar, type `pen`. **Expect** `PEN-BLU-01` is filtered immediately.
  - Tap Category filter chip `Writing Instruments`. **Expect** only items under `WRI` are shown, with matching count badge. Clear chip.

---

### 1.2 Stock (Inv-2)

Open **Stock** from Inventory.

#### 1.2.1 Receive Opening Stock (Consumable)
- [ ] Tap **Receive Stock** (or quick-action chip).
  - Store: `Central Main Store` (`S31`)
  - Source: `Opening stock`
  - Reference: `OP-2024-PEN`
  - Line: `PEN-BLU-01` × `100` units at unit cost `15.00`
  - Tap **Confirm Receiving**.
- [ ] **Expect** in Stock Overview for `S31`:
  - Available balance for `PEN-BLU-01` = `100 units`.
  - Store Valuation banner updates (+ ₹1,500.00).
  - Tap balance card → **View movement history**: shows `receive` movement with +100 units, source `opening`, reference `OP-2024-PEN`.

#### 1.2.2 Receive Batch Stock (FEFO Preparation)
- [ ] Tap **Receive Stock**:
  - Store: `Central Main Store` (`S31`)
  - Source: `Opening stock`
  - Reference: `OP-2024-MILK`
  - Line 1: `MILK-PAST-01`, Batch `BATCH-M1`, Expiry: Today + 5 days, Quantity: `20`
  - Line 2: `MILK-PAST-01`, Batch `BATCH-M2`, Expiry: Today + 25 days, Quantity: `10`
  - Tap **Confirm Receiving**.
- [ ] **Expect** in `S31`:
  - `MILK-PAST-01` shows total Available = `30 units`.
  - Expanding balance shows two separate batch balances: `BATCH-M1` (20 units, expiring in 5 days) and `BATCH-M2` (10 units, expiring in 25 days).

#### 1.2.3 Negative: Expired Batch Receipt Rejected
- [ ] Tap **Receive Stock** with `MILK-PAST-01`, Batch `BATCH-OLD`, Expiry: Yesterday (past date), Quantity: `5`.
- [ ] **Expect** rejected with validation error (expired batches cannot be received into active inventory).

#### 1.2.4 Negative: Asset-Tracked Items Ineligible for Stock Receive
- [ ] In **Receive Stock**, select `LAP-DELL-15` (asset-tracked item).
- [ ] **Expect** rejected: Asset items cannot be received via opening stock receipt; they must be received via Purchase Orders with individual serial/tag registration (Inv-6).

#### 1.2.5 Create Issue Request (Requisition)
- [ ] Tap **Issue Requests** → tap **New Request**:
  - Store: `Central Main Store` (`S31`)
  - Purpose: `Exam Hall Supplies for Midterms`
  - Destination: `Main Exam Hall - Block A`
  - Line: `PEN-BLU-01` × `30` units
  - Tap **Submit Request**.
- [ ] **Expect** request created with number `REQ/<year>/<seq>`. Status is `Pending`. Appears under `All` and `Pending` filter chips with badge count `1`.

#### 1.2.6 Approve Issue Request (One-Click Approval)
- [ ] As Approver (`inventory.issue.approve`), open the request sheet.
- [ ] Tap **"Approve all requested"** button. **Expect** approved quantity for `PEN-BLU-01` automatically fills with `30`.
- [ ] Tap **Approve request**.
- [ ] **Expect** status changes to `Approved`. Request card moves under `Approved` filter chip; requester receives outbox event `issuerequest__approved`.

#### 1.2.7 Negative: Rejection Reason Required
- [ ] Create a dummy request for `10` PEN. Open as Approver, leave Note empty and tap **Reject**.
- [ ] **Expect** blocked with error "Enter a reason for rejection".
- [ ] Type "Department monthly quota exceeded" and tap **Reject**. **Expect** status changes to `Rejected`.

#### 1.2.8 Stock Issuance & Recipient Auto-Fill
- [ ] As Storekeeper (`S31`), open the approved 30-unit request sheet.
- [ ] Scroll to **Issue Stock** section.
- [ ] **Expect** Recipient ERP ID is automatically pre-filled with the requester's ERP ID (`884`), Recipient Type: `Staff`.
- [ ] Tap **Issue stock**.
- [ ] **Expect**:
  - Issue number created (e.g. `ISS/<year>/<seq>`).
  - Request status updates to `Issued`.
  - In `S31` stock overview, `PEN-BLU-01` Available balance decreases from `100` to `70`.

#### 1.2.9 Negative: Issue Beyond Available Balance
- [ ] Create a request for `500` PEN from `S31`. Approve it and try to issue.
- [ ] **Expect** refused with error (insufficient stock; available is only 70; balances cannot go negative).

#### 1.2.10 Recipient Receipt Acknowledgement
- [ ] Open the issue sheet for the 30-unit issue.
- [ ] Notice the banner: *"Recipient has not yet acknowledged receiving these items"*.
- [ ] Tap **Confirm receipt**.
- [ ] **Expect** banner updates to `Receipt Confirmed` (green pill).

#### 1.2.11 Return Inspection (Usable vs. Damaged Split)
- [ ] In the issue return sheet for the 30-unit issue:
  - Outstanding is `30 units`.
  - For `PEN-BLU-01`, enter `10` in **Usable** (or tap "All usable" icon and edit) and `5` in **Damaged**.
  - Returned by Staff ERP ID: `884`.
  - Tap **Record Return**.
- [ ] **Expect**:
  - `S31` Available balance for `PEN-BLU-01` increases from `70` to `80` (only usable stock returns to available).
  - The `5` damaged units are NOT added to available balance; they are automatically routed to the **Quarantine / Damaged Stock Register**.
  - Outstanding on the issue becomes `15 units` (30 − 15).

#### 1.2.12 Negative: Return Exceeding Outstanding Quantity
- [ ] In the same issue return sheet, try to return `20` units (only 15 are outstanding).
- [ ] **Expect** refused with error (return quantity cannot exceed remaining outstanding balance).

#### 1.2.13 Inter-Store Transfer Request
- [ ] Tap **Transfers** → tap **New Transfer**:
  - Source Store (From): `Central Main Store` (`S31`, Campus 31)
  - Destination Store (To): `Science Lab Store` (`S32`, Campus 32)
  - Line: `PEN-BLU-01` × `20` units
  - Remarks: `Transfer surplus stationery to science faculty`
  - Tap **Request Transfer**.
- [ ] **Expect** transfer card created with number `TRF/<year>/<seq>`. Status is `Requested` (amber). Displays `Inter-campus` badge and route `Central Main Store ➔ Science Lab Store`.

#### 1.2.14 Negative: Same Source and Destination Store
- [ ] In **New Transfer**, select `S31` for both From and To stores.
- [ ] **Expect** blocked with error "Source and destination stores must differ".

#### 1.2.15 Transfer Dispatch
- [ ] Open the transfer card as Storekeeper for `S31`.
- [ ] Tap **Dispatch Transfer**.
- [ ] **Expect**:
  - Transfer status updates to `In Transit` (blue).
  - `PEN-BLU-01` Available balance in `S31` drops from `80` to `60` (allocated and deducted immediately upon dispatch).
  - `S32` balance remains `0` (stock is in transit).

#### 1.2.16 Transfer Partial Receipt & Shortfall Discrepancy Recording
- [ ] Open the transfer card as Storekeeper for `S32` (`Science Lab Store`).
- [ ] Receive dialog opens showing 20 units dispatched.
- [ ] Enter received quantity `15` (5 units short / damaged in transit).
- [ ] Switch ON **"Close transfer upon receipt (record any unreceived items as permanent shortfall)"**.
- [ ] Tap **Confirm Receipt**.
- [ ] **Expect**:
  - Transfer status updates to `Received` (green).
  - `PEN-BLU-01` Available balance in `S32` increases from `0` to `15 units`.
  - Transfer card displays red warning banner: *"Shortfall of 5 units recorded on receipt"*.
  - Discrepancy of 5 units is logged permanently in transfer audit records.

#### 1.2.17 Stock Adjustment with Reason
- [ ] In `S31`, tap on `PEN-BLU-01` balance card → select **Adjust stock**.
- [ ] Enter adjustment quantity `-3` units.
- [ ] Reason: `Physical count audit discrepancy`.
- [ ] Tap **Confirm adjustment**.
- [ ] **Expect** `PEN-BLU-01` Available balance in `S31` drops from `60` to `57 units`. Movement history logs an `adjust` movement with -3 units and the audit reason.

#### 1.2.18 Quarantine / Damaged Resolution Flow
- [ ] Open **Quarantine / Damaged Stock** (`unavailable_page`).
- [ ] **Expect** filter chip `Open (1)` shows the `5` damaged units of `PEN-BLU-01` recorded in step 1.2.11.
- [ ] **Resolution Case A (Restoration)**:
  - Tap the damaged card to open resolution modal.
  - Enter note: `Replaced leaking caps; verified usable after inspection`.
  - Tap **Return to usable stock**.
  - **Expect**: Status updates to `Resolved: Return to usable stock`. In `S31`, `PEN-BLU-01` Available balance increases from `57` to `62 units`.
- [ ] **Resolution Case B (Quarantine & Permanent Write-Off)**:
  - In `S31` stock overview, tap `PEN-BLU-01` → select **Report damaged / quarantine** for `2` units. Note: `Crushed in storage bin`.
  - `PEN-BLU-01` Available balance drops from `62` to `60 units`.
  - In Quarantine page, open the new 2-unit entry.
  - Tap **Write off**.
  - **Expect**: Confirmation dialog prompts *"Write off? This will permanently resolve 2 units... Action cannot be undone"*. Confirm.
  - **Expect**: Entry moves to `Resolved: Write off`. Stock Available remains `60`.

#### 1.2.19 Low Stock Alert & Filter Chip
- [ ] Open `PEN-BLU-01` in Item Details. Edit reorder level to `70` (higher than current available `60`).
- [ ] Return to **Stock Overview** for `S31`.
- [ ] **Expect**:
  - Balance card for `PEN-BLU-01` displays high-visibility warning pill: *"Low Stock: Below reorder level (70)"*.
  - Header filter chip **"Low stock only (1)"** appears.
  - Tapping **"Low stock only"** filters the list to show only `PEN-BLU-01`.
  - Low-stock outbox notification event generated (`lowstock__...`).

#### 1.2.20 FEFO Batch Issuance (Earliest Expiry First)
- [ ] In `S31`, create and approve an issue request for `15` units of `MILK-PAST-01`. Issue it.
- [ ] **Expect**: FEFO allocation consumes 15 units from `BATCH-M1` (expiring in 5 days). `BATCH-M1` balance drops from 20 to `5 units`. `BATCH-M2` remains untouched at `10 units`. Total available = 15.
- [ ] Create and approve a second issue request for `10` units of `MILK-PAST-01`. Issue it.
- [ ] **Expect**: Remaining 5 units are drawn from `BATCH-M1` (depleting it to 0), and the remaining 5 units are drawn from `BATCH-M2` (balance drops from 10 to `5 units`). Earliest-expiry batch is always exhausted first.

---

### 1.3 Procurement (Inv-3, Inv-4, Inv-5)

#### Vendors Master (Inv-3)
- [ ] 1.3.1 **Vendors** → Add Vendor 1 (`V-APEX`):
  - Code: `V-APEX`
  - Name: `Apex Educational Supplies Ltd.`
  - Contact Person: `Sunil Verma`
  - Phone: `9876543210`
  - Email: `sales@apexsupplies.com`
  - Tax / GST: `29ABCDE1234F1Z5`
  - Address: `Plot 14, Industrial Estate, Bangalore`
  - Payment Terms: `Net 30 days`
  - Categories: `STA` (Stationery), `WRI` (Writing Instruments)
  - **Expect** saved; vendor card displays code, contact chips, GSTIN, payment terms, and category tags.
- [ ] 1.3.2 Add Vendor 2 (`V-GLOBAL`):
  - Code: `V-GLOBAL`
  - Name: `Global Tech & Lab Instruments`
  - Contact Person: `Priya Nair`
  - Phone: `9845012345`
  - Email: `orders@globaltechlab.in`
  - Categories: `STA`
  - **Expect** saved.
- [ ] 1.3.3 Negative & Lifecycle checks:
  - Add Vendor with duplicate code `V-APEX`. **Expect** rejected ("Vendor code already exists").
  - Deactivate `V-GLOBAL` (switch off Active toggle). **Expect** Vendor card shows Inactive badge; filter chip "Active" excludes it, "Inactive" shows it.
  - Reactivate `V-GLOBAL`.

#### Purchase Requests Requisitions (Inv-3)
- [ ] 1.3.4 **Purchase requests** → Create PR 1 (Draft to Submitted):
  - Delivery Campus: `31`
  - Urgency / Priority: `High`
  - Purpose: `Annual Examination & Office Supplies Requisition`
  - Needed By Date: One week from today (`YYYY-MM-DD`)
  - Line 1: Item `PEN-BLU-01` · Quantity: `120` · Est. Unit Price: `15.00` (Subtotal ₹1,800.00)
  - Line 2: Item `LAP-DELL-15` · Quantity: `5` · Est. Unit Price: `55000.00` (Subtotal ₹2,75,000.00)
  - Total Estimated: ₹2,76,800.00
  - Tap "Save as draft". **Expect** created with status `Draft`, number `PR/<financialYear>/<seq>`.
- [ ] 1.3.5 Edit PR 1:
  - Open PR sheet → tap "Edit".
  - Change `PEN-BLU-01` quantity from `120` to `100` (Estimated total updates to ₹2,76,500.00).
  - Tap "Save changes". **Expect** updated item quantity on the PR card.
- [ ] 1.3.6 Submit PR 1:
  - Open PR sheet → tap "Submit for approval".
  - **Expect** status transitions from `Draft` to `Pending`; approval timeline logs "Submitted by [requester]"; `outbox` records notification event for approvers (`inventory.purchaseRequest.approve`).
- [ ] 1.3.7 Negative: Ownership & Permissions:
  - Open PR 1 with another user without requisition ownership or approval rights. **Expect** action bar hides Edit, Cancel, and Approve actions.

#### PR Review, Revision & Approval Workflow
- [ ] 1.3.8 Approver Review → Return for Revision:
  - Open PR 1 as Approver (with `inventory.purchaseRequest.approve`).
  - Tap "Return" action → enter reason: "Please reduce laptop quantity from 5 to 2 due to quarterly budget ceiling."
  - **Expect** status changes to `Returned`; timeline displays "Returned by [approver] · Remarks: Please reduce laptop quantity...".
- [ ] 1.3.9 Requester Resubmission:
  - As requester, open PR 1 → tap "Edit".
  - Update `LAP-DELL-15` quantity to `2`.
  - Tap "Submit for approval".
  - **Expect** status moves back to `Pending`; timeline logs re-submission.
- [ ] 1.3.10 Approver Approval:
  - Open PR 1 as Approver → tap "Approve".
  - Enter optional comment: "Approved within revised departmental budget."
  - **Expect** status changes to `Approved`; timeline logs approval; outbox emits notification to procurement role (`inventory.orders.manage`).

#### Quotations & Comparative Analysis (Inv-4)
- [ ] 1.3.11 **Quotations** → Add Quotation 1 (`V-APEX`):
  - On approved PR 1, tap "Add quotation".
  - Vendor: `Apex Educational Supplies Ltd.` (`V-APEX`)
  - Quote Ref: `QT-APEX-2026-09`
  - Valid Until: 30 days from today
  - Lead Time: `5 days`
  - Payment Terms: `Net 30 days`
  - Prices:
    - `PEN-BLU-01` (100 pc): Unit Price `14.50`
    - `LAP-DELL-15` (2 pc): Unit Price `54000.00`
  - Total Quoted: ₹1,09,450.00
  - Tap "Save quotation". **Expect** Quotation 1 listed.
- [ ] 1.3.12 Add Quotation 2 (`V-GLOBAL`):
  - Tap "Add quotation".
  - Vendor: `Global Tech & Lab Instruments` (`V-GLOBAL`)
  - Quote Ref: `QT-GLB-881`
  - Valid Until: 15 days from today
  - Lead Time: `12 days`
  - Payment Terms: `Net 15 days`
  - Prices:
    - `PEN-BLU-01` (100 pc): Unit Price `15.50`
    - `LAP-DELL-15` (2 pc): Unit Price `53500.00`
  - Total Quoted: ₹1,08,550.00
  - Tap "Save quotation". **Expect** Quotation 2 listed.
- [ ] 1.3.13 Comparative Matrix & Quotation Selection:
  - Open Quotations comparative view.
  - **Expect** side-by-side comparison matrix showing both vendor quotes, line items, and lowest price highlighted.
  - Select Quotation 1 (`V-APEX`) → Selection dialog prompts for mandatory justification reason.
  - Enter reason: "Shorter lead time of 5 days (vs 12 days) and local support warranty."
  - Tap "Confirm selection". **Expect** Quotation 1 marked `Selected`; other quotation remains unselected. Only one quotation can be selected per PR.

#### Purchase Orders (PO Generation, Issuance & Revision) (Inv-4)
- [ ] 1.3.14 Create PO from Selected Quotation:
  - Tap "Create PO" from the selected quotation or PR sheet.
  - **Expect** form prefilled with Vendor `V-APEX`, Delivery Campus `31`, items (`100` pens @ ₹14.50, `2` laptops @ ₹54,000.00), Subtotal ₹1,09,450.00.
  - Add Tax / GST: `18%` (₹19,701.00). Total: ₹1,29,151.00.
  - Expected Delivery Date: Next week (`YYYY-MM-DD`).
  - Delivery Terms: `Door delivery to Central Main Store S31`.
  - Tap "Save as draft". **Expect** PO created with number `PO/<financialYear>/<seq>`, status `Draft`.
- [ ] 1.3.15 Issue and Acknowledge PO:
  - Open PO sheet → tap "Issue Purchase Order".
  - **Expect** status changes to `Issued`; PR records ordered quantities; outbox notification generated for supplier dispatch.
  - Tap "Acknowledge" (supplier acknowledgement).
  - Enter Supplier Reference: `ACK-APEX-9921`.
  - **Expect** status updates to `Acknowledged`.
- [ ] 1.3.16 PO PDF Preview & Share:
  - Tap "Download / Share PDF".
  - **Expect** formatted purchase order PDF opens with institution header, PO Number, vendor details, itemized table, tax breakdown, delivery terms, and signature lines.
- [ ] 1.3.17 PO Revision with Audit Trail:
  - Tap "Revise PO".
  - Update `PEN-BLU-01` unit price from `14.50` to `14.00` (special discount conceded by vendor).
  - Enter Revision Reason: "Negotiated additional educational volume discount."
  - Tap "Create revision". **Expect** PO revision incremented (e.g. `Rev 1`); prior revision archived in history; status resets to `Issued` pending re-acknowledgement. Re-acknowledge the PO.

#### PO Goods Receiving (GRN, Inspection & Batch Tracking) (Inv-5)
- [ ] 1.3.18 Partial Goods Receiving:
  - Open PO sheet → tap "Receive goods".
  - **Expect** `PurchaseOrderReceivePage` opens with Destination Store dropdown, challan input, and items list (`100` pens due, `2` laptops due).
  - Select Destination Store: `Central Main Store (S31)`.
  - Enter Delivery note / Challan no.: `DC-APEX-7741`.
  - Line 1 (`PEN-BLU-01`): Enter Accepted `80`, Rejected `5`, Condition `5 broken tips during transit`.
  - Line 2 (`LAP-DELL-15`): Enter Accepted `0` (delivery scheduled next week).
  - Enter Overall inspection remarks: `First consignment received; 5 pens rejected at inspection.`
  - Tap "Confirm receiving (1 item)".
  - **Expect** GRN generated (`GRN/<financialYear>/<seq>`); PO status updates to `In Delivery` (`partially_received`); PO card shows delivery progress bar (~80%); Central Main Store (`S31`) stock balance of `PEN-BLU-01` increases by `80`; stock movement ledger records GRN movement; rejected count (5) logged in inspection records without entering store stock.
- [ ] 1.3.19 Negative: Exceeding Due Quantity:
  - Tap "Receive goods" again on the PO.
  - Remaining due for `PEN-BLU-01` is `15` (`100 ordered - 80 accepted - 5 rejected`).
  - Enter Accepted `25`. **Expect** inline validation error: "Only 15 due".
- [ ] 1.3.20 Quick Action "Accept all due" & Full Receiving:
  - Tap "Accept all due" button on the items header.
  - **Expect** line 1 accepted automatically fills with `15` (leaving 0 rejected), line 2 accepted fills with `2`.
  - Tap "Confirm receiving (2 items)".
  - **Expect** second GRN generated; all lines fulfilled; PO status transitions to `Received` (`fully_received`); PR status updates to `Completed`.

#### Vendor Invoices & 3-Way Match (Inv-5)
- [ ] 1.3.21 Record Vendor Invoice:
  - Open **Vendor Invoices** → tap "+ New Invoice".
  - Select Linked PO: `PO/<financialYear>/<seq>`.
  - **Expect** Vendor pre-filled as `Apex Educational Supplies Ltd.`.
  - Enter Invoice Number: `INV-APEX-2026-104`.
  - Invoice Date: Today (`YYYY-MM-DD`).
  - Due Date: Net 30 date (`YYYY-MM-DD`).
  - Subtotal: `1,09,350.00`, Tax: `19,683.00`, Total: `1,29,033.00`.
  - Link Goods Receipts: Check both generated GRN chips (`GRN-1`, `GRN-2`).
  - Tap "Create Invoice". **Expect** Invoice saved; status `Unpaid`; outstanding amount equals total `₹1,29,033.00`.
- [ ] 1.3.22 Negative: Duplicate Invoice Number per Vendor:
  - Tap "+ New Invoice" → choose same vendor and type identical Invoice Number `INV-APEX-2026-104`.
  - Tap "Create Invoice". **Expect** rejected with "Invoice number already exists for this vendor".
- [ ] 1.3.23 Payment Recording & Status Transitions:
  - Open Invoice sheet → tap "Update payment".
  - Enter Payment Reference: `NEFT/HDFC/9931023`.
  - Enter Paid Amount: `50,000.00`.
  - Tap "Save payment". **Expect** payment status transitions to `Partially paid`; Outstanding updates to `₹79,033.00`.
  - Tap "Update payment" again → enter Paid Amount `100,000.00` (exceeding outstanding).
  - **Expect** rejected ("Paid amount cannot exceed invoice total").
  - Enter remaining balance `79,033.00`. **Expect** status transitions to `Paid`; Outstanding becomes `₹0.00`.
- [ ] 1.3.24 Overdue Filter & Cancellation Safeguards:
  - In Emulator UI set an invoice's due date to yesterday. **Expect** filter chip `Overdue` filters and displays the invoice.
  - Try cancelling a `Paid` invoice. **Expect** cancellation prohibited / action disabled.
  - Cancel an `Unpaid` invoice. **Expect** invoice cancelled; status moves to `Cancelled`.
- [ ] 1.3.25 Cancel PO with Deliveries:
  - Attempt to cancel a PO that already has goods receipts recorded. **Expect** rejected with error explaining that received purchase orders cannot be cancelled without reversing receipts.

### 1.4 Assets (Inv-6)

#### Asset Registration & PO Integration
- [ ] 1.4.1 **Asset Registration (Unit 1)**:
  - In **Assets** → tap **+ Register Asset**.
  - Choose Asset Item: Tap search and select `LAP-DELL-15` (`Dell Latitude 15 Core i5 Laptop`).
  - Receiving Store: `Central Main Store` (`S31`).
  - Linked PO: Select `PO/<financialYear>/<seq>` (issued and received in step 1.3).
  - Asset Name: `Dell Latitude 15 - Admin 01`.
  - Serial Number: `DELL-SN-78491`.
  - Make: `Dell` · Model: `Latitude 3520`.
  - Physical Location: `Admin Building Ground Floor - Room 102`.
  - Condition: `new`.
  - Purchase Date: Today (`YYYY-MM-DD`).
  - Purchase Price: `54000.00` (auto-filled or matching PO).
  - Warranty Period: Start date: Today (`YYYY-MM-DD`), End date: 3 years from today.
  - Tap **Register asset**.
  - **Expect** Asset created with status `Available` (green pill), identifier `AST/<financialYear>/<seq>`. Linked PO and item code displayed on card.
- [ ] 1.4.2 **Asset Registration (Unit 2)**:
  - Register second asset for same item `LAP-DELL-15`:
    - Linked PO: Same `PO/<financialYear>/<seq>`.
    - Asset Name: `Dell Latitude 15 - Lab 01`.
    - Serial Number: `DELL-SN-78492`.
    - Make: `Dell` · Model: `Latitude 3520`.
    - Location: `Science Block 2nd Floor - Lab Store S32`.
    - Condition: `new`.
    - Purchase Price: `54000.00`.
  - Tap **Register asset**. **Expect** Asset 2 registered with status `Available`.
- [ ] 1.4.3 Negative: PO Quantity Cap Enforcement:
  - Attempt to register a 3rd asset unit linked to the same PO.
  - **Expect** rejected with error (cannot register more asset units than the accepted quantity of 2 on the purchase order).

#### Asset Labels & Identification
- [ ] 1.4.4 **QR Code Label Generation**:
  - Open Asset 1 sheet → tap **QR Label** (or barcode action).
  - **Expect** formatted asset label preview modal renders a scannable QR code encoding the asset identifier (`AST/...`), item name, serial number, and institution branding.
- [ ] 1.4.5 **RFID Tag Assignment & Uniqueness**:
  - Open Asset 1 sheet → tap **Set RFID Tag**.
  - Enter RFID Tag: `RFID-LAP-001`. Tap Save. **Expect** RFID tag saved and shown on Asset 1 card.
  - Open Asset 2 sheet → tap **Set RFID Tag**.
  - Enter identical RFID Tag: `RFID-LAP-001`. Tap Save.
  - **Expect** rejected with error ("RFID tag already assigned to another asset").
  - Enter unique RFID Tag: `RFID-LAP-002`. Tap Save. **Expect** saved.

#### Asset Custody Lifecycle (Assign, Transfer, Return)
- [ ] 1.4.6 **Custody Assignment**:
  - Open Asset 1 sheet → tap **Assign Custody**.
  - Recipient Staff ERP ID: `884` (Staff / Teacher).
  - Purpose: `Curriculum preparation and lecture presentations`.
  - Due Back Date: End of current academic term (`YYYY-MM-DD`).
  - Location: `Faculty Room 204`.
  - Tap **Confirm assignment**.
  - **Expect** Asset status transitions from `Available` to `Assigned` (blue pill); custodian displays Staff `884`; Custody History logs active assignment with timestamp.
- [ ] 1.4.7 Negative: Assigning an Unavailable Asset:
  - On Asset 1 (currently `Assigned`), attempt to assign custody again.
  - **Expect** assignment action is disabled or rejected (only `Available` assets can be assigned).
- [ ] 1.4.8 **Custody Transfer (Handover)**:
  - Open Asset 1 sheet → tap **Transfer Custody**.
  - New Custodian Staff ERP ID: `501`.
  - Handover Reason: `Inter-departmental teaching reassignment`.
  - Tap **Confirm transfer**.
  - **Expect** prior custody assignment for Staff `884` is closed; new active custody is opened for Staff `501`; custody history timeline shows complete audit trail of the transfer.
- [ ] 1.4.9 **Return Asset with Damage**:
  - Open Asset 1 sheet → tap **Return Asset**.
  - Condition: `Damaged`.
  - Return Remarks: `Display backlight flickering; cracked hinge casing`.
  - Return to Store: `Central Main Store` (`S31`).
  - Tap **Confirm return**.
  - **Expect** Custody assignment closed (no active custodian); Asset status changes to `Damaged` (red pill); Return record logged with inspection notes.

#### Asset Maintenance & Repair Workflow
- [ ] 1.4.10 **Raise Maintenance Request**:
  - Open Asset 1 sheet → tap **Request Maintenance**.
  - Issue Summary: `Screen hinge fracture and backlight repair`.
  - Priority: `High`.
  - Service Provider / Type: `Vendor Repair` (`Apex Educational Supplies Ltd.`).
  - Estimated Repair Cost: `4500.00`.
  - Tap **Submit maintenance request**.
  - **Expect** Maintenance ticket created (`MNT/<financialYear>/<seq>`); status is `Reported`; Asset status transitions to `Under Maintenance` (amber pill).
- [ ] 1.4.11 Negative: Multiple Concurrent Maintenance Requests:
  - On Asset 1, attempt to open another maintenance request.
  - **Expect** rejected with error ("Asset already has an active maintenance job in progress").
- [ ] 1.4.12 **Move Maintenance to In-Progress**:
  - Open the maintenance ticket in Maintenance view → tap **Mark In Progress**.
  - Vendor Job Sheet Ref: `JS-APEX-8820`.
  - Expected Completion Date: 3 days from today.
  - Tap **Update**. **Expect** maintenance status updates to `In Progress`.
- [ ] 1.4.13 **Spare Part Consumption from Inventory**:
  - In maintenance job sheet, link a spare part/consumable drawn from `Central Main Store` (`S31`) (e.g. `1` unit replacement component or cable).
  - Tap **Consume spare part**.
  - **Expect** store stock balance is deducted; stock movement ledger logs an `issue` movement with reference to the maintenance job ID.
- [ ] 1.4.14 Negative: Completion without Cost:
  - On the maintenance job, tap **Complete Maintenance**.
  - Leave Actual Cost empty and tap Submit.
  - **Expect** rejected with validation error ("Actual repair cost is required to complete maintenance").
- [ ] 1.4.15 **Complete Maintenance & Restore Asset**:
  - Enter Actual Cost: `4200.00`.
  - Resolution Notes: `Hinge casing replaced; screen tested operational under warranty rebate`.
  - Post-Repair Asset Condition: `Good`.
  - Tap **Complete maintenance**.
  - **Expect** Maintenance ticket status moves to `Completed`; Asset status is restored to `Available` (green pill); condition updated to `Good`. Total lifetime maintenance cost on asset card updates to `₹4,200.00`.

#### Asset Retirement / Decommissioning
- [ ] 1.4.16 **Retire Asset**:
  - Open Asset 2 (`Dell Latitude 15 - Lab 01`).
  - Tap **Retire Asset**.
  - Decommission Reason: `Damaged beyond economic repair` (or `Obsolete`).
  - Disposal Method: `Scrapped for parts`.
  - Disposal Remarks: `Motherboard liquid ingress; salvageable RAM and storage removed`.
  - Confirmation prompt: Confirm irreversible retirement.
  - **Expect** Asset status transitions to `Retired` (grey pill); asset is permanently locked from future custody assignments, maintenance, or store transfers; excluded from active valuation and store stock.

---

### 1.5 Verification, Scanning & Import (Inv-7, Inv-8)

#### Stock Verification & Discrepancy Reconciliation (Inv-7)
- [ ] 1.5.1 **Create Stock Verification Session**:
  - Open **Stock Verification** → tap **+ New Verification**.
  - Target Store: `Central Main Store` (`S31`).
  - Name: `Q4 Annual Physical Stock Audit`.
  - Scope: Select all active catalog items (or up to 150 lines).
  - Tap **Start Verification**.
  - **Expect** Session created with status `Counting` (`in_progress`); current system book balances are snapshotted (`PEN-BLU-01` = book balance 57, `MILK-PAST-01` = book balance 5, etc.).
- [ ] 1.5.2 **Physical Counting & Line Entry**:
  - In counting view, locate line `PEN-BLU-01`:
    - Physical Count: Enter `55` (discrepancy of `-2` units vs book balance `57`).
  - Locate line `MILK-PAST-01`:
    - Physical Count: Enter `5` (matches book balance, discrepancy `0`).
- [ ] 1.5.3 Negative: Discrepancy Reason Mandatory:
  - Leave Discrepancy Reason blank for line `PEN-BLU-01` and tap **Submit Verification**.
  - **Expect** rejected with error: "Every line with a count variance requires a discrepancy reason".
- [ ] 1.5.4 **Submit Verification with Audit Justification**:
  - For line `PEN-BLU-01`, enter Reason: `2 pens damaged and discarded during packaging without recorded write-off`.
  - Tap **Submit Verification**.
  - **Expect** Session status moves to `Submitted`; outbox notification emitted for inventory approver (`inventory.adjustment.approve`).
- [ ] 1.5.5 **Approver Review & Rejection Workflow**:
  - Open verification session as Approver (`inventory.adjustment.approve`).
  - Tap **Reject** → enter feedback: `Please recount stationery shelf B-3 for the 2 missing pens`.
  - **Expect** Session status reverts to `Rejected` / `Counting` for recount.
- [ ] 1.5.6 **Recount & Final Approval**:
  - As Storekeeper, update physical count of `PEN-BLU-01` to `56` (1 pen located on shelf B-3; variance is now `-1`).
  - Update Reason: `1 pen recovered from shelf B-3; 1 pen confirmed lost`.
  - Resubmit session.
  - As Approver, tap **Approve Verification**.
  - **Expect** Session status transitions to `Approved`; automatic stock adjustment of `-1` unit is written to `S31` stock ledger; `PEN-BLU-01` Available balance in `S31` updates from `57` to `56`; adjustment movement is logged in stock movement history with reference to the verification session.

#### Barcode & Code Scanning
- [ ] 1.5.7 **Item Code Scanning & Search Filter**:
  - In the Verification Counting page (or Stock Overview), focus the scan/search input field.
  - Enter item code `PEN-BLU-01` (simulating barcode scan input).
  - **Expect** the item line `PEN-BLU-01` is immediately matched, highlighted, and scrolled into view. **[EMU]** Camera scanning is tested with manual code entry in emulator.

#### Data Import (Inv-8)
- [ ] 1.5.8 **Catalog CSV Import (Batch Validation)**:
  - Open **Import** → choose **Items (Catalog)**.
  - Upload CSV file with header: `code,name,categoryCode,stockUnit,tracking` and 3 rows:
    - Row 1 (Valid): `NOTE-RULE-01,Ruled Notebook (200 pages),STA,pc,quantity`
    - Row 2 (Invalid Category): `CALC-SCI-01,Scientific Calculator,INVALID_CAT,pc,quantity`
    - Row 3 (Duplicate Code): `PEN-BLU-01,Duplicate Blue Pen,STA,pc,quantity`
  - Tap **Upload & Process Import**.
  - **Expect** import results summary displays:
    - Overall status: `1 of 3 records imported`.
    - Row 1: `Success` (created in catalog).
    - Row 2: `Error: Category code 'INVALID_CAT' does not exist`.
    - Row 3: `Error: Item code 'PEN-BLU-01' already exists`.
- [ ] 1.5.9 Negative: Idempotent Re-Import:
  - Upload the identical CSV file a second time without changes.
  - **Expect** summary displays `0 of 3 records imported`; Row 1 now fails with duplicate code error; no duplicate records created in Firestore.

---

### 1.6 Dashboard and Reports (Inv-7)

#### Executive Dashboard Overview
- [ ] 1.6.1 **Dashboard Multi-Store Filtering**:
  - Open **Dashboard** from the Inventory navigation bar.
  - Switch filter dropdown between **All Stores** and `Central Main Store (S31)`.
  - **Expect** KPI metric cards update dynamically:
    - **Total Items in Catalog**: matches master items count.
    - **Total Stock Balance**: reflects on-hand quantities across stores.
    - **Total Inventory Valuation**: reflects total financial worth based on unit costs.
    - **Low Stock Alerts**: displays badge count `1` (`PEN-BLU-01` below reorder level `70`).
    - **Expiring Batches**: displays alert for `BATCH-M1` expiring in 5 days.
    - **Pending Purchase Requests**: displays count of pending PRs.
    - **Active Purchase Orders**: displays count of open / in-delivery POs.
    - **Registered Assets**: displays `2` registered assets (`1` available, `1` retired).
    - **Active Maintenance Jobs**: displays `0` active (after completing step 1.4.15).
  - Tap on any KPI tile (e.g. Low Stock) → **Expect** navigates directly to the filtered list view.

#### Comprehensive Reporting Suite (17 Standard Reports)
- [ ] 1.6.2 **Execute and Validate All 17 Inventory Reports**:
  - Open **Reports** page. Open each report, apply Store filter (`S31` or `All`), date range, and status filter:
    1. **Stock Summary Report**: Displays current on-hand, allocated, and available balances for each item.
    2. **Item-wise Stock Report**: Detailed breakdown per item with minimum/maximum limits and reorder indicators.
    3. **Stock Movement Ledger**: Complete audit log showing `opening`, `receive`, `issue`, `return`, `transfer`, and `adjust` movements with timestamps and reference IDs.
    4. **Inventory Stock Valuation**: Financial valuation per item and store; verify **Totals Row** at bottom displays correct sum.
    5. **Low Stock Alert Report**: Lists items where available balance <= reorder point (`PEN-BLU-01`).
    6. **Expiry & Shelf-Life Report**: Lists batch-tracked items sorted by earliest expiry date (`MILK-PAST-01`).
    7. **Purchase History Report**: Chronological record of purchased items with vendor names and unit rates.
    8. **Vendor Register & Performance Report**: Lists registered suppliers (`V-APEX`, `V-GLOBAL`) with GSTIN, contact, and active order counts.
    9. **Purchase Requests Report**: Requisitions filtered by status (`Draft`, `Pending`, `Approved`, `Completed`).
    10. **Purchase Orders Report**: PO records with ordered, received, and due quantities, total amounts, and statuses.
    11. **Goods Receipts (GRN) Register**: Inspection results, challan numbers, accepted vs. rejected counts.
    12. **Stock Issuance Report**: Departmental consumption and staff issue records (`Staff 884`).
    13. **Inter-Store Transfers Report**: Dispatched vs. received quantities with in-transit and shortfall tracking.
    14. **Fixed Asset Register**: Complete catalog of serialized assets (`LAP-DELL-15`), purchase prices, locations, and conditions.
    15. **Asset Custody & Assignment History**: Audit trail of staff assignments, transfers, and return dates.
    16. **Asset Maintenance & Repair Cost History**: Maintenance job history with vendor details and total expenditures.
    17. **Stock Verification & Discrepancy Report**: Audit sessions, variance counts, discrepancy reasons, and approved adjustments.
- [ ] 1.6.3 **Report Export (CSV & PDF)**:
  - On **Inventory Stock Valuation** and **Stock Movement Ledger** reports:
    - Tap **Copy CSV** → **Expect** CSV text is copied to clipboard with header row and comma-separated column values.
    - Tap **Download / Print PDF** → **Expect** native PDF document viewer/preview opens with structured tabular layout, column headers, page numbering, and formatted currency totals.

---

### 1.7 Permissions & Cross-Campus Security (Inventory)

Re-seed with different role configurations and verify interface permissions and security rules:

- [ ] 1.7.1 **Role: `teacher`**:
  - Seed with `teacher` role permissions. Restart app.
  - **Expect**:
    - Can only access requisition forms (Issue Requests and Purchase Requests).
    - Cannot view Store Stock balances, Asset register, Maintenance jobs, Vendor master, Quotations, POs, Invoices, or Reports.
- [ ] 1.7.2 **Role: `storekeeper`**:
  - Seed with `storekeeper` role permissions. Restart app.
  - **Expect**:
    - Full operational access to Stock management (Receiving, Issuing, Returns, Transfers, Quarantine, and Physical Verification).
    - Can receive PO deliveries (GRN generation).
    - Read-only or hidden access to Vendor management, Quotations, PO issuance, and Invoices.
- [ ] 1.7.3 **Role: `procurement`**:
  - Seed with `procurement` role permissions. Restart app.
  - **Expect**:
    - Full access to Vendors, Purchase Requests, Quotation comparisons, PO creation/issuance, and Invoices.
    - Prohibited from executing physical store receipts, stock issues, or manual balance adjustments.
- [ ] 1.7.4 **Role: `principal`**:
  - Seed with `principal` role permissions. Restart app.
  - **Expect**:
    - Executive approval privileges for PRs, POs, and Verification adjustments.
    - Read-only access to Dashboards, Master registers, and all 17 Reports.
    - Cannot initiate direct stock movements or operational drafts.
- [ ] 1.7.5 **Campus Isolation & Boundary Enforcement**:
  - Sign in with a user credential assigned exclusively to Campus `32`.
  - Open Stock Overview, Requisitions, and Asset lists.
  - **Expect**:
    - Only Campus `32` stores (`Science Lab Store S32`) and records are visible.
    - Campus `31` stores (`Central Main Store S31`) and balances are excluded.
    - No crashes, blank error screens, or permission exceptions occur; UI handles single-campus scoping gracefully.
- [ ] 1.7.6 **Scheduled Maintenance & Alert Jobs [JOB]**:
  - Run `runDailyInventory` scheduled callable via test harness.
  - **Expect**:
    - Any batch with `expiryDate < today` transitions to `expired` status.
    - System emits outbox notifications for near-expiry batches (within 30 days), overdue PO deliveries past expected date, warranties expiring within 60 days, and assets due for scheduled maintenance.

---

## Part 2 – Library

Open **Library** from the dashboard. Use the `librarian` role for operational workflows.

### 2.1 Masters (Lib-1)

#### Library Facilities Master
- [ ] 2.1.1 **Libraries Setup**:
  - Open **Libraries** → Add Library 1:
    - Code: `L1`
    - Name: `Central High School Library`
    - Campus: `31`
    - Location: `Academic Block A, 1st Floor`
  - Add Library 2:
    - Code: `L2`
    - Name: `Junior School Library`
    - Campus: `32`
    - Location: `Primary Wing Ground Floor`
  - **Expect** Both libraries listed with Active status chips and campus IDs.

#### Classification Categories
- [ ] 2.1.2 **Book Categories**:
  - Tap **Categories** → tap seed defaults button (or verify default categories).
  - **Expect** Standard classification categories created:
    - Code `FIC`: `Fiction & Literature`
    - Code `NFIC`: `Non-Fiction`
    - Code `SCI`: `Science & Mathematics`
    - Code `HIS`: `History, Biography & Geography`
- [ ] 2.1.3 Negative: Category Deactivation Protection:
  - Deactivate category `HIS` (switch off Active toggle).
  - Attempt to create a catalog book assigned to category `HIS`.
  - **Expect** rejected with error ("Category is inactive"). Reactivate category `HIS`.

#### Title Catalogue Management
- [ ] 2.1.4 **Add Catalogue Title 1 (Standard ISBN-13)**:
  - Open **Catalogue** → tap **+ Add Book Title**:
    - Title: `Wings of Fire: An Autobiography`
    - Authors: `A.P.J. Abdul Kalam; Arun Tiwari`
    - Category: `History, Biography & Geography` (`HIS`)
    - Publisher: `Universities Press`
    - Edition: `1st Edition`
    - Publication Year: `1999`
    - ISBN-13: `9788173711466` (valid check digit)
    - Default Price: `350.00`
  - Tap **Save Title**. **Expect** Title saved and listed in catalogue.
- [ ] 2.1.5 **Add Catalogue Title 2**:
  - Title: `Pride and Prejudice`
  - Authors: `Jane Austen`
  - Category: `Fiction & Literature` (`FIC`)
  - Publisher: `Penguin Classics`
  - Publication Year: `2003`
  - ISBN-13: `9780141439518`
  - Default Price: `299.00`
  - Tap **Save Title**. **Expect** Title saved.
- [ ] 2.1.6 **Add Catalogue Title 3 (Without ISBN)**:
  - Title: `School Annual Magazine 2025-26`
  - Authors: `Editorial Board`
  - Category: `Non-Fiction` (`NFIC`)
  - ISBN-13: Leave blank (optional for local/school publications)
  - Default Price: `150.00`
  - Tap **Save Title**. **Expect** Title saved successfully without ISBN.
- [ ] 2.1.7 Negative: Duplicate ISBN-13:
  - Add another title with the identical ISBN-13 `9788173711466`.
  - **Expect** rejected with error ("A title with this ISBN-13 already exists in catalogue").
- [ ] 2.1.8 Negative: Invalid ISBN-13 Check Digit:
  - Attempt to add a title with invalid check digit `9788173711460`.
  - **Expect** rejected with validation error ("Invalid ISBN-13 check digit").
- [ ] 2.1.9 **Catalogue Search & Filter**:
  - In Catalogue search bar, search `kalam` (author) and `wings` (title). **Expect** "Wings of Fire" is returned.
  - Search exact ISBN `9780141439518`. **Expect** "Pride and Prejudice" is returned.

---

### 2.2 Copies & Acquisition (Lib-2)

#### Acquisition & Copy Generation
- [ ] 2.2.1 **Acquire Copies for Title 1 ("Wings of Fire")**:
  - Open Title sheet for "Wings of Fire" → tap **+ Add Acquisition**:
    - Acquisition Type: `Purchase`.
    - Target Library: `Central High School Library` (`L1`).
    - Quantity: `3` copies.
    - Unit Price: `320.00`.
    - Invoice / Bill Ref: `INV-BOOK-2026-01`.
  - Tap **Confirm Acquisition**.
  - **Expect**:
    - Three physical copies created with sequential accession numbers: `ACC-000001`, `ACC-000002`, `ACC-000003`.
    - All 3 copies have status `Available` (green pill).
    - Default barcode equals accession number.
- [ ] 2.2.2 **Acquire Copy for Title 2 ("Pride and Prejudice")**:
  - Open "Pride and Prejudice" → tap **+ Add Acquisition**:
    - Library: `Central High School Library` (`L1`).
    - Quantity: `1` copy. Unit Price: `280.00`.
  - Tap **Confirm Acquisition**.
  - **Expect** Copy created with accession number `ACC-000004`, status `Available`.

#### Copy Attributes, RFID & Spine Labels
- [ ] 2.2.3 **Shelf Location & RFID Assignment**:
  - Open Copy sheet for `ACC-000001`:
    - Shelf Location: `Shelf A-12 / Bay 2`.
    - Condition: `New`.
    - RFID Tag: `RFID-BK-0001`.
  - Tap **Save**. **Expect** Shelf and RFID updated.
- [ ] 2.2.4 Negative: Duplicate RFID Tag on Copies:
  - Open Copy sheet for `ACC-000002` → attempt to assign same RFID `RFID-BK-0001`.
  - **Expect** rejected with error ("RFID tag already assigned to another copy").
  - Enter unique RFID: `RFID-BK-0002`. **Expect** saved.
- [ ] 2.2.5 **Print Spine & Barcode Labels**:
  - On copy `ACC-000001`, tap **Print Label**.
  - **Expect** printable label preview renders accession barcode, call number, title, and library code.
- [ ] 2.2.6 **Inter-Library Copy Relocation**:
  - Open Copy `ACC-000003` ("Wings of Fire").
  - Tap **Transfer Library** → select `Junior School Library` (`L2`).
  - Shelf Location: `Junior Shelf J-04`.
  - **Expect** Copy library updates to `L2`; appears in `L2` copy inventory.
- [ ] 2.2.7 **Copy Maintenance State Transitions**:
  - Open Copy `ACC-000002` → tap **Mark Under Maintenance** (e.g. rebinding required).
  - **Expect** status transitions to `Under Maintenance` (amber); copy is excluded from available loans.
  - Tap **Restore to Circulation**. **Expect** status restored to `Available`.

---

### 2.3 Members & Borrowing Policies (Lib-3)

#### Borrowing Rules & Policies
- [ ] 2.3.1 **Create Primary Student Policy**:
  - Open **Borrowing Policies** → tap **+ New Policy**:
    - Library: `Central High School Library` (`L1`).
    - Member Category: `primary` (Students Class 1-5).
    - Max Books Allowed: `2` books.
    - Loan Period: `7` days.
    - Max Renewals: `1`.
    - Fine Per Day: `2.00` (₹2.00/day).
    - Grace Period: `0` days.
    - Can Reserve Titles: `Yes` (enabled).
  - Tap **Save Policy**. **Expect** Policy created for `L1` · `primary`.
- [ ] 2.3.2 **Create Teacher Policy**:
  - Add Policy 2:
    - Library: `Central High School Library` (`L1`).
    - Member Category: `teacher`.
    - Max Books Allowed: `5` books.
    - Loan Period: `30` days.
    - Max Renewals: `2`.
    - Fine Per Day: `0.00` (no overdue fine).
    - Grace Period: `3` days.
    - Can Reserve Titles: `Yes`.
  - Tap **Save Policy**. **Expect** Policy created for `L1` · `teacher`.
- [ ] 2.3.3 Negative: Invalid Fine Configuration:
  - Create policy with fine type "Per day" and empty or negative fine rate.
  - **Expect** rejected with validation error.

#### Member Enrollment
- [ ] 2.3.4 **Enrol Students**:
  - Open **Members** → tap **+ Enrol Member**:
    - Student 1: ERP ID `501`, Member Category `primary`, Library `L1`, Membership Start Date: `2026-01-01`.
    - Student 2: ERP ID `502`, Member Category `primary`, Library `L1`, Start Date: `2026-01-01`.
    - Student 3: ERP ID `503`, Member Category `primary`, Library `L1`, Start Date: `2026-01-01`.
  - **Expect** All 3 students enrolled with status `Active`, category `primary`, showing 0 active loans.
- [ ] 2.3.5 **Enrol Staff / Teacher**:
  - Enrol Staff ERP ID `884`, Member Category `teacher`, Library `L1`.
  - **Expect** Enrolled with matching teacher borrowing policy.
- [ ] 2.3.6 **Member Search & Status Lifecycle**:
  - Search member by exact ERP ID `501`. **Expect** Student 501 profile returned.
  - Deactivate Member 503 (toggle Active off) → **Expect** status shows `Inactive`; attempts to issue books are rejected. Reactivate Member 503.

---

### 2.4 Circulation (Loans, Renewals, Returns) (Lib-4)

#### Book Issuance
- [ ] 2.4.1 **Issue Book to Student 501**:
  - Open **Circulation** → tap **Issue Book**:
    - Member: Select or type ERP ID `501`.
    - Book Copy: Scan or select `ACC-000001` ("Wings of Fire").
  - Tap **Confirm Issue**.
  - **Expect**:
    - Issue transaction created with number `ISS/<financialYear>/<seq>`.
    - Due Date automatically set to Today + 7 days.
    - Copy `ACC-000001` status transitions from `Available` to `Issued` (blue pill).
    - Student 501 active loan count increments to `1`.
    - Outbox records notification event `library-issued__...` to student 501.
- [ ] 2.4.2 **Issue Second Book to Student 501**:
  - Issue Copy `ACC-000004` ("Pride and Prejudice") to Student 501.
  - **Expect** Issue succeeds; active loan count becomes `2` (reaching the policy limit).
- [ ] 2.4.3 Negative: Borrowing Quota Limit Exceeded:
  - Attempt to issue Copy `ACC-000002` to Student 501.
  - **Expect** rejected with error ("Member has reached maximum borrowing limit of 2 books").
- [ ] 2.4.4 Negative: Issuing an Already Issued Copy:
  - Attempt to issue Copy `ACC-000001` to Student 502.
  - **Expect** rejected with error ("Copy is currently issued and unavailable").

#### Loan Renewal
- [ ] 2.4.5 **Renew Active Loan**:
  - Open loan sheet for `ACC-000001` (Student 501) → tap **Renew Loan**.
  - **Expect** Due date moves forward by 7 days; renewal count increments to `1`.
- [ ] 2.4.6 Negative: Renewal Limit Reached:
  - Tap **Renew Loan** a second time on `ACC-000001`.
  - **Expect** rejected with error ("Maximum renewal limit of 1 reached for this loan").

#### Book Returns
- [ ] 2.4.7 **Return Book in Good Condition**:
  - Open loan sheet for `ACC-000004` ("Pride and Prejudice") → tap **Return Book**.
  - Return Condition: `Good`.
  - Remarks: `Returned on time in clean condition`.
  - Tap **Confirm Return**.
  - **Expect**:
    - Loan status marked `Returned`.
    - Copy `ACC-000004` status restores to `Available`.
    - Student 501 active loan count decreases from `2` to `1`.
    - Outbox records notification `library-returned__...`.

---

### 2.5 Reservations & Hold Queue (Lib-5)

Setup: Copy `ACC-000001` is currently on loan to Student 501. No other copies of "Wings of Fire" are available at Library `L1` (Copy 2 is under maintenance/quarantined, Copy 3 moved to `L2`).

- [ ] 2.5.1 **Queue Reservation 1 (Student 502)**:
  - Open Title "Wings of Fire" → tap **Reserve Title**:
    - Member: Student ERP ID `502`.
    - Target Library: `Central High School Library` (`L1`).
  - Tap **Confirm Reservation**.
  - **Expect** Reservation created with status `Waiting`; Queue Position is `1`.
- [ ] 2.5.2 **Queue Reservation 2 (Student 503)**:
  - Place second reservation for Student ERP ID `503` on "Wings of Fire".
  - **Expect** Reservation created with status `Waiting`; Queue Position is `2`.
- [ ] 2.5.3 Negative: Reserving a Title with Available Shelf Copies:
  - Attempt to place a reservation on "Pride and Prejudice" (which has available copy `ACC-000004`).
  - **Expect** rejected with error ("Reservations cannot be placed while shelf copies are available in this library").
- [ ] 2.5.4 Negative: Duplicate Active Reservation:
  - Attempt to place another reservation for Student 502 on "Wings of Fire".
  - **Expect** rejected with error ("Member already has an active reservation for this title").
- [ ] 2.5.5 **Fulfill Reservation on Return (Hold Activation)**:
  - In Circulation, return copy `ACC-000001` from Student 501.
  - **Expect**:
    - Copy status does NOT become available to general circulation; status transitions to `Reserved` (purple pill).
    - Student 502's reservation status changes from `Waiting` to `Ready`.
    - Hold Expiry Date is automatically set to Today + 3 days.
    - Outbox records notification `library-rsv-ready__...` notifying Student 502 that the book is held for pickup.
- [ ] 2.5.6 Negative: Issuing a Held Copy to Another Member:
  - Attempt to issue copy `ACC-000001` to Student 503 (queue position 2).
  - **Expect** rejected with error ("Copy is currently held on reservation for Member 502").
- [ ] 2.5.7 **Issue Held Copy to Target Member**:
  - Issue copy `ACC-000001` to Student 502.
  - **Expect** Issue allowed; reservation status updates to `Fulfilled`; active loans for Student 502 becomes `1`.
- [ ] 2.5.8 **Reservation Cancellation**:
  - Open Student 503's reservation → tap **Cancel Reservation**.
  - **Expect** Reservation status moves to `Cancelled`.
- [ ] 2.5.9 **Hold Expiry Job [JOB]**:
  - For a reservation in `Ready` status whose hold date has passed, execute `runHoldExpiry`.
  - **Expect** Reservation status transitions to `Expired`; copy either allocates to next queued member or reverts to `Available`.

---

### 2.6 Fines, Penalties, Lost & Damaged Incidents (Lib-6)

#### Overdue Fine Calculation & Enforcement
- [ ] 2.6.1 **Overdue Fine Generation**:
  - In Emulator Firestore UI, edit loan for `ACC-000001` (issued to Student 502): change `dueDate` to 3 days in the past (`today - 3 days`).
  - Return the book via Circulation.
  - **Expect**:
    - Overdue fine generated: 3 days × ₹2.00/day = `₹6.00`.
    - Fine record created with status `Unpaid` (`outstanding` = `₹6.00`).
    - Member Student 502 status is flagged `Blocked` (fines pending).
    - Outbox records notification event `library-fine__...`.
- [ ] 2.6.2 Negative: Blocked Member Borrowing Prevention:
  - Attempt to issue any book to Student 502.
  - **Expect** rejected with error ("Member is blocked due to outstanding unpaid fines").

#### Fine Waivers & Payments
- [ ] 2.6.3 **Partial Fine Waiver**:
  - Open **Fines & Penalties** → locate Student 502's ₹6.00 fine.
  - Tap **Waive Fine**:
    - Waive Amount: `3.00` (₹3.00).
    - Justification: `Medical illness leave with doctor certificate`.
  - Tap **Confirm Waiver**.
  - **Expect** Fine status updates to `Partially paid`; Outstanding fine drops to `₹3.00`; Member remains blocked until settled.
- [ ] 2.6.4 **Fine Payment Collection**:
  - On the same fine, tap **Record Payment**:
    - Payment Amount: `3.00`.
    - Payment Method: `Cash`.
    - Receipt / Payment Reference: `RCP-LIB-2026-441`.
  - Tap **Save Payment**.
  - **Expect** Fine status updates to `Paid`; Outstanding becomes `₹0.00`; Student 502 status is automatically unblocked.

#### Damaged and Lost Incidents
- [ ] 2.6.5 **Return Copy as Damaged**:
  - Issue copy `ACC-000004` to Student 501.
  - Return copy `ACC-000004` selecting Condition `Damaged`:
    - Damage Description: `Water stains and ripped pages from chapter 3`.
    - Charge Member: `Yes` · Penalty Charge: `150.00`.
  - Tap **Confirm Return**.
  - **Expect**:
    - Incident ticket created (`INC/<financialYear>/<seq>`); status is `Reported`.
    - Copy status transitions to `Damaged` (red pill); removed from circulation.
    - Fine of `₹150.00` assessed against Student 501; member blocked pending payment.
- [ ] 2.6.6 **Resolve Damaged Incident (Repair vs Replacement)**:
  - Open **Lost & Damaged** → open incident for `ACC-000004`.
  - Tap **Resolve Incident**:
    - Resolution: `Repaired`.
    - Repair Notes: `Rebound and dried by central bookbinder`.
  - Tap **Confirm Resolution**.
  - **Expect** Incident marked `Resolved`; Copy status restored to `Available`.
- [ ] 2.6.7 **Mark Book as Lost**:
  - Issue a copy to Student 501. On loan sheet, tap **Mark Lost**:
    - Replacement Book Cost: `299.00`.
    - Administrative Processing Fee: `50.00`.
    - Total Charge: `349.00`.
  - Tap **Confirm Lost**.
  - **Expect** Loan closed with status `Lost`; Copy status marked `Lost`; fine of `₹349.00` raised; incident recorded.

---

### 2.7 Inter-Library Transfers & Verification (Lib-7)

#### Inter-Library Transfers
- [ ] 2.7.1 **Request Inter-Library Transfer**:
  - Open **Transfers** → tap **+ Request Transfer**:
    - Origin Library (From): `Central High School Library` (`L1`, Campus 31).
    - Destination Library (To): `Junior School Library` (`L2`, Campus 32).
    - Copies: Add `ACC-000004` ("Pride and Prejudice").
    - Reason: `Required for Class 8 inter-school literature workshop`.
  - Tap **Submit Transfer Request**.
  - **Expect** Transfer record created (`LTR/<financialYear>/<seq>`); status `Requested`; approvers notified.
- [ ] 2.7.2 **Approve and Dispatch Transfer**:
  - As authorized librarian/admin, tap **Approve Transfer**.
  - Tap **Dispatch Transfer**.
  - **Expect** Transfer status updates to `In Transit` (blue); copy `ACC-000004` marked `In Transit`; removed from `L1` shelf.
- [ ] 2.7.3 Negative: Issuing an In-Transit Copy:
  - Attempt to issue `ACC-000004` while in transit.
  - **Expect** rejected with error ("Copy is currently in transit between libraries").
- [ ] 2.7.4 **Receive Transfer at Destination Library**:
  - Switch user/view to Campus `32` (`Junior School Library L2`).
  - Open transfer `LTR/...` → tap **Receive Copies**.
  - Assign New Shelf: `Shelf J-08`.
  - Tap **Confirm Receipt**.
  - **Expect** Transfer marked `Received` (green); copy `ACC-000004` now belongs to `L2` and is available for circulation at `L2`.

#### Library Stock Verification
- [ ] 2.7.5 **Initiate Library Stock Verification**:
  - Open **Stock Verification** → tap **+ New Verification**:
    - Library: `Central High School Library` (`L1`).
    - Title/Shelf Scope: All copies at `L1`.
  - Tap **Start Verification**.
  - **Expect** System snapshots expected shelf copies; issued copies on active loans are flagged as `On Loan` and excluded from shelf discrepancies.
- [ ] 2.7.6 **Barcode Scanning & Discrepancy Reconciliation**:
  - Scan all expected accession numbers except one (simulating a missing book).
  - Scan an accession number belonging to `L2` (unexpected copy).
  - **Expect** Verification screen categorizes copies into `Matched`, `Missing (1)`, and `Unexpected (1)`.
  - Tap **Submit Verification**.
  - Approve session: Mark missing copy as `Investigate` / `Lost` and unexpected copy as `Transferred In`.
  - **Expect** Copy records and catalogue counts updated accordingly.

---

### 2.8 Dashboard, Reports, Import & Automation (Lib-8)

#### Library Executive Dashboard
- [ ] 2.8.1 **Dashboard KPI Validation**:
  - Open **Library Dashboard**. Toggle between **All Libraries** and `Central High School Library (L1)`.
  - **Expect** 12 KPI cards match actual database records:
    - **Total Catalog Titles**
    - **Total Book Copies**
    - **Available Copies on Shelf**
    - **Currently Issued Loans**
    - **Overdue Loans**
    - **Active Reservations (Waiting + Ready)**
    - **Lost Copies Count**
    - **Damaged Copies Count**
    - **Student Members Enrolled**
    - **Staff / Teacher Members Enrolled**
    - **Pending Returns Expected Today**
    - **Total Outstanding Fines Balance (₹)**
  - Tapping each card opens the corresponding management screen.

#### Library Management Reports (15 Reports)
- [ ] 2.8.2 **Execute All 15 Library Reports**:
  - Open **Reports** and verify each report with library and date range filters:
    1. **Catalogue Master Register**
    2. **Accession Register (All Copies)**
    3. **Stock & Shelf Availability Report**
    4. **Active Circulation & Issued Books**
    5. **Overdue Loans & Aging Report** (shows days overdue and calculated fines)
    6. **Member Borrowing History Report**
    7. **Fines, Penalties & Collections Report** (totals row verified)
    8. **Lost Books Register**
    9. **Damaged Books & Incident Log**
    10. **Book Acquisitions & Expenditures Report**
    11. **Inter-Library Transfers Log**
    12. **Stock Verification & Audit History**
    13. **Most Popular / Highest Circulated Titles**
    14. **Inactive / Zero-Circulation Titles**
    15. **Member Category Utilization Summary**
- [ ] 2.8.3 **Export Capabilities**:
  - On **Accession Register** and **Fines & Collections** reports:
    - Tap **Copy CSV** → **Expect** formatted CSV copied to clipboard.
    - Tap **Download / Print PDF** → **Expect** formatted PDF opens with library header and totals summary.

#### Batch Import (CSV)
- [ ] 2.8.4 **Import Catalogue CSV**:
  - In **Import** → select **Catalogue Titles**.
  - Upload CSV with header `title,authors,categoryCode,isbn13`:
    - Row 1 (Good): `Discovery of India,Jawaharlal Nehru,HIS,9780143031031`
    - Row 2 (Invalid Category): `Modern Physics,H.C. Verma,INVALID_CAT,9788177091878`
    - Row 3 (Duplicate ISBN): `Wings of Fire,A.P.J. Abdul Kalam,HIS,9788173711466`
  - **Expect** "1 of 3 records imported" with granular row-level error reports.
- [ ] 2.8.5 **Import Copies CSV**:
  - Upload copies CSV (`isbn13,libraryCode,quantity,price`) for the newly imported title.
  - **Expect** Generated accession numbers assigned and copies created as `Available`.

#### Scheduled Notification Automation [JOB]
- [ ] 2.8.6 **Execute `runDailyLibrary`**:
  - Run the daily library scheduled callable.
  - **Expect**:
    - Loans due in 2 days receive `library-due-soon__...` outbox event.
    - Overdue loans past due date receive `library-overdue__...__<date>` outbox event.
    - Memberships expiring within 7 days receive `library-member-expiring__...`.
    - Reservation holds expiring within 24 hours receive `library-rsv-expiring__...`.
    - Re-executing the job on the same day produces no duplicate outbox events.

---

### 2.9 Permissions & Role Security (Library)

- [ ] 2.9.1 **Role: `teacher`**:
  - Sign in as `teacher`. Open Library.
  - **Expect** Access restricted to **Catalogue Search** and personal loan history. Circulation, Member management, Copies admin, and Reports are hidden.
- [ ] 2.9.2 **Role: `principal`**:
  - Sign in as `principal`.
  - **Expect** Read-only access to Dashboard, Catalogue, Member registers, and Reports. Circulation desk operational buttons are disabled.
- [ ] 2.9.3 **Role: `librarian` (Cross-Campus Scoping)**:
  - Sign in as a librarian assigned exclusively to Campus `32` (`Junior School Library L2`).
  - **Expect** Library views, loans, and circulation lists default to `L2`; queries cannot view or alter Campus `31` (`L1`) active loans or shelf copies.
- [ ] 2.9.4 **Parent & Student Rules Validation**:
  - Security rules ensure students and parents can read catalog titles and their own active loans/fines, but cannot write or modify records (`melos run firebase:test`).

---

## Part 3 – Cross-cutting

- [ ] 3.1 Double-tap any save/issue/return button. **Expect** one record only.
- [ ] 3.2 Stop the emulator mid-action, then act. **Expect** a clear "needs connection" style error, nothing half-saved.
- [ ] 3.3 Open any list with no data. **Expect** an empty state, not a spinner or crash.
- [ ] 3.4 Every created document has a matching `auditLogs` entry.
- [ ] 3.5 `melos run firebase:test` passes (functions and rules tests use their own emulator ports through the project config).
