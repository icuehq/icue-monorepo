import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { dayTimestamp } from '../src/shared/dates';
import { loans } from './circulation';
import {
  seedLibrary,
  seedLibraryCategory,
  seedLibraryPolicy,
  seedLibraryTitle,
  person,
} from './fixtures';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
let requestSequence = 0;

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(
    definition,
    { uid, token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } },
    { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data },
  );
const get = async (path: string) => (await db().doc(`${BRANCH}/${path}`).get()).data();
const set = (path: string, data: Record<string, unknown>) =>
  db().doc(`${BRANCH}/${path}`).update(data);

describe('library circulation', () => {
  let mainLibrary: string, category: string, title: string, policy: string;
  const issue = (barcode = 'ACC-000001', erpId = 501) =>
    run(loans.loanIssue, { person: person(erpId), barcode });
  const day = (offset: number) =>
    new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`${BRANCH}/userAccess/1`)
      .set({
        permissions: [],
      });
    await db()
      .doc(`${BRANCH}/userAccess/2`)
      .set({
        permissions: [],
      });
    category = (await seedLibraryCategory({ name: 'General' })).id;
    title = (
      await seedLibraryTitle({
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ name: 'Main' })).id;
    await run(copies.createBook, {
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 3,
      barcodes: ['ACC-000001', 'ACC-000002', 'ACC-000003'],
    });
    policy = (
      await seedLibraryPolicy({
        libraryId: mainLibrary,
        memberType: 'student',
        name: 'Primary',
        maxBooks: 2,
        loanDays: 7,
        maxRenewals: 1,
        fineType: 'none',
      })
    ).id;
  });

  it('issue sets due date from the policy, marks the copy issued and counts the loan', async () => {
    const result = await issue();
    expect(result.dueDate).toBe(day(7));
    expect(await get(`libraryLoans/${result.id}`)).toMatchObject({
      status: 'active',
      personErpId: 501,
      barcode: 'ACC-000001',
      policySnapshot: { policyId: policy, loanDays: 7, maxRenewals: 1 },
    });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'issued',
      activeLoanId: result.id,
    });
    expect((await get('libraryMembers/501'))!.activeLoans).toBe(1);
  });

  it('issue falls back to the default policy for everyone when the person type has none', async () => {
    const teacher = () =>
      run(loans.loanIssue, {
        person: { memberType: 'teacher', personErpId: 9, name: 'T' },
        barcode: 'ACC-000003',
      });
    await expect(teacher()).rejects.toMatchObject({ code: 'failed-precondition' });
    const everyone = await seedLibraryPolicy({
      libraryId: mainLibrary,
      memberType: 'all',
      name: 'Default',
      maxBooks: 5,
      loanDays: 14,
      maxRenewals: 0,
      fineType: 'none',
    });
    const loan = await teacher();
    expect(await get(`libraryLoans/${loan.id}`)).toMatchObject({
      policySnapshot: { policyId: everyone.id, loanDays: 14 },
    });
    expect((await issue()).dueDate).toBe(day(7)); // students keep their own policy
  });

  it('issue creates the borrower on first use and refreshes the name and class after', async () => {
    expect(await get('libraryMembers/501')).toBeUndefined();
    await run(loans.loanIssue, {
      person: { memberType: 'student', personErpId: 501, name: 'Asha Rao', classId: 4 },
      barcode: 'ACC-000001',
    });
    expect(await get('libraryMembers/501')).toMatchObject({
      memberType: 'student',
      personErpId: 501,
      name: 'Asha Rao',
      classId: 4,
      activeLoans: 1,
      blocked: false,
    });
    await run(loans.loanIssue, {
      person: { memberType: 'student', personErpId: 501, name: 'Asha R. Rao', classId: 5 },
      barcode: 'ACC-000002',
    });
    expect(await get('libraryMembers/501')).toMatchObject({
      name: 'Asha R. Rao',
      classId: 5,
      activeLoans: 2,
    });
    expect((await db().collection(`${BRANCH}/libraryMembers`).get()).size).toBe(1);
    const loanDocs = await db().collection(`${BRANCH}/libraryLoans`).get();
    const firstLoan = loanDocs.docs.find((doc) => doc.data().barcode === 'ACC-000001')!.data();
    expect(firstLoan.memberName).toBe('Asha Rao');
    await expect(
      run(loans.loanIssue, {
        person: { memberType: 'teacher', personErpId: 9, name: 'T' },
        barcode: 'ACC-000003',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' }); // no teacher policy in this library
  });

  it('issue rules: copy taken, limit, blocked member, no policy for the type or category', async () => {
    await issue();
    await expect(issue()).rejects.toMatchObject({ code: 'failed-precondition' });
    await issue('ACC-000002');
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' }); // maxBooks 2
    await set('libraryMembers/501', { activeLoans: 0, blocked: true });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libraryMembers/501', { blocked: false });
    // A policy for other categories does not cover this book.
    const other = await seedLibraryCategory({ name: 'Other' });
    await set(`libraryBorrowingPolicies/${policy}`, { categoryIds: [other.id] });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    // A policy for the parent category covers its subcategories.
    const parent = await seedLibraryCategory({ name: 'Parent' });
    await set(`libraryCategories/${category}`, { parentId: parent.id });
    await set(`libraryBorrowingPolicies/${policy}`, { categoryIds: [parent.id] });
    await set(`libraryBorrowingPolicies/${policy}`, { status: 'inactive' });
    await expect(issue('ACC-000003')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set(`libraryBorrowingPolicies/${policy}`, { status: 'active' });
    await set(`libraryBorrowingPolicies/${policy}`, { categoryIds: [], maxBooks: 3 });
    await expect(issue('ACC-000003')).resolves.toBeTruthy();
  });

  it('policy edits do not move existing due dates; renewal uses the frozen snapshot and limit', async () => {
    const result = await issue();
    await set(`libraryBorrowingPolicies/${policy}`, { loanDays: 30, maxRenewals: 5 });
    const first = await run(loans.loanRenew, { id: result.id });
    expect(first.dueDate).toBe(day(14));
    expect((await get(`libraryLoans/${result.id}`))!.renewals).toHaveLength(1);
    await expect(run(loans.loanRenew, { id: result.id })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('an overdue loan cannot be renewed', async () => {
    const result = await issue();
    await set(`libraryLoans/${result.id}`, { dueDate: dayTimestamp(day(-3)) });
    await expect(run(loans.loanRenew, { id: result.id })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('the borrowing limit counts only loans under the same policy', async () => {
    const other = await seedLibraryCategory({ name: 'Other' });
    await set(`libraryBorrowingPolicies/${policy}`, { maxBooks: 1, categoryIds: [category] });
    await seedLibraryPolicy({
      libraryId: mainLibrary,
      memberType: 'student',
      name: 'Rest',
      maxBooks: 1,
      loanDays: 14,
      maxRenewals: 0,
      fineType: 'none',
    });
    const otherTitle = (
      await seedLibraryTitle({ title: 'Other', authors: ['A'], categoryId: other.id })
    ).id;
    await run(copies.createBook, {
      catalogueId: otherTitle,
      libraryId: mainLibrary,
      quantity: 1,
      barcodes: ['ACC-000004'],
    });
    await issue();
    await expect(issue('ACC-000002')).rejects.toMatchObject({ code: 'failed-precondition' });
    const second = await issue('ACC-000004');
    expect(second.dueDate).toBe(day(14));
  });

  it('return: good makes the copy available, records overdue days, frees the limit; second return fails', async () => {
    const result = await issue();
    await set(`libraryLoans/${result.id}`, { dueDate: dayTimestamp(day(-2)) });
    const ret = await run(loans.loanReturn, { id: result.id, condition: 'good' });
    expect(ret.overdueDays).toBe(2);
    expect(await get(`libraryLoans/${result.id}`)).toMatchObject({
      status: 'returned',
      condition: 'good',
      overdueDays: 2,
    });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'available',
      activeLoanId: null,
    });
    expect((await get('libraryMembers/501'))!.activeLoans).toBe(0);
    await expect(run(loans.loanReturn, { id: result.id, condition: 'good' })).rejects.toMatchObject(
      { code: 'failed-precondition' },
    );
    await expect(run(loans.loanRenew, { id: result.id })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('return: damaged copy is not made available', async () => {
    const result = await issue();
    await run(loans.loanReturn, { id: result.id, condition: 'damaged' });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'damaged',
      activeLoanId: null,
    });
    await expect(issue()).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
