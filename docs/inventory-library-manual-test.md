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
melos run emulators:seed -- --school <sid> --roles admin=<roleId>
```

To test other roles later, re-run with `--force` and a different mapping, for example `--roles librarian=<roleId> --force`. Role names: `admin`, `principal`, `inventoryManager`, `storekeeper`, `procurement`, `librarian`, `teacher`.

### 0.3 Run the app

Launch config **icueadmin [Dev + Emulators · Android]** (or iOS). It signs in with a locally built unsigned token. Open Emulator UI → Firestore → `schools/<sid>/userAccess/<your uid>`.

- [ ] 0.3.1 `perms` is non-empty, `cmp` lists your campus IDs (or `all: true`). **Expect** the app shows Inventory and Library tiles. If not, the role ID in the seed does not match your login.

### 0.4 Test data you will type

Use two campuses (31 and 32 below; use your real campus IDs). Keep a scratch list: ERP student IDs 501, 502, 503, ERP teacher/staff ID 884 (yours), a second staff ID.

### 0.5 Scheduled jobs

`dailyInventory`, `dailyLibrary` and `holdExpiry` do not run by themselves in the emulator. Steps tagged **[JOB]** can only be checked once someone triggers them (a small script calling `runDailyInventory` / `runDailyLibrary` / `runHoldExpiry` is not in the repo yet). Skip those steps for now and mark them blocked.

### 0.6 What to watch in the Emulator UI during the whole run

- `schools/<sid>/auditLogs`: one entry per change.
- `schools/<sid>/outbox` and `notifications`: what would have been pushed. Push itself is never sent from the emulator. **[EMU]**
- `schools/<sid>/requests`: repeating the same action (double tap) must not create a second record.

---

## Part 1 – Inventory

Open **Inventory** from the dashboard.

### 1.1 Masters (Inv-1)

- [ ] 1.1.1 **Categories** → seed defaults (empty-state button). **Expect** FRS default categories and units appear.
- [ ] 1.1.2 Add a category `GEN` "General"; add subcategory under it. **Expect** saved. Add `GEN` again. **Expect** "already exists" error (codes are unique, case-insensitive).
- [ ] 1.1.3 Deactivate the subcategory, then try to create an item in it. **Expect** rejected (inactive category).
- [ ] 1.1.4 **Units** → add `box`. **Expect** saved.
- [ ] 1.1.5 **Stores** → add `S31` on campus 31 and `S32` on campus 32. **Expect** both listed; campus cannot be edited later.
- [ ] 1.1.6 **Items** → add three items: `PEN` (quantity tracked), `MILK` (batch + expiry tracked), `LAP` (asset tracked). Set min and reorder levels on PEN. **Expect** each saved with its tracking method.
- [ ] 1.1.7 Item details → add a variant on PEN (for example colour). **Expect** variant listed.
- [ ] 1.1.8 Items list → search "pen" (whole word). **Expect** PEN found. **[EMU]** Type-ahead (`pe`) finds nothing, that is expected.

### 1.2 Stock (Inv-2)

Open **Stock**.

- [ ] 1.2.1 Receive 100 PEN into S31 (source: opening stock). **Expect** balance Available = 100; movement history shows `receive`.
- [ ] 1.2.2 Receive 20 MILK with batch `B1`, expiry in 10 days, and 10 MILK batch `B2`, expiry in 30 days. **Expect** two balances, one per batch. Then try a batch with a past expiry date and note what happens (an expired batch must never be issuable).
- [ ] 1.2.3 Receive an asset-tracked item (LAP) through stock receive. **Expect** rejected: asset items are received through purchase orders and registered individually.
- [ ] 1.2.4 **Issue requests** → as a requester create a request for 30 PEN from S31. **Expect** status pending.
- [ ] 1.2.5 As approver, approve it. **Expect** status approved; requester gets an `outbox` event.
- [ ] 1.2.6 Issue it to a recipient (staff 884). **Expect** PEN Available = 70; an issue number is created.
- [ ] 1.2.7 Try to issue 500 PEN. **Expect** refused, stock never goes below zero.
- [ ] 1.2.8 Acknowledge the issue, then return 10 PEN good. **Expect** Available = 80. Return 25 (more than outstanding). **Expect** refused.
- [ ] 1.2.9 Return 5 PEN as damaged. **Expect** goes to the **damaged-expired register**, not to Available.
- [ ] 1.2.10 **Transfers** → request 20 PEN from S31 to S32, dispatch, then receive only 15. **Expect** in-transit tracked, partial receipt recorded, discrepancy of 5 shown, S31 −20, S32 +15.
- [ ] 1.2.11 Adjust PEN in S31 by −3 with a reason. **Expect** movement `adjust`; Available reduced by 3.
- [ ] 1.2.12 Report 4 PEN as damaged from the stock sheet, then resolve one entry. **Expect** register updated, Available reduced.
- [ ] 1.2.13 Set PEN reorder level above current stock. **Expect** low-stock outbox event `lowstock__…`; **Dashboard** shows a low-stock line.
- [ ] 1.2.14 Issue MILK twice. **Expect** the earliest-expiry batch is used first (FEFO).

### 1.3 Procurement (Inv-3, 4, 5)

- [ ] 1.3.1 **Vendors** → add `V1`. Deactivate and try to set it as an item's preferred vendor. **Expect** rejected.
- [ ] 1.3.2 **Purchase requests** → new request: 10 LAP and 50 PEN, priority high. Save as draft, edit, submit. **Expect** number `PR/<fy>/<seq>`; approvers get an outbox event.
- [ ] 1.3.3 Only the requester can edit/cancel: open as another user. **Expect** no edit actions.
- [ ] 1.3.4 Approver → **revise** with a comment. **Expect** returned to requester. Resubmit, then approve. **Expect** procurement gets an outbox event.
- [ ] 1.3.5 **Quotations** → add two quotations from two vendors for the approved request. **Expect** comparison view; totals computed; quantities cannot exceed the request.
- [ ] 1.3.6 Select one quotation with a reason. **Expect** one selected per request.
- [ ] 1.3.7 **Purchase orders** → create from the quotation (vendor and prices come from it), issue it. **Expect** number `PO/<fy>/<seq>`; request shows quantity ordered; status partially ordered or ordered.
- [ ] 1.3.8 Revise the PO unit price. **Expect** previous version kept in revisions; acknowledgement resets. Acknowledge it.
- [ ] 1.3.9 Open the PO → PDF. **Expect** preview/print/share opens.
- [ ] 1.3.10 **Receive goods** against the PO: accept 30 PEN, reject 5 now, leave the rest. **Expect** PO `partially_received`; PEN stock +30 at the PO unit price; rejected quantity recorded but not in stock.
- [ ] 1.3.11 Receive the rest. **Expect** PO `fully_received`; request `completed`.
- [ ] 1.3.12 Try to receive more than still due. **Expect** refused.
- [ ] 1.3.13 **Vendor invoices** → record an invoice from the PO; add the same invoice number again for the vendor. **Expect** second one refused.
- [ ] 1.3.14 Record a partial payment, then full. **Expect** `unpaid` → `partially_paid` → `paid`; paying more than total is refused. Cancel a paid invoice. **Expect** refused; cancel an unpaid one **Expect** allowed.
- [ ] 1.3.15 Cancel a PO that has deliveries. **Expect** refused or limited as shown by the error message.

### 1.4 Assets (Inv-6)

- [ ] 1.4.1 **Assets** → register two LAP units linked to the PO. **Expect** IDs `AST/<fy>/<seq>`; cannot register more than the accepted PO quantity.
- [ ] 1.4.2 Open an asset → QR label. **Expect** PDF label preview.
- [ ] 1.4.3 Assign to staff 884. **Expect** status assigned; custody history shows it. Try assigning again. **Expect** refused (only available assets).
- [ ] 1.4.4 Transfer custody to another staff ID. **Expect** previous assignment closed and kept.
- [ ] 1.4.5 Return it damaged. **Expect** status `damaged`.
- [ ] 1.4.6 **Maintenance** → raise a request on it, then open a second one. **Expect** second refused (one live request per asset).
- [ ] 1.4.7 Move to in progress. **Expect** asset `under_repair`. Complete without cost. **Expect** refused; complete with cost. **Expect** asset restored.
- [ ] 1.4.8 Add a spare part drawn from a store. **Expect** an `issue` movement in stock (needs stock-operate permission).
- [ ] 1.4.9 Asset sheet → set an RFID tag, then set the same tag on the other asset. **Expect** second refused (unique); move tag after clearing the first.
- [ ] 1.4.10 Retire an asset. **Expect** status `retired`.

### 1.5 Verification, scanning, import (Inv-7, 8)

- [ ] 1.5.1 **Stock verification** → create for S31 (pick up to 150 lines). **Expect** expected quantities snapshotted.
- [ ] 1.5.2 Count every line; make one differ without a reason, then submit. **Expect** refused until each difference has a reason.
- [ ] 1.5.3 Submit with reasons. **Expect** status submitted.
- [ ] 1.5.4 As approver (`inv.adjustment.approve`) reject once. **Expect** back to counting. Resubmit and approve. **Expect** adjustments written, stock matches counts.
- [ ] 1.5.5 Type an item code into the scan field of the counting page. **Expect** the line is found. **[EMU]** Camera scanning is untested on a device.
- [ ] 1.5.6 Turn the emulator off (stop it), save a count, restart it. **Expect** count saved locally then synced. Optional.
- [ ] 1.5.7 **Import** → items CSV with a header row `code,name,categoryCode,stockUnit,tracking` and three rows: one good, one with an unknown `categoryCode`, one duplicate code. **Expect** summary "1 of 3 imported" with row-level errors; re-running the same file adds nothing new.

### 1.6 Dashboard and reports (Inv-7)

- [ ] 1.6.1 **Dashboard** with All stores, then one store. **Expect** tiles change with the store; counts agree with what you created (items, available, low, expiring, pending requests, open POs, assets, maintenance).
- [ ] 1.6.2 Open each of the 17 **Reports** (stock summary, item-wise, movement, valuation, low stock, expiry, purchase history, vendors, purchase requests, purchase orders, goods receiving, issuance, transfers, asset register, asset assignment, maintenance, verification). **Expect** rows for what you created; apply the date range and status filters; totals row appears where numbers are summed.
- [ ] 1.6.3 On two reports use **Copy CSV** and **PDF**. **Expect** CSV on the clipboard, PDF preview opens.

### 1.7 Permissions (Inventory)

Re-seed with a different role, restart the app, and for each role check which tiles show.

- [ ] 1.7.1 `teacher`: only requesting an issue or purchase; no Stock, Assets list management, Reports.
- [ ] 1.7.2 `storekeeper`: stock operations, no vendors or purchase orders.
- [ ] 1.7.3 `procurement`: purchase requests, quotations, POs, vendors; cannot receive stock.
- [ ] 1.7.4 `principal`: approvals and read-only reports/dashboard; cannot create stock.
- [ ] 1.7.5 A user on campus 32 only cannot see campus 31 balances. **Expect** empty lists, no crash.
- [ ] 1.7.6 [JOB] Expired batch moves to expired; near-expiry, PO overdue, warranty, maintenance-due notices appear in `outbox` after `runDailyInventory`.

---

## Part 2 – Library

Open **Library** from the dashboard. Use the librarian role for most steps.

### 2.1 Masters (Lib-1)

- [ ] 2.1.1 **Libraries** → add `L1` "Main" campus 31 and `L2` "Junior" campus 32. **Expect** both listed.
- [ ] 2.1.2 **Categories** → seed defaults. **Expect** default FRS book categories.
- [ ] 2.1.3 **Catalogue** → add "Wings of Fire" with a valid ISBN-13. Add again with the same ISBN. **Expect** "already exists".
- [ ] 2.1.4 Add a title with an invalid ISBN check digit. **Expect** refused. Add a title with no ISBN. **Expect** saved.
- [ ] 2.1.5 Search "fire" (whole word) and an exact ISBN. **Expect** both find the title. **[EMU]** The text search is a scan fallback.
- [ ] 2.1.6 Deactivate a category, then add a title to it. **Expect** refused.

### 2.2 Copies and acquisition (Lib-2)

- [ ] 2.2.1 Book page → **Add acquisition**: purchase, 3 copies, library L1. **Expect** accession numbers `ACC-000001…3` and three copies, all available; barcode equals accession number.
- [ ] 2.2.2 **Copies** → open one, change shelf/condition, add an RFID tag; reuse the same tag on another copy. **Expect** duplicate refused.
- [ ] 2.2.3 Move a copy to L2. **Expect** library changes; **Copies** shows it there.
- [ ] 2.2.4 Set a copy to `under_maintenance`, then back. **Expect** allowed; set `lost`. **Expect** allowed only from valid states.
- [ ] 2.2.5 Print labels. **Expect** label preview opens.
- [ ] 2.2.6 Scan an accession number into a copy search. **Expect** copy found.

### 2.3 Members and policies (Lib-3)

- [ ] 2.3.1 **Borrowing policies** → L1, category `primary`: 2 books, 7 days, 1 renewal, fine per day 2, grace 0, can reserve. **Expect** saved; making the same library/category again edits it.
- [ ] 2.3.2 Add a policy with fine type per day and amount 0. **Expect** refused.
- [ ] 2.3.3 **Members** → enrol student 501, 502, 503 (category `primary`, library L1, start in the past) and teacher 884 (category `teacher` without a matching policy). **Expect** teacher flagged "no policy".
- [ ] 2.3.4 Search a member by exact ERP ID; search a missing one. **Expect** miss opens the enrol sheet.
- [ ] 2.3.5 Deactivate and reactivate a member. **Expect** status updates.

### 2.4 Circulation (Lib-4)

- [ ] 2.4.1 **Circulation** → issue `ACC-000001` to student 501. **Expect** issue number `ISS/…`, due date = today + 7, copy `issued`, member active loans = 1. Outbox: `lib-issued__…` to ward 501.
- [ ] 2.4.2 Issue a second and a third book to 501. **Expect** third refused: limit of 2.
- [ ] 2.4.3 Issue to the teacher with no policy. **Expect** refused.
- [ ] 2.4.4 Try issuing an already issued copy. **Expect** refused.
- [ ] 2.4.5 Renew a loan. **Expect** due date moves by the loan's days; renew again. **Expect** refused (limit 1).
- [ ] 2.4.6 Return a copy in good condition. **Expect** copy available, loans −1, `lib-returned__…` in outbox.
- [ ] 2.4.7 Enrol a member whose end date is yesterday, then try to issue. **Expect** refused (membership not valid).

### 2.5 Reservations (Lib-5)

Setup: one title with a single copy, issued to 501.

- [ ] 2.5.1 **Reservations** → reserve it for 502, then 503. **Expect** queue positions 1 and 2.
- [ ] 2.5.2 Reserve a title that still has a shelf copy. **Expect** refused.
- [ ] 2.5.3 Reserve it a second time for 502. **Expect** refused (one live reservation per member).
- [ ] 2.5.4 Return the copy. **Expect** copy `reserved`, reservation of 502 `ready` with a hold date (default 3 days), `rsv-ready__…` in outbox.
- [ ] 2.5.5 Try issuing the held copy to 503. **Expect** refused. Issue to 502. **Expect** allowed; reservation `fulfilled`.
- [ ] 2.5.6 Cancel 503's reservation. **Expect** status cancelled.
- [ ] 2.5.7 Add a new acquisition of that title while someone waits. **Expect** the waiting member's reservation becomes ready automatically.
- [ ] 2.5.8 [JOB] Let a hold pass its date, run `runHoldExpiry`. **Expect** reservation `expired`, copy goes to the next in queue or back to available. Check **Reservations** with the Expired filter.

### 2.6 Fines, lost and damaged (Lib-6)

- [ ] 2.6.1 In Emulator UI set a loan's `dueOn` to 3 days ago, then return it. **Expect** fine = 3 × 2 = 6 (grace 0); fine row `outstanding`; member `blocked`; `lib-fine__…` in outbox.
- [ ] 2.6.2 Try issuing to the blocked member. **Expect** refused.
- [ ] 2.6.3 **Fines & Penalties** → waive part of the fine with a reason. **Expect** status `partially_paid`/outstanding reduced; waive the rest. **Expect** `waived`, member unblocked.
- [ ] 2.6.4 Create another overdue fine; record a payment with a reference until fully paid. **Expect** `paid`; member unblocked. Overpaying is refused.
- [ ] 2.6.5 Return a book as **damaged**. **Expect** copy `damaged`, an open incident, `lib-incident__…` to ward and librarians.
- [ ] 2.6.6 **Lost & Damaged** → resolve it as `repaired`. **Expect** copy goes to the next waiting reservation or shelf.
- [ ] 2.6.7 Loan sheet → **Mark lost** with a charge. **Expect** loan `lost`, copy `lost`, replacement fine, member blocked, incident created.
- [ ] 2.6.8 Report an incident on a copy that is on loan or on hold. **Expect** refused; report one on an available copy with a charge and a responsible member. **Expect** copy off circulation, fine raised.
- [ ] 2.6.9 Resolve a lost incident as `dismissed` (book found). **Expect** copy returns to circulation. Try to lower the charge on resolve. **Expect** refused (waive the fine instead).

### 2.7 Transfers and verification (Lib-7)

- [ ] 2.7.1 **Transfers** → request 2 available copies from L1 to L2. **Expect** number `LTR/…`; approvers get an outbox event.
- [ ] 2.7.2 Dispatch before approval. **Expect** refused. Approve (needs `lib.settings`), then dispatch. **Expect** copies `in_transit`; destination staff get an event.
- [ ] 2.7.3 Try issuing an in-transit copy. **Expect** refused.
- [ ] 2.7.4 Receive one copy at L2 (as campus 32 staff) with a shelf. **Expect** status `partially_received`; that copy now belongs to L2 and is available. Receive the other. **Expect** `received`.
- [ ] 2.7.5 **Stock verification** → create for L1 (optionally one shelf). **Expect** expected list excludes issued copies (they are shown as on loan).
- [ ] 2.7.6 Scan all but one expected accession, plus one that belongs elsewhere. **Expect** missing and unexpected lists.
- [ ] 2.7.7 Submit. **Expect** `submitted` and an event to approvers. Submit a session where everything matches. **Expect** goes straight to `approved`.
- [ ] 2.7.8 Approve with the missing copy marked **lost** and the unexpected available copy **moved** in. **Expect** statuses updated; leaving a missing copy alone is recorded as `investigate`.

### 2.8 Dashboard, reports, import, notifications (Lib-8)

- [ ] 2.8.1 **Dashboard** (All libraries, then L1). **Expect** the 12 tiles agree with your data: titles (hidden for a single library), copies, available, issued, overdue, reserved (waiting + ready), lost, damaged, student and teacher members, pending returns, outstanding fines amount.
- [ ] 2.8.2 Tap tiles. **Expect** they open the matching screen (Catalogue, Copies, Circulation, Reservations, Members, Fines).
- [ ] 2.8.3 **Reports** → open all 15 (catalogue, accession register, stock, available, issued, overdue, member history, fines, lost, damaged, acquisition, transfers, verification, popular, inactive). **Expect** rows from your data; library, date range and status filters narrow them; search filters the loaded rows by member, author, category; Overdue shows days overdue.
- [ ] 2.8.4 Popular books after several issues of one title. **Expect** it is first with the right loan count. Inactive books. **Expect** titles with copies and no loan in the period.
- [ ] 2.8.5 **Copy CSV** and **PDF** on two reports. **Expect** both work; totals row on Fine and Overdue.
- [ ] 2.8.6 **Import** → catalogue CSV (header `title,authors,categoryCode,isbn13`) with a good row, a duplicate ISBN and an unknown category. **Expect** "1 of 3 imported" with row errors. Authors separated by `;`.
- [ ] 2.8.7 Import copies (`isbn13,libraryCode,qty,price`) for the imported title. **Expect** copies with generated accession numbers. Import members (`memberType,erpId,memberCategory,libraryCodes,start`). **Expect** members created; existing member rejected.
- [ ] 2.8.8 Open the import page as a role without `lib.catalogue.manage`. **Expect** only the types you may run.
- [ ] 2.8.9 [JOB] After `runDailyLibrary`: a loan due in 2 days gets `lib-due-soon__…`, a past-due loan gets `lib-overdue__…__<date>`, a membership ending within 7 days gets `lib-member-expiring__…`, a hold ending within 1 day gets `lib-rsv-expiring__…`. Running it twice adds nothing.

### 2.9 Permissions and parent view (Library)

- [ ] 2.9.1 `teacher`: Library shows Catalogue only. No Copies, Circulation, Reports.
- [ ] 2.9.2 `principal`: Dashboard and Reports and Members read-only; no Circulation.
- [ ] 2.9.3 `librarian`: everything; a campus-32-only librarian cannot see campus-31 loans. **Expect** empty lists or an error message, no crash. (Existing list screens query without a campus filter, so note any permission-denied here.)
- [ ] 2.9.4 Parent view is rules-only, covered by the automated rules tests (`melos run firebase:test`). There is no parent screen in this repo yet.

---

## Part 3 – Cross-cutting

- [ ] 3.1 Double-tap any save/issue/return button. **Expect** one record only.
- [ ] 3.2 Stop the emulator mid-action, then act. **Expect** a clear "needs connection" style error, nothing half-saved.
- [ ] 3.3 Open any list with no data. **Expect** an empty state, not a spinner or crash.
- [ ] 3.4 Every created document has a matching `auditLogs` entry.
- [ ] 3.5 `melos run firebase:test` passes (functions and rules tests use their own emulator ports through the project config).
