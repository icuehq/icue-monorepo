import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, { uid, token: { schoolId: 12, personType: 'staff' } }, { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();

describe('library members and policies', () => {
  let mainLibrary: string, secondLibrary: string, category: string;
  const policy = (extra: Record<string, unknown> = {}) =>
    run(members.policyUpsert, { libraryId: mainLibrary, memberCategory: 'primary', name: 'Primary', maxBooks: 1, loanDays: 7, maxRenewals: 1, fineType: 'per_day', fineAmount: 2, canReserve: true, ...extra });
  const enrol = (extra: Record<string, unknown> = {}) =>
    run(members.memberUpsert, { memberType: 'student', personErpId: 501, classId: 4, memberCategory: 'primary', libraryIds: [mainLibrary], start: '2026-06-01', ...extra });

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SCHOOL_ID}/userAccess/1`).set({ permissions: ['library.settings', 'library.catalogue.manage', 'library.circulation.operate'], campusIds: [31, 32], hasAllCampuses: false });
    await db().doc(`schools/${SCHOOL_ID}/userAccess/2`).set({ permissions: ['library.members.view'], campusIds: [31], hasAllCampuses: false });
    await db().doc(`schools/${SCHOOL_ID}/userAccess/3`).set({ permissions: ['library.settings', 'library.circulation.operate'], campusIds: [31], hasAllCampuses: false });
    category = (await run(masters.categoryUpsert, { code: 'REF', name: 'Reference' })).id;
    mainLibrary = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    secondLibrary = (await run(masters.libraryUpsert, { code: 'L2', name: 'Junior', campusId: 32 })).id;
  });

  it('policy: one per library and category, saving again edits it', async () => {
    const first = await policy({ restrictedCategoryIds: [category, category] });
    expect(first.id).toBe(`${mainLibrary}_primary`);
    expect(await get(`libraryBorrowingPolicies/${first.id}`)).toMatchObject({ campusId: 31, maxBooks: 1, loanDays: 7, status: 'active', restrictedCategoryIds: [category] });
    await policy({ maxBooks: 3 });
    expect(await get(`libraryBorrowingPolicies/${first.id}`)).toMatchObject({ maxBooks: 3, status: 'active' });
    await policy({ libraryId: secondLibrary });
    await policy({ memberCategory: 'teacher' });
    expect((await db().collection(`schools/${SCHOOL_ID}/libraryBorrowingPolicies`).get()).size).toBe(3);
    await run(members.policySetStatus, { id: first.id, status: 'inactive' });
    expect((await get(`libraryBorrowingPolicies/${first.id}`))!.status).toBe('inactive');
  });

  it('policy rules: fine needs an amount, no fine clears amounts, permission, campus, unknown category', async () => {
    await expect(policy({ fineAmount: 0 })).rejects.toMatchObject({ code: 'invalid-argument' });
    await policy({ fineType: 'none', fineAmount: 5, maxFine: 9 });
    expect(await get(`libraryBorrowingPolicies/${mainLibrary}_primary`)).toMatchObject({ fineAmount: 0, maxFine: null });
    await expect(policy({ restrictedCategoryIds: ['nope'] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(policy({}, )).resolves.toBeTruthy();
    await expect(run(members.policyUpsert, { libraryId: mainLibrary, memberCategory: 'x', name: 'x', maxBooks: 1, loanDays: 1, maxRenewals: 0, fineType: 'none', canReserve: false }, '2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(policy({ libraryId: secondLibrary }, )).resolves.toBeTruthy();
    await expect(run(members.policyUpsert, { libraryId: secondLibrary, memberCategory: 'x', name: 'x', maxBooks: 1, loanDays: 1, maxRenewals: 0, fineType: 'none', canReserve: false }, '3')).rejects.toMatchObject({ code: 'permission-denied' });
    await run(masters.librarySetStatus, { id: mainLibrary, status: 'inactive' });
    await policy({ maxBooks: 2 }); // existing policy of an inactive library stays editable
    await expect(policy({ memberCategory: 'new' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('member: deterministic ID, no duplicates, loans preserved on edit', async () => {
    const member = await enrol();
    expect(member.id).toBe('student_501');
    expect(await get('libraryMembers/student_501')).toMatchObject({ personErpId: 501, classId: 4, campusIds: [31], status: 'active', activeLoans: 0, blocked: false });
    await db().doc(`schools/${SCHOOL_ID}/libraryMembers/student_501`).update({ activeLoans: 2 });
    await enrol({ libraryIds: [mainLibrary, secondLibrary], end: '2027-03-31' });
    expect(await get('libraryMembers/student_501')).toMatchObject({ activeLoans: 2, campusIds: [31, 32], end: '2027-03-31' });
    expect((await db().collection(`schools/${SCHOOL_ID}/libraryMembers`).get()).size).toBe(1);
    await run(members.memberUpsert, { memberType: 'teacher', personErpId: 501, memberCategory: 'teacher', libraryIds: [mainLibrary], start: '2026-06-01', classId: 9 });
    expect(await get('libraryMembers/teacher_501')).toMatchObject({ classId: null });
  });

  it('member rules: dates, permission, campus, inactive library, status toggle', async () => {
    await expect(enrol({ end: '2026-05-01' })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(run(members.memberUpsert, { memberType: 'student', personErpId: 1, memberCategory: 'p', libraryIds: [mainLibrary], start: '2026-06-01' }, '2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(run(members.memberUpsert, { memberType: 'student', personErpId: 1, memberCategory: 'p', libraryIds: [secondLibrary], start: '2026-06-01' }, '3')).rejects.toMatchObject({ code: 'permission-denied' });
    await run(masters.librarySetStatus, { id: secondLibrary, status: 'inactive' });
    await expect(enrol({ libraryIds: [secondLibrary] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await enrol();
    await run(members.memberSetStatus, { id: 'student_501', status: 'inactive' });
    expect((await get('libraryMembers/student_501'))!.status).toBe('inactive');
    await expect(run(members.memberSetStatus, { id: 'student_999', status: 'active' })).rejects.toMatchObject({ code: 'not-found' });
  });
});
