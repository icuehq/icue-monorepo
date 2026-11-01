import { beforeEach, describe, expect, it } from 'vitest';
import { recomputeSchool, syncSession } from '../src/session';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
const config = () => db().doc(`schools/${SCHOOL_ID}/config/rolePermissions`);
const access = (uid: string) => db().doc(`schools/${SCHOOL_ID}/userAccess/${uid}`).get().then((snapshot) => snapshot.data());

describe('session', () => {
  beforeEach(async () => {
    await clearFirestore();
    await config().set({ roles: { '4': ['inventory.items.view'], '9': ['library.settings'] } });
  });

  it('syncs userAccess from claims', async () => {
    const result = await syncSession(db(), '1', { schoolId: 12, roleIds: [4, 9], campusIds: [31, 32], personType: 'teacher', personErpId: 884 });
    expect(result).toEqual({ permissions: ['inventory.items.view', 'library.settings'], campusIds: [31, 32], hasAllCampuses: false });
    expect(await access('1')).toMatchObject({ roleIds: [4, 9], personType: 'teacher', personErpId: 884, wardStudentIds: [] });
  });

  it('gives parents no permissions, keeps wardStudentIds', async () => {
    const result = await syncSession(db(), 'parent-1', { schoolId: 12, roleIds: [4], personType: 'parent', wardStudentIds: [5521] });
    expect(result.permissions).toEqual([]);
    expect(await access('parent-1')).toMatchObject({ wardStudentIds: [5521], personErpId: null });
  });

  it('rejects tokens without a school', async () => {
    await expect(syncSession(db(), '1', {})).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('recomputes permissions when the role map changes', async () => {
    await syncSession(db(), '1', { schoolId: 12, roleIds: [4] });
    await syncSession(db(), '2', { schoolId: 12, roleIds: [9] });
    await config().set({ roles: { '4': ['inventory.items.view', 'inventory.stock.view'], '9': ['library.settings'] } });
    expect(await recomputeSchool(db(), SCHOOL_ID)).toBe(1);
    expect((await access('1'))?.permissions).toEqual(['inventory.items.view', 'inventory.stock.view']);
  });
});
