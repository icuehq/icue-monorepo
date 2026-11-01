/** Fixed permission keys (architecture §3.1). Role → permission mapping is data. */
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
  'library.catalogue.manage',
  'library.catalogue.view',
  'library.circulation.operate',
  'library.fines.waive',
  'library.reports.view',
  'library.members.view',
] as const;

export type Permission = (typeof PERMISSIONS)[number];

/** FRS §12 default matrix, keyed by role name. Seeded per school against Node role IDs. */
export const DEFAULT_ROLES: Record<string, Permission[]> = {
  admin: [...PERMISSIONS],
  principal: [
    'inventory.items.view',
    'inventory.stock.view',
    'inventory.issue.approve',
    'inventory.adjustment.approve',
    'inventory.purchaseRequest.approve',
    'inventory.assets.view',
    'inventory.reports.view',
    'library.catalogue.view',
    'library.reports.view',
    'library.members.view',
  ],
  inventoryManager: [
    'inventory.settings',
    'inventory.items.manage',
    'inventory.items.view',
    'inventory.stock.view',
    'inventory.stock.operate',
    'inventory.adjustment.approve',
    'inventory.issue.request',
    'inventory.purchaseRequest.request',
    'inventory.procure.operate',
    'inventory.vendors.manage',
    'inventory.assets.manage',
    'inventory.assets.view',
    'inventory.reports.view',
    'library.catalogue.view',
  ],
  storekeeper: [
    'inventory.items.view',
    'inventory.stock.view',
    'inventory.stock.operate',
    'inventory.issue.request',
    'inventory.purchaseRequest.request',
    'inventory.assets.manage',
    'inventory.assets.view',
    'library.catalogue.view',
  ],
  procurement: [
    'inventory.items.view',
    'inventory.stock.view',
    'inventory.purchaseRequest.request',
    'inventory.procure.operate',
    'inventory.vendors.manage',
    'inventory.assets.view',
    'library.catalogue.view',
  ],
  librarian: [
    'library.settings',
    'library.catalogue.manage',
    'library.catalogue.view',
    'library.circulation.operate',
    'library.fines.waive',
    'library.reports.view',
    'library.members.view',
  ],
  teacher: ['inventory.issue.request', 'inventory.purchaseRequest.request', 'inventory.assets.view', 'library.catalogue.view'],
};

export type RolePermissions = { roles?: Record<string, string[]> };

/** Union of the permissions of [roleIds]; unknown keys are dropped. */
export function resolvePerms(config: RolePermissions | undefined, roleIds: unknown[]): string[] {
  const known = new Set<string>(PERMISSIONS);
  const out = new Set<string>();
  for (const id of roleIds) {
    for (const permission of config?.roles?.[String(id)] ?? []) if (known.has(permission)) out.add(permission);
  }
  return [...out].sort();
}
