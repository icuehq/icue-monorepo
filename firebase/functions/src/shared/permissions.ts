/** Fixed permission keys (architecture §3.1). Role → permission mapping is data. */
export const PERMISSIONS = [
  'inv.settings',
  'inv.items.manage',
  'inv.items.view',
  'inv.stock.view',
  'inv.stock.operate',
  'inv.issue.request',
  'inv.issue.approve',
  'inv.pr.request',
  'inv.pr.approve',
  'inv.procure.operate',
  'inv.vendors.manage',
  'inv.assets.manage',
  'inv.assets.view',
  'inv.reports.view',
  'lib.settings',
  'lib.catalogue.manage',
  'lib.catalogue.view',
  'lib.circulation.operate',
  'lib.fines.waive',
  'lib.reports.view',
  'lib.members.view',
] as const;

export type Permission = (typeof PERMISSIONS)[number];

/** FRS §12 default matrix, keyed by role name. Seeded per school against Node role IDs. */
export const DEFAULT_ROLES: Record<string, Permission[]> = {
  admin: [...PERMISSIONS],
  principal: [
    'inv.items.view',
    'inv.stock.view',
    'inv.issue.approve',
    'inv.pr.approve',
    'inv.assets.view',
    'inv.reports.view',
    'lib.catalogue.view',
    'lib.reports.view',
    'lib.members.view',
  ],
  inventoryManager: [
    'inv.settings',
    'inv.items.manage',
    'inv.items.view',
    'inv.stock.view',
    'inv.stock.operate',
    'inv.issue.request',
    'inv.pr.request',
    'inv.procure.operate',
    'inv.vendors.manage',
    'inv.assets.manage',
    'inv.assets.view',
    'inv.reports.view',
    'lib.catalogue.view',
  ],
  storekeeper: [
    'inv.items.view',
    'inv.stock.view',
    'inv.stock.operate',
    'inv.issue.request',
    'inv.pr.request',
    'inv.assets.manage',
    'inv.assets.view',
    'lib.catalogue.view',
  ],
  procurement: [
    'inv.items.view',
    'inv.stock.view',
    'inv.pr.request',
    'inv.procure.operate',
    'inv.vendors.manage',
    'inv.assets.view',
    'lib.catalogue.view',
  ],
  librarian: [
    'lib.settings',
    'lib.catalogue.manage',
    'lib.catalogue.view',
    'lib.circulation.operate',
    'lib.fines.waive',
    'lib.reports.view',
    'lib.members.view',
  ],
  teacher: ['inv.issue.request', 'inv.pr.request', 'inv.assets.view', 'lib.catalogue.view'],
};

export type RolePermissions = { roles?: Record<string, string[]> };

/** Union of the permissions of [roleIds]; unknown keys are dropped. */
export function resolvePerms(config: RolePermissions | undefined, roleIds: unknown[]): string[] {
  const known = new Set<string>(PERMISSIONS);
  const out = new Set<string>();
  for (const id of roleIds) {
    for (const p of config?.roles?.[String(id)] ?? []) if (known.has(p)) out.add(p);
  }
  return [...out].sort();
}
