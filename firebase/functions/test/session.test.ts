import { PERMISSIONS } from '../src/shared/permissions';
import { beforeEach, describe, expect, it } from 'vitest';
import { syncSession } from '../src/session';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
const access = (uid: string) =>
  db()
    .doc(`schools/${SCHOOL_ID}/userAccess/${uid}`)
    .get()
    .then((snapshot) => snapshot.data());

const libraryPermissions = PERMISSIONS.filter((permission) =>
  permission.startsWith('library.'),
).sort();

describe('session', () => {
  beforeEach(clearFirestore);

  it('syncs userAccess from claims, permissions from actionIds', async () => {
    const result = await syncSession(db(), '1', {
      schoolId: 12,
      roleIds: [4, 9],
      actionIds: [300, 312, 313],
      campusIds: [31, 32],
      personType: 'teacher',
      personErpId: 884,
    });
    expect(result).toEqual({
      permissions: [...libraryPermissions, 'inventory.items.view', 'inventory.stock.view'].sort(),
      campusIds: [31, 32],
      hasAllCampuses: false,
    });
    expect(await access('1')).toMatchObject({
      roleIds: [4, 9],
      personType: 'teacher',
      personErpId: 884,
      wardStudentIds: [],
    });
  });

  it('gives only the library permissions without actionIds', async () => {
    expect((await syncSession(db(), '1', { schoolId: 12, roleIds: [4] })).permissions).toEqual(
      libraryPermissions,
    );
  });

  it('gives parents no permissions, keeps wardStudentIds', async () => {
    const result = await syncSession(db(), 'parent-1', {
      schoolId: 12,
      actionIds: [312],
      personType: 'parent',
      wardStudentIds: [5521],
    });
    expect(result.permissions).toEqual([]);
    expect(await access('parent-1')).toMatchObject({ wardStudentIds: [5521], personErpId: null });
  });

  it('rejects tokens without a school', async () => {
    await expect(syncSession(db(), '1', {})).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
