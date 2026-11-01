import { describe, expect, it } from 'vitest';
import { DEFAULT_ROLES, PERMISSIONS, resolvePerms } from '../../src/shared/permissions';

describe('resolvePerms', () => {
  const config = { roles: { '4': ['inventory.items.view', 'bogus'], '9': ['inventory.items.view', 'library.settings'] } };

  it('unions roles, drops unknown keys, sorts', () => {
    expect(resolvePerms(config, [4, '9'])).toEqual(['inventory.items.view', 'library.settings']);
  });

  it('is empty without config or roles', () => {
    expect(resolvePerms(undefined, [4])).toEqual([]);
    expect(resolvePerms(config, [])).toEqual([]);
  });

  it('defaults only use known keys; admin has all', () => {
    for (const permissions of Object.values(DEFAULT_ROLES)) for (const permission of permissions) expect(PERMISSIONS).toContain(permission);
    expect(DEFAULT_ROLES.admin).toHaveLength(PERMISSIONS.length);
  });
});
