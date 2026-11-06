/** Fixed permission keys (architecture §3.1). Granted per user through Node actions (see ACTION_PERMISSIONS). */
export const PERMISSIONS = [
  'inventory.settings',
  'inventory.items.manage',
  'inventory.items.view',
  'inventory.stock.view',
  'inventory.stock.operate',
  'inventory.issue.request',
  'inventory.issue.approve',
  'inventory.adjustment.approve',
  'inventory.purchaseRequest.request',
  'inventory.purchaseRequest.approve',
  'inventory.procure.operate',
  'inventory.vendors.manage',
  'inventory.assets.manage',
  'inventory.assets.view',
  'inventory.reports.view',
  'library.settings',
  'library.catalogue',
  'library.circulation.operate',
  'library.fines.waive',
  'library.reports.view',
  'library.members.view',
] as const;

export type Permission = (typeof PERMISSIONS)[number];

/**
 * Node action Id (`/v1.0/getActionsByRole`, sent as the `actionIds` token claim) → permission.
 * Ids must match docs/inventory-library-node-actions.md. Parent actions (300, 301) grant nothing.
 */
export const ACTION_PERMISSIONS: Record<number, Permission> = {
  310: 'inventory.settings',
  311: 'inventory.items.manage',
  312: 'inventory.items.view',
  313: 'inventory.stock.view',
  314: 'inventory.stock.operate',
  315: 'inventory.issue.request',
  316: 'inventory.issue.approve',
  317: 'inventory.adjustment.approve',
  318: 'inventory.purchaseRequest.request',
  319: 'inventory.purchaseRequest.approve',
  320: 'inventory.procure.operate',
  321: 'inventory.vendors.manage',
  322: 'inventory.assets.manage',
  323: 'inventory.assets.view',
  324: 'inventory.reports.view',
  330: 'library.settings',
  331: 'library.catalogue',
  333: 'library.circulation.operate',
  334: 'library.fines.waive',
  335: 'library.reports.view',
  336: 'library.members.view',
};

/** Permissions of the granted [actionIds]; unknown Ids are ignored. Sorted, unique. */
export function permissionsFromActions(actionIds: unknown): string[] {
  const ids = Array.isArray(actionIds) ? actionIds : [];
  return [...new Set(ids.map((id) => ACTION_PERMISSIONS[Number(id)]).filter(Boolean))].sort();
}
