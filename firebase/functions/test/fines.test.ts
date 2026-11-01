import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { fines } from '../src/library/fines';
import { incidents } from '../src/library/incidents';
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

describe('library fines and incidents', () => {
  let l1: string, cat: string, title: string;
  const issue = (copyId = 'ACC-000001', memberId = 'student_501') => run(loans.loanIssue, { memberId, copyId });
  const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({
      perms: ['lib.settings', 'lib.catalogue.manage', 'lib.circulation.operate', 'lib.fines.waive'],
      cmp: [31, 32],
      all: false,
    });
    await db().doc(`schools/${SID}/userAccess/u_no_waive`).set({
      perms: ['lib.circulation.operate'],
      cmp: [31],
      all: false,
    });
    cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
    title = (await run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['Kalam'], categoryId: cat })).id;
    l1 = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, { type: 'purchase', catalogueId: title, libraryId: l1, qty: 3, price: 500 });
    await run(members.policyUpsert, {
      libraryId: l1,
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
    await run(members.memberUpsert, { memberType: 'student', erpId: 501, memberCategory: 'primary', libraryIds: [l1], start: '2020-01-01' });
  });

  it('overdue return calculates fine per policySnapshot, blocks member, writes libFines doc', async () => {
    const r = await issue();
    // 5 days overdue: grace 2 days -> 3 fine days * 5/day = 15
    await set(`libLoans/${r.id}`, { dueOn: day(-5) });
    const ret = await run(loans.loanReturn, { id: r.id, condition: 'good' });
    expect(ret.overdueDays).toBe(5);

    const fine = await get(`libFines/${r.id}__overdue`);
    expect(fine).toMatchObject({
      loanId: r.id,
      memberId: 'student_501',
      personErpId: 501,
      type: 'overdue',
      amount: 15,
      outstanding: 15,
      waived: 0,
      paid: 0,
      status: 'outstanding',
    });
    expect((await get('libMembers/student_501'))!.blocked).toBe(true);
  });

  it('fine waiver: permission check, partial waive, full waive unblocks member', async () => {
    const r = await issue();
    await set(`libLoans/${r.id}`, { dueOn: day(-5) });
    await run(loans.loanReturn, { id: r.id, condition: 'good' });
    const fineId = `${r.id}__overdue`;

    // Without lib.fines.waive
    await expect(run(fines.fineWaive, { id: fineId, amount: 5, reason: 'Valid reason' }, 'u_no_waive')).rejects.toMatchObject({
      code: 'permission-denied',
    });

    // Partial waive: 5 out of 15
    const w1 = await run(fines.fineWaive, { id: fineId, amount: 5, reason: 'Discretionary' });
    expect(w1).toMatchObject({ outstanding: 10, status: 'outstanding' });
    expect((await get('libMembers/student_501'))!.blocked).toBe(true);

    // Cannot waive more than outstanding
    await expect(run(fines.fineWaive, { id: fineId, amount: 20, reason: 'Too much' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });

    // Full waive remainder: 10
    const w2 = await run(fines.fineWaive, { id: fineId, amount: 10, reason: 'Principal waiver' });
    expect(w2).toMatchObject({ outstanding: 0, status: 'waived' });
    expect((await get(`libFines/${fineId}`))!.status).toBe('waived');
    // Member is now unblocked
    expect((await get('libMembers/student_501'))!.blocked).toBe(false);
  });

  it('payment recording: partial payment, full payment unblocks member', async () => {
    const r = await issue();
    await set(`libLoans/${r.id}`, { dueOn: day(-5) });
    await run(loans.loanReturn, { id: r.id, condition: 'good' });
    const fineId = `${r.id}__overdue`;

    const p1 = await run(fines.fineSetPayment, { id: fineId, paidAmount: 10, reference: 'REC-123' });
    expect(p1).toMatchObject({ outstanding: 5, status: 'partially_paid' });
    expect((await get('libMembers/student_501'))!.blocked).toBe(true);

    const p2 = await run(fines.fineSetPayment, { id: fineId, paidAmount: 5, reference: 'REC-124' });
    expect(p2).toMatchObject({ outstanding: 0, status: 'paid' });
    expect((await get('libMembers/student_501'))!.blocked).toBe(false);
  });

  it('mark lost: updates loan and copy, fines replacement cost, creates incident, blocks member', async () => {
    const r = await issue();
    const lost = await run(loans.loanMarkLost, { id: r.id, reason: 'Lost on bus', charge: 500 });
    expect(lost.charge).toBe(500);

    expect(await get(`libLoans/${r.id}`)).toMatchObject({ status: 'lost', lostRemarks: 'Lost on bus' });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'lost', activeLoanId: null });
    expect((await get('libMembers/student_501'))!.blocked).toBe(true);

    const fine = await get(`libFines/${r.id}__lost`);
    expect(fine).toMatchObject({
      type: 'lost',
      amount: 500,
      outstanding: 500,
      status: 'outstanding',
    });

    const incs = (await db().collection(`schools/${SID}/libIncidents`).where('loanId', '==', r.id).get()).docs;
    expect(incs).toHaveLength(1);
    expect(incs[0].data()).toMatchObject({
      kind: 'lost',
      copyId: 'ACC-000001',
      charge: 500,
      status: 'open',
    });
  });

  it('damaged return creates incident; resolving repaired releases copy to available', async () => {
    const r = await issue();
    await run(loans.loanReturn, { id: r.id, condition: 'damaged', remarks: 'Torn spine' });

    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'damaged' });

    const incs = (await db().collection(`schools/${SID}/libIncidents`).where('loanId', '==', r.id).get()).docs;
    expect(incs).toHaveLength(1);
    const incId = incs[0].id;
    expect(incs[0].data()).toMatchObject({
      kind: 'damaged',
      severity: 'moderate',
      description: 'Torn spine',
      status: 'open',
    });

    // Resolve as repaired
    await run(incidents.resolve, { id: incId, resolution: 'repaired', remarks: 'Rebound with tape' });
    expect(await get(`libIncidents/${incId}`)).toMatchObject({ status: 'resolved', resolution: 'repaired', repairStatus: 'repaired' });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'available' });
  });

  it('reporting direct incident on shelf copy', async () => {
    const res = await run(incidents.incidentReport, {
      copyId: 'ACC-000002',
      kind: 'damaged',
      severity: 'severe',
      description: 'Water damaged on shelf',
    });
    expect(res.number).toMatch(/^INC\//);
    expect(await get('libCopies/ACC-000002')).toMatchObject({ status: 'damaged' });

    // Resolve as written_off
    await run(incidents.resolve, { id: res.id, resolution: 'written_off', remarks: 'Pages ruined' });
    expect(await get('libCopies/ACC-000002')).toMatchObject({ status: 'withdrawn' });
  });
});
