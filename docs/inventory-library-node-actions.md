# Inventory & Library: actions Node must add

For `/v1.0/getActionsByRole` (same shape as Fleet, Drop Boarding, etc.). Node is the
source of truth: the app shows tiles from this response, and `/v1.0/firebaseToken`
sends the same action `Id`s to Firebase as a claim (`actionIds`). Rules and Cloud
Functions only check that the caller is non-parent staff of the branch.

## What Node must do

1. Create the actions below so they can be granted per role in the admin panel.
2. Return them in `getActionsByRole` for a role that has them (top-level actions
   with `SubActions: true` and the granted children in `SubActionItems`).
3. Add `actionIds` (flat array of every granted action `Id`, parents and children)
   to the `/v1.0/firebaseToken` custom claims. Numbers only: custom claims are
   limited to ~1000 bytes.
4. Use the **same `Id`s in dev, staging and prod**. Firebase maps by `Id`.
   Reserve a fixed range (suggested 300-349) and send us the final Ids.

## Actions

`RouteState` values are suggestions, but fix them once chosen.

### Top-level

| Name | DisplayName | RouteState |
| --- | --- | --- |
| Inventory - Admin App | Inventory | `layout.inventory` |
| Library - Admin App | Library | `layout.Library` |

Node has no sub-actions for either module. Holding the tile is the only gate: any
staff user with it may use every screen and action of that module. Firebase treats
action Id **300** as the Inventory tile (`INVENTORY_ACTION_ID` in `session.ts`).

## Suggested default grants

Grant the Inventory tile to Admin, Principal, Inventory Manager, Storekeeper,
Procurement and any Teacher who raises requests; grant the Library tile to Admin and
Librarian.
