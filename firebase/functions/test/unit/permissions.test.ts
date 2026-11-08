import { describe, expect, it } from 'vitest';
import {
  ACTION_PERMISSIONS,
  PERMISSIONS,
  permissionsFromActions,
} from '../../src/shared/permissions';

const library = PERMISSIONS.filter((permission) => permission.startsWith('library.'));

describe('permissionsFromActions', () => {
  it('maps action Ids, drops unknown and parent Ids, sorts and dedupes', () => {
    expect(permissionsFromActions([313, '312', 312, 300, 330, 999])).toEqual(
      [...library, 'inventory.items.view', 'inventory.stock.view'].sort(),
    );
  });

  it('always grants every library permission, even without actionIds', () => {
    expect(permissionsFromActions(undefined)).toEqual([...library].sort());
    expect(permissionsFromActions([])).toEqual([...library].sort());
  });

  it('covers every inventory permission exactly once', () => {
    expect(Object.values(ACTION_PERMISSIONS).sort()).toEqual(
      PERMISSIONS.filter((permission) => permission.startsWith('inventory.')).sort(),
    );
  });
});
