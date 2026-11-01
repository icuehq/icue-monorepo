import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { loans } from '../src/library/loans';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { reservations } from '../src/library/reservations';
import { transfers } from '../src/library/transfers';
import { verification } from '../src/library/verification';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();

describe('library transfers and stock verification', () => {
  let l1: string, l2: string, title: string;

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({
      perms: ['lib.settings', 'lib.catalogue.manage', 'lib.circulation.operate'],
      cmp: [31, 32],
      all: false,
    });
    await db().doc(`schools/${SID}/userAccess/u_dest`).set({ perms: ['lib.catalogue.manage'], cmp: [32], all: false });
    await db().doc(`schools/${SID}/userAccess/u_src`).set({ perms: ['lib.catalogue.manage'], cmp: [31], all: false });
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
    title = (await run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['Kalam'], categoryId: cat })).id;
    l1 = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    l2 = (await run(masters.libraryUpsert, { code: 'L2', name: 'Branch', campusId: 32 })).id;
    await run(copies.acquisitionCreate, { type: 'purchase', catalogueId: title, libraryId: l1, qty: 3, price: 500 });
  });

  const request = (copyIds = ['ACC-000001', 'ACC-000002']) =>
    run(transfers.transferRequest, { fromLibraryId: l1, toLibraryId: l2, copyIds }, 'u_src');

  it('request → approve → dispatch → receive moves copies; in-transit copies cannot be issued', async () => {
    const t = await request();
    expect((await get(`libTransfers/${t.id}`))?.status).toBe('requested');
    await expect(run(transfers.transferDispatch, { id: t.id }, 'u_src')).rejects.toThrow(/requested/);
    await run(transfers.transferApprove, { id: t.id });
    await run(transfers.transferDispatch, { id: t.id }, 'u_src');
    expect((await get('libCopies/ACC-000001'))?.status).toBe('in_transit');

    await run(members.policyUpsert, { libraryId: l1, memberCategory: 'primary', name: 'P', maxBooks: 2, loanDays: 7, maxRenewals: 1, fineType: 'per_day', fineAmount: 5, graceDays: 2, maxFine: 50, canReserve: true });
    await run(members.memberUpsert, { memberType: 'student', erpId: 501, memberCategory: 'primary', libraryIds: [l1], start: '2020-01-01' });
    await expect(run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000001' })).rejects.toThrow(/in_transit/);

    // only the destination campus may receive
    await expect(run(transfers.transferReceive, { id: t.id, copies: [{ copyId: 'ACC-000001' }] }, 'u_src')).rejects.toThrow(/Campus/);
    const part = await run(transfers.transferReceive, { id: t.id, copies: [{ copyId: 'ACC-000001', condition: 'fair' }] }, 'u_dest');
    expect(part.status).toBe('partially_received');
    expect(await get('libCopies/ACC-000001')).toMatchObject({ status: 'available', libraryId: l2, campusId: 32, condition: 'fair' });
    expect((await get('libCopies/ACC-000002'))?.status).toBe('in_transit');
    await expect(run(transfers.transferReceive, { id: t.id, copies: [{ copyId: 'ACC-000001' }] }, 'u_dest')).rejects.toThrow(/already received/);

    const done = await run(transfers.transferReceive, { id: t.id, copies: [{ copyId: 'ACC-000002' }] }, 'u_dest');
    expect(done.status).toBe('received');
    expect((await get(`libTransfers/${t.id}`))?.receivedOn).toBeTruthy();
  });

  it('rejects unavailable copies, same library and copies from another library', async () => {
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'damaged', reason: 'torn' });
    await expect(request(['ACC-000001'])).rejects.toThrow(/damaged/);
    await expect(run(transfers.transferRequest, { fromLibraryId: l1, toLibraryId: l1, copyIds: ['ACC-000002'] })).rejects.toThrow(/differ/);
    await expect(run(transfers.transferRequest, { fromLibraryId: l2, toLibraryId: l1, copyIds: ['ACC-000002'] }, 'u_1')).rejects.toThrow(/not in the source/);
  });

  it('dispatch fails if a copy left the shelf after approval', async () => {
    const t = await request();
    await run(transfers.transferApprove, { id: t.id });
    await run(copies.copySetStatus, { id: 'ACC-000002', status: 'under_maintenance', reason: 'x' });
    await expect(run(transfers.transferDispatch, { id: t.id })).rejects.toThrow(/no longer available/);
    expect((await get('libCopies/ACC-000001'))?.status).toBe('available');
  });

  it('received copies serve the destination waiting list first', async () => {
    await run(copies.acquisitionCreate, { type: 'purchase', catalogueId: title, libraryId: l2, qty: 1, price: 500 });
    await run(copies.copySetStatus, { id: 'ACC-000004', status: 'damaged', reason: 'x' });
    await run(members.policyUpsert, { libraryId: l2, memberCategory: 'primary', name: 'P', maxBooks: 2, loanDays: 7, maxRenewals: 1, fineType: 'per_day', fineAmount: 5, graceDays: 2, maxFine: 50, canReserve: true });
    await run(members.memberUpsert, { memberType: 'student', erpId: 502, memberCategory: 'primary', libraryIds: [l2], start: '2020-01-01' });
    await run(reservations.reservationCreate, { memberId: 'student_502', catalogueId: title, libraryId: l2 });

    const t = await request(['ACC-000001', 'ACC-000002']);
    await run(transfers.transferApprove, { id: t.id });
    await run(transfers.transferDispatch, { id: t.id }, 'u_src');
    await run(transfers.transferReceive, { id: t.id, copies: [{ copyId: 'ACC-000001' }, { copyId: 'ACC-000002' }] }, 'u_dest');
    expect((await get('libCopies/ACC-000001'))?.status).toBe('reserved');
    expect((await get('libCopies/ACC-000002'))?.status).toBe('available');
  });

  describe('verification', () => {
    it('lists issued copies apart, flags missing and unexpected, and approves corrections', async () => {
      await run(copies.acquisitionCreate, { type: 'purchase', catalogueId: title, libraryId: l2, qty: 1, price: 500 }); // ACC-000004 in L2
      await run(members.policyUpsert, { libraryId: l1, memberCategory: 'primary', name: 'P', maxBooks: 2, loanDays: 7, maxRenewals: 1, fineType: 'per_day', fineAmount: 5, graceDays: 2, maxFine: 50, canReserve: true });
      await run(members.memberUpsert, { memberType: 'student', erpId: 501, memberCategory: 'primary', libraryIds: [l1], start: '2020-01-01' });
      await run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000003' });

      const v = await run(verification.verificationCreate, { libraryId: l1 });
      expect(await get(`libVerifications/${v.id}`)).toMatchObject({ status: 'counting', expected: ['ACC-000001', 'ACC-000002'], onLoan: ['ACC-000003'] });

      await expect(run(verification.verificationScan, { id: v.id, accessionNos: ['ACC-999999'] })).rejects.toThrow(/Unknown/);
      await run(verification.verificationScan, { id: v.id, accessionNos: ['ACC-000001', 'ACC-000004'] });
      const s = await run(verification.verificationScan, { id: v.id, accessionNos: ['ACC-000001'] }); // repeat is harmless
      expect(s).toMatchObject({ scanned: 2, unexpected: 1 });

      const sub = await run(verification.verificationSubmit, { id: v.id });
      expect(sub).toMatchObject({ status: 'submitted', missing: 1, unexpected: 1 });
      await expect(run(verification.verificationScan, { id: v.id, accessionNos: ['ACC-000002'] })).rejects.toThrow(/submitted/);

      await expect(run(verification.verificationApprove, { id: v.id, lost: ['ACC-000001'] })).rejects.toThrow(/missing/);
      await expect(run(verification.verificationApprove, { id: v.id, lost: ['ACC-000002'] }, 'u_src')).rejects.toThrow(/Not allowed/);
      await run(verification.verificationApprove, { id: v.id, lost: ['ACC-000002'], move: ['ACC-000004'] });
      expect((await get('libCopies/ACC-000002'))?.status).toBe('lost');
      expect(await get('libCopies/ACC-000004')).toMatchObject({ libraryId: l1, campusId: 31 });
      expect((await get(`libVerifications/${v.id}`))?.status).toBe('approved');
    });

    it('a clean count is approved on submit; missing copies left alone are recorded for investigation', async () => {
      const v = await run(verification.verificationCreate, { libraryId: l1 });
      await run(verification.verificationScan, { id: v.id, accessionNos: ['ACC-000001', 'ACC-000002', 'ACC-000003'] });
      expect(await run(verification.verificationSubmit, { id: v.id })).toMatchObject({ status: 'approved' });

      const w = await run(verification.verificationCreate, { libraryId: l1 });
      await run(verification.verificationScan, { id: w.id, accessionNos: ['ACC-000001'] });
      await run(verification.verificationSubmit, { id: w.id });
      await run(verification.verificationApprove, { id: w.id });
      expect((await get(`libVerifications/${w.id}`))?.investigate).toEqual(['ACC-000002', 'ACC-000003']);
      expect((await get('libCopies/ACC-000002'))?.status).toBe('available');
    });
  });
});
