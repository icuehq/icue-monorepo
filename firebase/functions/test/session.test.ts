import { beforeEach, describe, expect, it } from 'vitest';
import { syncSession } from '../src/session';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const access = (uid: string) =>
  db()
    .doc(`${BRANCH}/userAccess/${uid}`)
    .get()
    .then((snapshot) => snapshot.data());

describe('session', () => {
  beforeEach(clearFirestore);

  it('syncs userAccess from claims, Inventory access from the tile action', async () => {
    const result = await syncSession(db(), '1', {
      orgId: 8,
      zoneId: 147,
      branchId: 427,
      roleIds: [4, 9],
      actionIds: [300, 312, 313],
      personType: 'teacher',
      personErpId: 884,
    });
    expect(result).toEqual({
      inventoryAccess: true,
      scope: 'branch',
    });
    expect(await access('1')).toMatchObject({
      roleIds: [4, 9],
      personType: 'teacher',
      personErpId: 884,
      wardStudentIds: [],
    });
  });

  it('gives no Inventory access without the tile action', async () => {
    expect(
      (await syncSession(db(), '1', { orgId: 8, zoneId: 147, branchId: 427, roleIds: [4] }))
        .inventoryAccess,
    ).toBe(false);
  });

  it('gives parents no Inventory access, keeps wardStudentIds', async () => {
    const result = await syncSession(db(), 'parent-1', {
      orgId: 8,
      zoneId: 147,
      branchId: 427,
      actionIds: [300],
      personType: 'parent',
      wardStudentIds: [5521],
    });
    expect(result.inventoryAccess).toBe(false);
    expect(await access('parent-1')).toMatchObject({ wardStudentIds: [5521], personErpId: null });
  });

  it('rejects tokens without a school', async () => {
    await expect(syncSession(db(), '1', {})).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
