import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { loans } from '../src/library/loans';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { reservations, runHoldExpiry } from '../src/library/reservations';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const set = (path: string, data: Record<string, unknown>) => db().doc(`schools/${SID}/${path}`).update(data);
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('library reservations', () => {
  let l1: string, title: string;
  const reserve = (memberId: string) => run(reservations.reservationCreate, { memberId, catalogueId: title, libraryId: l1 });
  const enrol = (erpId: number) => run(members.memberUpsert, { memberType: 'student', erpId, memberCategory: 'primary', libraryIds: [l1], start: '2020-01-01' });
  const issue = (memberId: string, copyId = 'ACC-000001') => run(loans.loanIssue, { memberId, copyId });

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({ perms: ['lib.settings', 'lib.catalogue.manage', 'lib.circulation.operate'], cmp: [31], all: false });
    await db().doc(`schools/${SID}/userAccess/u_2`).set({ perms: ['lib.circulation.operate'], cmp: [99], all: false });
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
    title = (await run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['Kalam'], categoryId: cat })).id;
    l1 = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, { type: 'donation', catalogueId: title, libraryId: l1, qty: 1 });
    await run(members.policyUpsert, { libraryId: l1, memberCategory: 'primary', name: 'Primary', maxBooks: 2, loanDays: 7, maxRenewals: 2, fineType: 'none', canReserve: true });
    for (const e of [501, 502, 503]) await enrol(e);
    await issue('student_501');
  });

  it('queue: waits in order, return holds the copy for the first, only they can issue it, fulfilment is recorded', async () => {
    const a = await reserve('student_502');
    const b = await reserve('student_503');
    expect(await get(`libReservations/${a.id}`)).toMatchObject({ status: 'waiting', personErpId: 502, campusId: 31 });
    const loan = (await db().collection(`schools/${SID}/libLoans`).get()).docs[0];
    await run(loans.loanReturn, { id: loan.id, condition: 'good' });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'reserved', heldReservationId: a.id });
    expect(await get(`libReservations/${a.id}`)).toMatchObject({ status: 'ready', heldCopyId: 'ACC-000001', holdUntil: day(3) });
    expect((await get(`libReservations/${b.id}`))!.status).toBe('waiting');
    expect((await db().collection(`schools/${SID}/outbox`).get()).size).toBe(1);
    await expect(issue('student_503')).rejects.toMatchObject({ code: 'failed-precondition' });
    const r = await issue('student_502');
    expect(await get(`libReservations/${a.id}`)).toMatchObject({ status: 'fulfilled', fulfilledLoanId: r.id, fulfilledCopyId: 'ACC-000001' });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'issued', heldReservationId: null });
  });

  it('create rules: copy on shelf, duplicate, on loan, policy, inactive, campus', async () => {
    await expect(reserve('student_501')).rejects.toMatchObject({ code: 'failed-precondition' }); // already has it
    await reserve('student_502');
    await expect(reserve('student_502')).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(reservations.reservationCreate, { memberId: 'student_503', catalogueId: title, libraryId: l1 }, 'u_2')).rejects.toMatchObject({ code: 'permission-denied' });
    await set(`libPolicies/${l1}_primary`, { canReserve: false });
    await expect(reserve('student_503')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set(`libPolicies/${l1}_primary`, { canReserve: true });
    await set('libMembers/student_503', { blocked: true });
    await expect(reserve('student_503')).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libMembers/student_503', { blocked: false });
    await set('libCopies/ACC-000001', { status: 'available', activeLoanId: null });
    await expect(reserve('student_503')).rejects.toMatchObject({ code: 'failed-precondition' }); // shelf copy
  });

  it('cancelling a ready reservation passes the copy on; with nobody waiting it goes back on the shelf', async () => {
    const a = await reserve('student_502');
    const b = await reserve('student_503');
    const loan = (await db().collection(`schools/${SID}/libLoans`).get()).docs[0];
    await run(loans.loanReturn, { id: loan.id, condition: 'good' });
    await run(reservations.reservationCancel, { id: a.id });
    expect(await get(`libReservations/${a.id}`)).toMatchObject({ status: 'cancelled' });
    expect(await get(`libReservations/${b.id}`)).toMatchObject({ status: 'ready' });
    await run(reservations.reservationCancel, { id: b.id });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'available', heldReservationId: null });
    await expect(run(reservations.reservationCancel, { id: b.id })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('expired hold releases the copy to the next member; ineligible members are skipped but keep their place', async () => {
    const a = await reserve('student_502');
    const b = await reserve('student_503');
    const loan = (await db().collection(`schools/${SID}/libLoans`).get()).docs[0];
    await run(loans.loanReturn, { id: loan.id, condition: 'good' });
    await runHoldExpiry(SID, day(1));
    expect((await get(`libReservations/${a.id}`))!.status).toBe('ready'); // not due yet
    await set('libMembers/student_503', { blocked: true });
    await runHoldExpiry(SID, day(4));
    expect((await get(`libReservations/${a.id}`))!.status).toBe('expired');
    expect((await get(`libReservations/${b.id}`))!.status).toBe('waiting'); // blocked: skipped
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'available', heldReservationId: null });
  });

  it('renewal is refused while someone waits; new copies and repaired copies serve the queue', async () => {
    const a = await reserve('student_502');
    const loan = (await db().collection(`schools/${SID}/libLoans`).get()).docs[0];
    await expect(run(loans.loanRenew, { id: loan.id })).rejects.toMatchObject({ code: 'failed-precondition' });
    const acq = await run(copies.acquisitionCreate, { type: 'donation', catalogueId: title, libraryId: l1, qty: 2 });
    expect(await get(`libReservations/${a.id}`)).toMatchObject({ status: 'ready', heldCopyId: acq.copyIds[0] });
    expect(await get(`libCopies/${acq.copyIds[0]}`)).toMatchObject({ status: 'reserved', heldReservationId: a.id });
    expect(await get(`libCopies/${acq.copyIds[1]}`)).toMatchObject({ status: 'available' });
    await expect(run(loans.loanRenew, { id: loan.id })).resolves.toBeTruthy(); // nobody waiting any more
  });
});
