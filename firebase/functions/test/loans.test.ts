import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { loans } from '../src/library/loans';
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
const set = (path: string, data: Record<string, unknown>) => db().doc(`schools/${SCHOOL_ID}/${path}`).update(data);

describe('library circulation', () => {
  let mainLibrary: string, category: string, title: string;
  const issue = (copyId = 'ACC-000001', memberId = 'student_501') => run(loans.loanIssue, { memberId, copyId });
  const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SCHOOL_ID}/userAccess/1`).set({ permissions: ['library.settings', 'library.catalogue.manage', 'library.circulation.operate'], campusIds: [31, 32], hasAllCampuses: false });
    await db().doc(`schools/${SCHOOL_ID}/userAccess/2`).set({ permissions: ['library.circulation.operate'], campusIds: [99], hasAllCampuses: false });
    category = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
    title = (await run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['Kalam'], categoryId: category })).id;
    mainLibrary = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, { type: 'donation', catalogueId: title, libraryId: mainLibrary, quantity: 3 });
    await run(members.policyUpsert, { libraryId: mainLibrary, memberCategory: 'primary', name: 'Primary', maxBooks: 2, loanDays: 7, maxRenewals: 1, fineType: 'none', canReserve: true });
    await run(members.memberUpsert, { memberType: 'student', personErpId: 501, memberCategory: 'primary', libraryIds: [mainLibrary], start: '2020-01-01' });
  });

  it('issue sets due date from the policy, marks the copy issued and counts the loan', async () => {
    const result = await issue();
    expect(result.dueDate).toBe(day(7));
    expect(await get(`libraryLoans/${result.id}`)).toMatchObject({ status: 'active', personErpId: 501, copyId: 'ACC-000001', campusId: 31, policySnapshot: { loanDays: 7, maxRenewals: 1 } });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({ status: 'issued', activeLoanId: result.id });
    expect((await get('libraryMembers/student_501'))!.activeLoans).toBe(1);
  });

  it('issue rules: copy taken, limit, inactive/blocked/expired member, no policy, restricted category, campus', async () => {
    await issue();
    await expect(issue()).rejects.toMatchObject({ code: 'failed-precondition' });
    await issue('ACC-000002');
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' }); // maxBooks 2
    await set('libraryMembers/student_501', { activeLoans: 0, blocked: true });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libraryMembers/student_501', { blocked: false, end: '2021-01-01' });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libraryMembers/student_501', { end: null, status: 'inactive' });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libraryMembers/student_501', { status: 'active', memberCategory: 'none' });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libraryMembers/student_501', { memberCategory: 'primary' });
    await set(`libraryBorrowingPolicies/${mainLibrary}_primary`, { restrictedCategoryIds: [category] });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set(`libraryBorrowingPolicies/${mainLibrary}_primary`, { restrictedCategoryIds: [] });
    await expect(run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000003' }, '2')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(issue('ACC-000003')).resolves.toBeTruthy();
  });

  it('policy edits do not move existing due dates; renewal uses the frozen snapshot and limit', async () => {
    const result = await issue();
    await set(`libraryBorrowingPolicies/${mainLibrary}_primary`, { loanDays: 30, maxRenewals: 5 });
    const first = await run(loans.loanRenew, { id: result.id });
    expect(first.dueDate).toBe(day(14));
    expect((await get(`libraryLoans/${result.id}`))!.renewals).toHaveLength(1);
    await expect(run(loans.loanRenew, { id: result.id })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('overdue renewal follows the policy snapshot', async () => {
    const result = await issue();
    await set(`libraryLoans/${result.id}`, { dueDate: day(-3) });
    await expect(run(loans.loanRenew, { id: result.id })).rejects.toMatchObject({ code: 'failed-precondition' });
    await set(`libraryLoans/${result.id}`, { 'policySnapshot.overdueRenewal': true });
    expect((await run(loans.loanRenew, { id: result.id })).dueDate).toBe(day(7));
  });

  it('return: good makes the copy available, records overdue days, frees the limit; second return fails', async () => {
    const result = await issue();
    await set(`libraryLoans/${result.id}`, { dueDate: day(-2) });
    const ret = await run(loans.loanReturn, { id: result.id, condition: 'good' });
    expect(ret.overdueDays).toBe(2);
    expect(await get(`libraryLoans/${result.id}`)).toMatchObject({ status: 'returned', condition: 'good', overdueDays: 2 });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({ status: 'available', activeLoanId: null });
    expect((await get('libraryMembers/student_501'))!.activeLoans).toBe(0);
    await expect(run(loans.loanReturn, { id: result.id, condition: 'good' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(loans.loanRenew, { id: result.id })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('return: damaged copy is not made available', async () => {
    const result = await issue();
    await run(loans.loanReturn, { id: result.id, condition: 'damaged' });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({ status: 'damaged', activeLoanId: null });
    await expect(issue()).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
