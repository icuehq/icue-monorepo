import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { loans } from '../src/library/loans';
import { members } from '../src/library/members';
import { reservations, runHoldExpiry } from '../src/library/reservations';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { dayTimestamp } from '../src/shared/dates';
import { seedLibrary, seedLibraryCategory, seedLibraryTitle, person } from './fixtures';
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
  db().doc(`schools/${SCHOOL_ID}/${path}`).set(data, { merge: true });
const day = (offset: number) =>
  new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('library reservations', () => {
  let mainLibrary: string, title: string, policy: string;
  const reserve = (erpId: number) =>
    run(reservations.reservationCreate, {
      person: person(erpId),
      catalogueId: title,
      libraryId: mainLibrary,
    });
  const issue = (erpId: number, barcode = 'ACC-000001') =>
    run(loans.loanIssue, { person: person(erpId), barcode });

  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: [],
        campusIds: [31],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/2`)
      .set({
        permissions: [],
        campusIds: [99],
        hasAllCampuses: false,
      });
    const category = (await seedLibraryCategory({ name: 'General' })).id;
    title = (
      await seedLibraryTitle({
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ name: 'Main', campusId: 31 })).id;
    await run(copies.acquisitionCreate, {
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 1,
      barcodes: ['ACC-000001'],
    });
    policy = (
      await run(members.policyUpsert, {
        libraryId: mainLibrary,
        memberType: 'student',
        name: 'Primary',
        maxBooks: 2,
        loanDays: 7,
        maxRenewals: 2,
        fineType: 'none',
      })
    ).id;
    await issue(501);
  });

  it('queue: waits in order, return holds the copy for the first, only they can issue it, fulfilment is recorded', async () => {
    const first = await reserve(502);
    const second = await reserve(503);
    expect(await get(`libraryReservations/${first.id}`)).toMatchObject({
      status: 'waiting',
      personErpId: 502,
      campusId: 31,
    });
    const loan = (await db().collection(`schools/${SCHOOL_ID}/libraryLoans`).get()).docs[0];
    await run(loans.loanReturn, { id: loan.id, condition: 'good' });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'reserved',
      heldReservationId: first.id,
    });
    expect(await get(`libraryReservations/${first.id}`)).toMatchObject({
      status: 'ready',
      heldBarcode: 'ACC-000001',
      holdUntil: dayTimestamp(day(3)),
    });
    expect((await get(`libraryReservations/${second.id}`))!.status).toBe('waiting');
    expect(
      (await db().collection(`schools/${SCHOOL_ID}/outbox`).get()).docs.filter((outboxDocument) =>
        outboxDocument.id.startsWith('library-reservation-ready__'),
      ),
    ).toHaveLength(1);
    await expect(issue(503)).rejects.toMatchObject({ code: 'failed-precondition' });
    const result = await issue(502);
    expect(await get(`libraryReservations/${first.id}`)).toMatchObject({
      status: 'fulfilled',
      fulfilledLoanId: result.id,
      fulfilledBarcode: 'ACC-000001',
    });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'issued',
      heldReservationId: null,
    });
  });

  it('create rules: copy on shelf, duplicate, on loan, policy, inactive, campus', async () => {
    await expect(reserve(501)).rejects.toMatchObject({ code: 'failed-precondition' }); // already has it
    await reserve(502);
    await expect(reserve(502)).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(
      run(
        reservations.reservationCreate,
        { person: person(503), catalogueId: title, libraryId: mainLibrary },
        '2',
      ),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await set(`libraryBorrowingPolicies/${policy}`, { status: 'inactive' });
    await expect(reserve(503)).rejects.toMatchObject({ code: 'failed-precondition' });
    await set(`libraryBorrowingPolicies/${policy}`, { status: 'active' });
    await set('libraryMembers/503', { blocked: true });
    await expect(reserve(503)).rejects.toMatchObject({ code: 'failed-precondition' });
    await set('libraryMembers/503', { blocked: false });
    await set('libraryCopies/ACC-000001', { status: 'available', activeLoanId: null });
    await expect(reserve(503)).rejects.toMatchObject({ code: 'failed-precondition' }); // shelf copy
  });

  it('cancelling a ready reservation passes the copy on; with nobody waiting it goes back on the shelf', async () => {
    const first = await reserve(502);
    const second = await reserve(503);
    const loan = (await db().collection(`schools/${SCHOOL_ID}/libraryLoans`).get()).docs[0];
    await run(loans.loanReturn, { id: loan.id, condition: 'good' });
    await run(reservations.reservationCancel, { id: first.id });
    expect(await get(`libraryReservations/${first.id}`)).toMatchObject({ status: 'cancelled' });
    expect(await get(`libraryReservations/${second.id}`)).toMatchObject({ status: 'ready' });
    await run(reservations.reservationCancel, { id: second.id });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'available',
      heldReservationId: null,
    });
    await expect(run(reservations.reservationCancel, { id: second.id })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  it('expired hold releases the copy to the next member; ineligible members are skipped but keep their place', async () => {
    const first = await reserve(502);
    const second = await reserve(503);
    const loan = (await db().collection(`schools/${SCHOOL_ID}/libraryLoans`).get()).docs[0];
    await run(loans.loanReturn, { id: loan.id, condition: 'good' });
    await runHoldExpiry(SCHOOL_ID, day(1));
    expect((await get(`libraryReservations/${first.id}`))!.status).toBe('ready'); // not due yet
    await set('libraryMembers/503', { blocked: true });
    await runHoldExpiry(SCHOOL_ID, day(4));
    expect((await get(`libraryReservations/${first.id}`))!.status).toBe('expired');
    expect((await get(`libraryReservations/${second.id}`))!.status).toBe('waiting'); // blocked: skipped
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'available',
      heldReservationId: null,
    });
  });

  it('renewal is refused while someone waits; new copies and repaired copies serve the queue', async () => {
    const first = await reserve(502);
    const loan = (await db().collection(`schools/${SCHOOL_ID}/libraryLoans`).get()).docs[0];
    await expect(run(loans.loanRenew, { id: loan.id })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    const acq = await run(copies.acquisitionCreate, {
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 2,
      barcodes: ['ACC-000002', 'ACC-000003'],
    });
    expect(await get(`libraryReservations/${first.id}`)).toMatchObject({
      status: 'ready',
      heldBarcode: acq.barcodes[0],
    });
    expect(await get(`libraryCopies/${acq.barcodes[0]}`)).toMatchObject({
      status: 'reserved',
      heldReservationId: first.id,
    });
    expect(await get(`libraryCopies/${acq.barcodes[1]}`)).toMatchObject({ status: 'available' });
    await expect(run(loans.loanRenew, { id: loan.id })).resolves.toBeTruthy(); // nobody waiting any more
  });
});
