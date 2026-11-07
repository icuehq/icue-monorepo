import { describe, expect, it } from 'vitest';
import {
  ACTION_PERMISSIONS,
  PERMISSIONS,
  permissionsFromActions,
} from '../../src/shared/permissions';

describe('permissionsFromActions', () => {
  it('maps action Ids, drops unknown and parent Ids, sorts and dedupes', () => {
    expect(permissionsFromActions([313, '312', 312, 300, 330, 999])).toEqual([
      'inventory.items.view',
      'inventory.stock.view',
    ]);
  });

  it('is empty without actionIds', () => {
    expect(permissionsFromActions(undefined)).toEqual([]);
    expect(permissionsFromActions([])).toEqual([]);
  });

  it('covers every inventory permission exactly once', () => {
    expect(Object.values(ACTION_PERMISSIONS).sort()).toEqual(
      PERMISSIONS.filter((permission) => permission.startsWith('inventory.')).sort(),
    );
  });
});
