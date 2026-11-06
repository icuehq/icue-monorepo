# Inventory & Library: actions Node must add

For `/v1.0/getActionsByRole` (same shape as Fleet, Drop Boarding, etc.). Node is the
source of truth: the app shows tiles from this response, and `/v1.0/firebaseToken`
sends the same action `Id`s to Firebase as a claim (`actionIds`), where each Id maps
to one permission. Rules and Cloud Functions enforce that permission server-side.

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

`Permission` is the Firebase permission the action grants; it is for our mapping,
not a field Node needs to return. `RouteState` values are suggestions, but fix them
once chosen.

### Top-level

| Name | DisplayName | RouteState | Permission |
| --- | --- | --- | --- |
| Inventory - Admin App | Inventory | `layout.inventory` | none (shows the tile) |
| Library - Admin App | Library | `layout.library` | none (shows the tile) |

### Inventory sub-actions (children of Inventory)

| DisplayName | RouteState | Permission |
| --- | --- | --- |
| Inventory Settings | `layout.inventory.settings` | `inventory.settings` |
| Manage Items | `layout.inventory.items.manage` | `inventory.items.manage` |
| View Items | `layout.inventory.items.view` | `inventory.items.view` |
| View Stock | `layout.inventory.stock.view` | `inventory.stock.view` |
| Operate Stock | `layout.inventory.stock.operate` | `inventory.stock.operate` |
| Request Issue | `layout.inventory.issue.request` | `inventory.issue.request` |
| Approve Issue | `layout.inventory.issue.approve` | `inventory.issue.approve` |
| Approve Stock Adjustment | `layout.inventory.adjustment.approve` | `inventory.adjustment.approve` |
| Request Purchase | `layout.inventory.purchaserequest.request` | `inventory.purchaseRequest.request` |
| Approve Purchase | `layout.inventory.purchaserequest.approve` | `inventory.purchaseRequest.approve` |
| Procurement | `layout.inventory.procure.operate` | `inventory.procure.operate` |
| Manage Vendors | `layout.inventory.vendors.manage` | `inventory.vendors.manage` |
| Manage Assets | `layout.inventory.assets.manage` | `inventory.assets.manage` |
| View Assets | `layout.inventory.assets.view` | `inventory.assets.view` |
| Inventory Reports | `layout.inventory.reports.view` | `inventory.reports.view` |

### Library sub-actions (children of Library)

| DisplayName | RouteState | Permission |
| --- | --- | --- |
| Library Settings | `layout.library.settings` | `library.settings` |
| Catalogue (view, add, edit) | `layout.library.catalogue` | `library.catalogue` |
| Circulation (issue/return) | `layout.library.circulation.operate` | `library.circulation.operate` |
| Waive Fines | `layout.library.fines.waive` | `library.fines.waive` |
| Library Reports | `layout.library.reports.view` | `library.reports.view` |
| View Members | `layout.library.members.view` | `library.members.view` |

## Suggested default grants (FRS §12)

| Role | Inventory | Library |
| --- | --- | --- |
| Admin | all | all |
| Principal | View Items, View Stock, Approve Issue, Approve Stock Adjustment, Approve Purchase, View Assets, Inventory Reports | none |
| Inventory Manager | all except the two Approve (Issue, Purchase) | none |
| Storekeeper | View Items, View Stock, Operate Stock, Request Issue, Request Purchase, Manage Assets, View Assets | none |
| Procurement | View Items, View Stock, Request Purchase, Procurement, Manage Vendors, View Assets | none |
| Librarian | none | all |
| Teacher | Request Issue, Request Purchase, View Assets | none |

Granting any child without its parent shows nothing; the parent must be granted
for the tile to appear.
