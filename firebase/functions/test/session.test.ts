import { beforeEach, describe, expect, it } from 'vitest';
import { recomputeSchool, syncSession } from '../src/session';
import { clearFirestore, db } from './setup';

const SID = '12';
const config = () => db().doc(`schools/${SID}/config/rolePermissions`);
const access = (uid: string) => db().doc(`schools/${SID}/userAccess/${uid}`).get().then((s) => s.data());

describe('session', () => {
  beforeEach(async () => {
    await clearFirestore();
    await config().set({ roles: { '4': ['inv.items.view'], '9': ['lib.settings'] } });
  });

  it('syncs userAccess from claims', async () => {
    const res = await syncSession(db(), 'u_1', { sid: 12, rol: [4, 9], cmp: [31, 32], pt: 'teacher', eid: 884 });
    expect(res).toEqual({ perms: ['inv.items.view', 'lib.settings'], cmp: [31, 32], all: false });
    expect(await access('u_1')).toMatchObject({ rol: [4, 9], pt: 'teacher', eid: 884, wards: [] });
  });

  it('gives parents no permissions, keeps wards', async () => {
    const res = await syncSession(db(), 'p_1', { sid: 12, rol: [4], pt: 'parent', wards: [5521] });
    expect(res.perms).toEqual([]);
    expect(await access('p_1')).toMatchObject({ wards: [5521], eid: null });
  });

  it('rejects tokens without a school', async () => {
    await expect(syncSession(db(), 'u_1', {})).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('recomputes permissions when the role map changes', async () => {
    await syncSession(db(), 'u_1', { sid: 12, rol: [4] });
    await syncSession(db(), 'u_2', { sid: 12, rol: [9] });
    await config().set({ roles: { '4': ['inv.items.view', 'inv.stock.view'], '9': ['lib.settings'] } });
    expect(await recomputeSchool(db(), SID)).toBe(1);
    expect((await access('u_1'))?.perms).toEqual(['inv.items.view', 'inv.stock.view']);
  });
});
