import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { fines } from '../src/library/fines';
import { incidents } from '../src/library/incidents';
import { loans } from '../src/library/loans';
import { masters } from '../src/library/masters';
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
const set = (path: string, data: Record<string, unknown>) =>
  db().doc(`schools/${SCHOOL_ID}/${path}`).update(data);

describe('library fines and incidents', () => {
  let mainLibrary: string, category: string, title: string;
  const issue = (copyId = 'ACC-000001', memberId = 'student_501') =>
    run(loans.loanIssue, { memberId, copyId });
  const day = (offset: number) =>
    new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: [
          'library.settings',
          'library.catalogue.manage',
          'library.circulation.operate',
          'library.fines.waive',
        ],
        campusIds: [31, 32],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/no_waive`)
      .set({
        permissions: ['library.circulation.operate'],
        campusIds: [31],
        hasAllCampuses: false,
      });
    category = (await seedLibraryCategory({ code: 'GEN', name: 'General' })).id;
    title = (
      await run(masters.catalogueUpsert, {
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ code: 'L1', name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, {
      type: 'purchase',
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 3,
      price: 500,
    });
    await run(members.policyUpsert, {
      libraryId: mainLibrary,
      memberCategory: 'primary',
      name: 'Primary',
      maxBooks: 2,
      loanDays: 7,
      maxRenewals: 1,
      fineType: 'per_day',
      fineAmount: 5,
      graceDays: 2,
      maxFine: 50,
      canReserve: true,
    });
    await run(members.memberUpsert, {
      memberType: 'student',
      personErpId: 501,
      memberCategory: 'primary',
      libraryIds: [mainLibrary],
      start: '2020-01-01',
    });
  });

  it('overdue return calculates fine per policySnapshot, blocks member, writes libraryFines doc', async () => {
    const issued = await issue();
    // 5 days overdue: grace 2 days -> 3 fine days * 5/day = 15
    await set(`libraryLoans/${issued.id}`, { dueDate: day(-5) });
    const ret = await run(loans.loanReturn, { id: issued.id, condition: 'good' });
    expect(ret.overdueDays).toBe(5);

    const fine = await get(`libraryFines/${issued.id}__overdue`);
    expect(fine).toMatchObject({
      loanId: issued.id,
      memberId: 'student_501',
      personErpId: 501,
      type: 'overdue',
      amount: 15,
      outstanding: 15,
      waived: 0,
      paid: 0,
      status: 'outstanding',
    });
    expect((await get('libraryMembers/student_501'))!.blocked).toBe(true);
  });

  it('fine waiver: permission check, partial waive, full waive unblocks member', async () => {
    const issued = await issue();
    await set(`libraryLoans/${issued.id}`, { dueDate: day(-5) });
    await run(loans.loanReturn, { id: issued.id, condition: 'good' });
    const fineId = `${issued.id}__overdue`;

    // Without lib.fines.waive
    await expect(
      run(fines.fineWaive, { id: fineId, amount: 5, reason: 'Valid reason' }, 'no_waive'),
    ).rejects.toMatchObject({
      code: 'permission-denied',
    });

    // Partial waive: 5 out of 15
    const firstWaiver = await run(fines.fineWaive, {
      id: fineId,
      amount: 5,
      reason: 'Discretionary',
    });
    expect(firstWaiver).toMatchObject({ outstanding: 10, status: 'outstanding' });
    expect((await get('libraryMembers/student_501'))!.blocked).toBe(true);

    // Cannot waive more than outstanding
    await expect(
      run(fines.fineWaive, { id: fineId, amount: 20, reason: 'Too much' }),
    ).rejects.toMatchObject({
      code: 'failed-precondition',
    });

    // Full waive remainder: 10
    const secondWaiver = await run(fines.fineWaive, {
      id: fineId,
      amount: 10,
      reason: 'Principal waiver',
    });
    expect(secondWaiver).toMatchObject({ outstanding: 0, status: 'waived' });
    expect((await get(`libraryFines/${fineId}`))!.status).toBe('waived');
    // Member is now unblocked
    expect((await get('libraryMembers/student_501'))!.blocked).toBe(false);
  });

  it('payment recording: partial payment, full payment unblocks member', async () => {
    const issued = await issue();
    await set(`libraryLoans/${issued.id}`, { dueDate: day(-5) });
    await run(loans.loanReturn, { id: issued.id, condition: 'good' });
    const fineId = `${issued.id}__overdue`;

    const firstPayment = await run(fines.fineSetPayment, {
      id: fineId,
      paidAmount: 10,
      reference: 'REC-123',
    });
    expect(firstPayment).toMatchObject({ outstanding: 5, status: 'partially_paid' });
    expect((await get('libraryMembers/student_501'))!.blocked).toBe(true);

    const secondPayment = await run(fines.fineSetPayment, {
      id: fineId,
      paidAmount: 5,
      reference: 'REC-124',
    });
    expect(secondPayment).toMatchObject({ outstanding: 0, status: 'paid' });
    expect((await get('libraryMembers/student_501'))!.blocked).toBe(false);
  });

  it('mark lost: updates loan and copy, fines replacement cost, creates incident, blocks member', async () => {
    const issued = await issue();
    const lost = await run(loans.loanMarkLost, {
      id: issued.id,
      reason: 'Lost on bus',
      charge: 500,
    });
    expect(lost.charge).toBe(500);

    expect(await get(`libraryLoans/${issued.id}`)).toMatchObject({
      status: 'lost',
      lostRemarks: 'Lost on bus',
    });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'lost',
      activeLoanId: null,
    });
    expect((await get('libraryMembers/student_501'))!.blocked).toBe(true);

    const fine = await get(`libraryFines/${issued.id}__lost`);
    expect(fine).toMatchObject({
      type: 'lost',
      amount: 500,
      outstanding: 500,
      status: 'outstanding',
    });

    const incs = (
      await db()
        .collection(`schools/${SCHOOL_ID}/libraryIncidents`)
        .where('loanId', '==', issued.id)
        .get()
    ).docs;
    expect(incs).toHaveLength(1);
    expect(incs[0].data()).toMatchObject({
      type: 'lost',
      copyId: 'ACC-000001',
      charge: 500,
      status: 'open',
    });
  });

  it('damaged return creates incident; resolving repaired releases copy to available', async () => {
    const issued = await issue();
    await run(loans.loanReturn, { id: issued.id, condition: 'damaged', remarks: 'Torn spine' });

    expect(await get('libraryCopies/ACC-000001')).toMatchObject({ status: 'damaged' });

    const incs = (
      await db()
        .collection(`schools/${SCHOOL_ID}/libraryIncidents`)
        .where('loanId', '==', issued.id)
        .get()
    ).docs;
    expect(incs).toHaveLength(1);
    const incId = incs[0].id;
    expect(incs[0].data()).toMatchObject({
      type: 'damaged',
      severity: 'moderate',
      description: 'Torn spine',
      status: 'open',
    });

    // Resolve as repaired
    await run(incidents.resolve, {
      id: incId,
      resolution: 'repaired',
      remarks: 'Rebound with tape',
    });
    expect(await get(`libraryIncidents/${incId}`)).toMatchObject({
      status: 'resolved',
      resolution: 'repaired',
      repairStatus: 'repaired',
    });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({ status: 'available' });
  });

  it('reporting direct incident on shelf copy', async () => {
    const result = await run(incidents.incidentReport, {
      copyId: 'ACC-000002',
      type: 'damaged',
      severity: 'severe',
      description: 'Water damaged on shelf',
    });
    expect(result.number).toMatch(/^INC\//);
    expect(await get('libraryCopies/ACC-000002')).toMatchObject({ status: 'damaged' });

    // Resolve as written_off
    await run(incidents.resolve, {
      id: result.id,
      resolution: 'written_off',
      remarks: 'Pages ruined',
    });
    expect(await get('libraryCopies/ACC-000002')).toMatchObject({ status: 'withdrawn' });
  });

  it('incident guards: on-loan copy, duplicate open incident, repair of lost, charge reduction; dismissed restores copy', async () => {
    const issued = await issue();
    await expect(
      run(incidents.incidentReport, { copyId: 'ACC-000001', type: 'lost' }),
    ).rejects.toThrow(/on loan/);

    const inc = await run(incidents.incidentReport, {
      copyId: 'ACC-000002',
      type: 'damaged',
      charge: 40,
      memberId: 'student_501',
    });
    await expect(
      run(incidents.incidentReport, { copyId: 'ACC-000002', type: 'damaged' }),
    ).rejects.toThrow(/open incident/);
    await expect(
      run(incidents.resolve, { id: inc.id, resolution: 'dismissed', charge: 10 }),
    ).rejects.toThrow(/lowered/);

    await run(incidents.resolve, { id: inc.id, resolution: 'dismissed' });
    expect(await get('libraryCopies/ACC-000002')).toMatchObject({ status: 'available' });

    await run(loans.loanMarkLost, { id: issued.id });
    const lost = (
      await db()
        .collection(`schools/${SCHOOL_ID}/libraryIncidents`)
        .where('type', '==', 'lost')
        .get()
    ).docs[0];
    await expect(run(incidents.resolve, { id: lost.id, resolution: 'repaired' })).rejects.toThrow(
      /damaged copy/,
    );
  });
});
