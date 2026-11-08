import { beforeEach, describe, expect, it } from 'vitest';
import { members } from '../src/library/members';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { seedLibrary, seedLibraryCategory } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(
    definition,
    { uid, token: { schoolId: 12, personType: 'staff' } },
    { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data },
  );
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();

describe('library members and policies', () => {
  let mainLibrary: string, secondLibrary: string, category: string;
  const policy = (extra: Record<string, unknown> = {}) =>
    run(members.policyUpsert, {
      libraryId: mainLibrary,
      memberType: 'student',
      name: 'Students',
      maxBooks: 1,
      loanDays: 7,
      maxRenewals: 1,
      fineType: 'per_day',
      fineAmount: 2,
      ...extra,
    });
  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: ['library.settings', 'library.catalogue', 'library.circulation.operate'],
        campusIds: [31, 32],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/2`)
      .set({ permissions: ['library.members.view'], campusIds: [31], hasAllCampuses: false });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/3`)
      .set({
        permissions: ['library.settings', 'library.circulation.operate'],
        campusIds: [31],
        hasAllCampuses: false,
      });
    category = (await seedLibraryCategory({ name: 'Reference' })).id;
    mainLibrary = (await seedLibrary({ name: 'Main', campusId: 31 })).id;
    secondLibrary = (await seedLibrary({ name: 'Junior', campusId: 32 })).id;
  });

  it('policy: created with categories, edited by id, library and person type fixed', async () => {
    const first = await policy({ categoryIds: [category, category] });
    expect(await get(`libraryBorrowingPolicies/${first.id}`)).toMatchObject({
      campusId: 31,
      maxBooks: 1,
      loanDays: 7,
      status: 'active',
      categoryIds: [category],
    });
    await policy({ id: first.id, maxBooks: 3, categoryIds: [category] });
    expect(await get(`libraryBorrowingPolicies/${first.id}`)).toMatchObject({
      maxBooks: 3,
      status: 'active',
    });
    await expect(
      policy({ id: first.id, memberType: 'teacher', categoryIds: [category] }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(policy({ id: 'nope' })).rejects.toMatchObject({ code: 'not-found' });
    await policy({ libraryId: secondLibrary });
    await policy({ memberType: 'teacher' });
    await policy({ name: 'Rest' }); // catch-all next to the category policy
    expect(
      (await db().collection(`schools/${SCHOOL_ID}/libraryBorrowingPolicies`).get()).size,
    ).toBe(4);
    await run(members.policySetStatus, { id: first.id, status: 'inactive' });
    expect((await get(`libraryBorrowingPolicies/${first.id}`))!.status).toBe('inactive');
  });

  it('policy: a category, or the catch-all, belongs to one active policy per library and person type', async () => {
    const reference = await policy({ categoryIds: [category] });
    await expect(policy({ name: 'Again', categoryIds: [category] })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    const rest = await policy({ name: 'Rest' });
    await expect(policy({ name: 'Rest 2' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    await policy({ memberType: 'teacher', categoryIds: [category] }); // other person type
    await run(members.policySetStatus, { id: rest.id, status: 'inactive' });
    await policy({ name: 'Rest 2' });
    await expect(
      run(members.policySetStatus, { id: rest.id, status: 'active' }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(members.policySetStatus, { id: reference.id, status: 'inactive' });
    await policy({ name: 'Reference again', categoryIds: [category] });
  });

  it('policy: one default for everyone per library', async () => {
    await policy({ memberType: 'all', name: 'Default' });
    await expect(policy({ memberType: 'all', name: 'Again' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('policy rules: fine needs an amount, no fine clears amounts, only student or teacher, permission, campus, unknown category', async () => {
    await expect(policy({ fineAmount: 0 })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(policy({ memberType: 'parent' })).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    const first = await policy({ fineType: 'none', fineAmount: 5, maxFine: 9 });
    expect(await get(`libraryBorrowingPolicies/${first.id}`)).toMatchObject({
      fineAmount: 0,
      maxFine: null,
    });
    await expect(policy({ categoryIds: ['nope'] })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    const other = {
      memberType: 'student',
      name: 'x',
      maxBooks: 1,
      loanDays: 1,
      maxRenewals: 0,
      fineType: 'none',
    };
    await expect(
      run(members.policyUpsert, { libraryId: mainLibrary, ...other }, '2'),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(policy({ libraryId: secondLibrary })).resolves.toBeTruthy();
    await expect(
      run(members.policyUpsert, { libraryId: secondLibrary, ...other, name: 'y' }, '3'),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await db().doc(`schools/${SCHOOL_ID}/libraries/${mainLibrary}`).update({ status: 'inactive' });
    await policy({ id: first.id, maxBooks: 2 }); // existing policy of an inactive library stays editable
    await expect(policy({ memberType: 'teacher' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });
});
