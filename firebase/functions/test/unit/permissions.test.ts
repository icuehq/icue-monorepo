import { describe, expect, it } from 'vitest';
import { DEFAULT_ROLES, PERMISSIONS, resolvePerms } from '../../src/shared/permissions';

describe('resolvePerms', () => {
  const config = { roles: { '4': ['inv.items.view', 'bogus'], '9': ['inv.items.view', 'lib.settings'] } };

  it('unions roles, drops unknown keys, sorts', () => {
    expect(resolvePerms(config, [4, '9'])).toEqual(['inv.items.view', 'lib.settings']);
  });

  it('is empty without config or roles', () => {
    expect(resolvePerms(undefined, [4])).toEqual([]);
    expect(resolvePerms(config, [])).toEqual([]);
  });

  it('defaults only use known keys; admin has all', () => {
    for (const perms of Object.values(DEFAULT_ROLES)) for (const p of perms) expect(PERMISSIONS).toContain(p);
    expect(DEFAULT_ROLES.admin).toHaveLength(PERMISSIONS.length);
  });
});
