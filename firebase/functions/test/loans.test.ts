import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { loans } from '../src/library/loans';
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
const set = (path: string, data: Record<string, unknown>) => db().doc(`schools/${SID}/${path}`).update(data);

describe('library circulation', () => {
  let l1: string, cat: string, title: string;
  const issue = (copyId = 'ACC-000001', memberId = 'student_501') => run(loans.loanIssue, { memberId, copyId });
  const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({ perms: ['lib.settings', 'lib.catalogue.manage', 'lib.circulation.operate'], cmp: [31, 32], all: false });
    await db().doc(`schools/${SID}/userAccess/u_2`).set({ perms: ['lib.circulation.operate'], cmp: [99], all: false });
    cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
    title = (await run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['Kalam'], categoryId: cat })).id;
    l1 = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, { type: 'donation', catalogueId: title, libraryId: l1, qty: 3 });
    await run(members.policyUpsert, { libraryId: l1, memberCategory: 'primary', name: 'Primary', maxBooks: 2, loanDays: 7, maxRenewals: 1, fineType: 'none', canReserve: true });
    await run(members.memberUpsert, { memberType: 'student', erpId: 501, memberCategory: 'primary', libraryIds: [l1], start: '2020-01-01' });
  });

  it('issue sets due date from the policy, marks the copy issued and counts the loan', async () => {
    const r = await issue();
    expect(r.dueOn).toBe(day(7));
    expect(await get(`libLoans/${r.id}`)).toMatchObject({ status: 'active', personErpId: 501, copyId: 'ACC-000001', campusId: 31, policySnapshot: { loanDays: 7, maxRenewals: 1 } });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'issued', activeLoanId: r.id });
    expect((await get('libMembers/student_501'))!.activeLoans).toBe(1);
  });

  it('issue rules: copy taken, limit, inactive/blocked/expired member, no policy, restricted category, campus', async () => {
    await issue();
    await expect(issue()).rejects.toMatchObject({ code: 'failed-precondition' });
    await issue('ACC-000002');
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' }); // maxBooks 2
    await set('libMembers/student_501', { activeLoans: 0, blocked: true });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libMembers/student_501', { blocked: false, end: '2021-01-01' });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libMembers/student_501', { end: null, status: 'inactive' });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libMembers/student_501', { status: 'active', memberCategory: 'none' });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libMembers/student_501', { memberCategory: 'primary' });
    await set(`libPolicies/${l1}_primary`, { restrictedCategoryIds: [cat] });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set(`libPolicies/${l1}_primary`, { restrictedCategoryIds: [] });
    await expect(run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000003' }, 'u_2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(issue('ACC-000003')).resolves.toBeTruthy();
  });

  it('policy edits do not move existing due dates; renewal uses the frozen snapshot and limit', async () => {
    const r = await issue();
    await set(`libPolicies/${l1}_primary`, { loanDays: 30, maxRenewals: 5 });
    const a = await run(loans.loanRenew, { id: r.id });
    expect(a.dueOn).toBe(day(14));
    expect((await get(`libLoans/${r.id}`))!.renewals).toHaveLength(1);
    await expect(run(loans.loanRenew, { id: r.id })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('overdue renewal follows the policy snapshot', async () => {
    const r = await issue();
    await set(`libLoans/${r.id}`, { dueOn: day(-3) });
    await expect(run(loans.loanRenew, { id: r.id })).rejects.toMatchObject({ code: 'failed-precondition' });
    await set(`libLoans/${r.id}`, { 'policySnapshot.overdueRenewal': true });
    expect((await run(loans.loanRenew, { id: r.id })).dueOn).toBe(day(7));
  });

  it('return: good makes the copy available, records overdue days, frees the limit; second return fails', async () => {
    const r = await issue();
    await set(`libLoans/${r.id}`, { dueOn: day(-2) });
    const ret = await run(loans.loanReturn, { id: r.id, condition: 'good' });
    expect(ret.overdueDays).toBe(2);
    expect(await get(`libLoans/${r.id}`)).toMatchObject({ status: 'returned', condition: 'good', overdueDays: 2 });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'available', activeLoanId: null });
    expect((await get('libMembers/student_501'))!.activeLoans).toBe(0);
    await expect(run(loans.loanReturn, { id: r.id, condition: 'good' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(loans.loanRenew, { id: r.id })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('return: damaged copy is not made available', async () => {
    const r = await issue();
    await run(loans.loanReturn, { id: r.id, condition: 'damaged' });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'damaged', activeLoanId: null });
    await expect(issue()).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
