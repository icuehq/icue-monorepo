import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();

describe('library members and policies', () => {
  let l1: string, l2: string, cat: string;
  const policy = (extra: Record<string, unknown> = {}) =>
    run(members.policyUpsert, { libraryId: l1, memberCategory: 'primary', name: 'Primary', maxBooks: 1, loanDays: 7, maxRenewals: 1, fineType: 'per_day', fineAmount: 2, canReserve: true, ...extra });
  const enrol = (extra: Record<string, unknown> = {}) =>
    run(members.memberUpsert, { memberType: 'student', erpId: 501, classId: 4, memberCategory: 'primary', libraryIds: [l1], start: '2026-06-01', ...extra });

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({ perms: ['lib.settings', 'lib.catalogue.manage', 'lib.circulation.operate'], cmp: [31, 32], all: false });
    await db().doc(`schools/${SID}/userAccess/u_2`).set({ perms: ['lib.members.view'], cmp: [31], all: false });
    await db().doc(`schools/${SID}/userAccess/u_3`).set({ perms: ['lib.settings', 'lib.circulation.operate'], cmp: [31], all: false });
    cat = (await run(masters.categoryUpsert, { code: 'REF', name: 'Reference' })).id;
    l1 = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    l2 = (await run(masters.libraryUpsert, { code: 'L2', name: 'Junior', campusId: 32 })).id;
  });

  it('policy: one per library and category, saving again edits it', async () => {
    const a = await policy({ restrictedCategoryIds: [cat, cat] });
    expect(a.id).toBe(`${l1}_primary`);
    expect(await get(`libPolicies/${a.id}`)).toMatchObject({ campusId: 31, maxBooks: 1, loanDays: 7, status: 'active', restrictedCategoryIds: [cat] });
    await policy({ maxBooks: 3 });
    expect(await get(`libPolicies/${a.id}`)).toMatchObject({ maxBooks: 3, status: 'active' });
    await policy({ libraryId: l2 });
    await policy({ memberCategory: 'teacher' });
    expect((await db().collection(`schools/${SID}/libPolicies`).get()).size).toBe(3);
    await run(members.policySetStatus, { id: a.id, status: 'inactive' });
    expect((await get(`libPolicies/${a.id}`))!.status).toBe('inactive');
  });

  it('policy rules: fine needs an amount, no fine clears amounts, permission, campus, unknown category', async () => {
    await expect(policy({ fineAmount: 0 })).rejects.toMatchObject({ code: 'invalid-argument' });
    await policy({ fineType: 'none', fineAmount: 5, maxFine: 9 });
    expect(await get(`libPolicies/${l1}_primary`)).toMatchObject({ fineAmount: 0, maxFine: null });
    await expect(policy({ restrictedCategoryIds: ['nope'] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(policy({}, )).resolves.toBeTruthy();
    await expect(run(members.policyUpsert, { libraryId: l1, memberCategory: 'x', name: 'x', maxBooks: 1, loanDays: 1, maxRenewals: 0, fineType: 'none', canReserve: false }, 'u_2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(policy({ libraryId: l2 }, )).resolves.toBeTruthy();
    await expect(run(members.policyUpsert, { libraryId: l2, memberCategory: 'x', name: 'x', maxBooks: 1, loanDays: 1, maxRenewals: 0, fineType: 'none', canReserve: false }, 'u_3')).rejects.toMatchObject({ code: 'permission-denied' });
    await run(masters.librarySetStatus, { id: l1, status: 'inactive' });
    await policy({ maxBooks: 2 }); // existing policy of an inactive library stays editable
    await expect(policy({ memberCategory: 'new' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('member: deterministic ID, no duplicates, loans preserved on edit', async () => {
    const m = await enrol();
    expect(m.id).toBe('student_501');
    expect(await get('libMembers/student_501')).toMatchObject({ erpId: 501, classId: 4, campusIds: [31], status: 'active', activeLoans: 0, blocked: false });
    await db().doc(`schools/${SID}/libMembers/student_501`).update({ activeLoans: 2 });
    await enrol({ libraryIds: [l1, l2], end: '2027-03-31' });
    expect(await get('libMembers/student_501')).toMatchObject({ activeLoans: 2, campusIds: [31, 32], end: '2027-03-31' });
    expect((await db().collection(`schools/${SID}/libMembers`).get()).size).toBe(1);
    await run(members.memberUpsert, { memberType: 'teacher', erpId: 501, memberCategory: 'teacher', libraryIds: [l1], start: '2026-06-01', classId: 9 });
    expect(await get('libMembers/teacher_501')).toMatchObject({ classId: null });
  });

  it('member rules: dates, permission, campus, inactive library, status toggle', async () => {
    await expect(enrol({ end: '2026-05-01' })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(run(members.memberUpsert, { memberType: 'student', erpId: 1, memberCategory: 'p', libraryIds: [l1], start: '2026-06-01' }, 'u_2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(run(members.memberUpsert, { memberType: 'student', erpId: 1, memberCategory: 'p', libraryIds: [l2], start: '2026-06-01' }, 'u_3')).rejects.toMatchObject({ code: 'permission-denied' });
    await run(masters.librarySetStatus, { id: l2, status: 'inactive' });
    await expect(enrol({ libraryIds: [l2] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await enrol();
    await run(members.memberSetStatus, { id: 'student_501', status: 'inactive' });
    expect((await get('libMembers/student_501'))!.status).toBe('inactive');
    await expect(run(members.memberSetStatus, { id: 'student_999', status: 'active' })).rejects.toMatchObject({ code: 'not-found' });
  });
});
