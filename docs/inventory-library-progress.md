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

- [ ] Firestore database `icueadmin` (Standard, Native, `asia-south1`) created
- [ ] Firebase project `icueadmin-dev` created (same settings), project ID noted here: `____`
- [ ] Blaze plan enabled on both projects
- [ ] Node dev: `POST /v1.0/firebaseToken` live (signs with `icueadmin-dev` service account)
- [ ] Node prod: `POST /v1.0/firebaseToken` live
- [ ] Node endpoints confirmed (students by class/section, staff, departments, roles, academic years)
- [ ] Dev/prod Android and iOS flavors with separate app IDs

## Phase 0 – Shared foundation

**Status:** not started · **Commit:** –

- [ ] `firebase/` scaffold: `firebase.json`, `.firebaserc` (aliases `dev`, `prod`; default `dev`), emulators
- [ ] Functions project (TypeScript, Node 22, `asia-south1`), shared wrapper: auth, access, validation, idempotency (`requests`), audit, counters, `uniqueKeys`, outbox
- [ ] `session.sync`, `userAccess`, `config/rolePermissions` seed, `onRolePermissionsChange`
- [ ] `outboxSend` and token dual-write (Node + `devices/{uid}/tokens`), logout cleanup
- [ ] Rules and Storage rules base, rules-test harness
- [ ] `icue_firebase`: auth, firestore, functions, storage; callable helper; paged query helper
- [ ] `features/auth`: Firebase custom-token exchange and sign-out
- [ ] `features/inventory` and `features/library` packages created, registered in root `workspace:` and `injection.dart`
- [ ] `AGENTS.md` updated: features use Firestore/Functions directly, not `api_client`; points here
- [ ] Parent app token exchange + token dual-write plan noted (applies when it joins the monorepo)

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

## Decisions and deviations

Format: `date · phase · what changed from the architecture doc · why`.

- (none yet)

## Open items

- (none yet)
