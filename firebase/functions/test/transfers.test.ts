import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { loans } from '../src/library/loans';
import { masters } from '../src/library/masters';
import { members } from '../src/library/members';
import { reservations } from '../src/library/reservations';
import { transfers } from '../src/library/transfers';
import { verification } from '../src/library/verification';
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

describe('library transfers and stock verification', () => {
  let mainLibrary: string, secondLibrary: string, title: string;

  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: [
          'library.settings',
          'library.catalogue.manage',
          'library.circulation.operate',
        ],
        campusIds: [31, 32],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/approver`)
      .set({
        permissions: ['library.settings', 'library.catalogue.manage'],
        campusIds: [31, 32],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/dest`)
      .set({ permissions: ['library.catalogue.manage'], campusIds: [32], hasAllCampuses: false });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/src`)
      .set({ permissions: ['library.catalogue.manage'], campusIds: [31], hasAllCampuses: false });
    const category = (await seedLibraryCategory({ code: 'GEN', name: 'General' })).id;
    title = (
      await run(masters.catalogueUpsert, {
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ code: 'L1', name: 'Main', campusId: 31 })).id;
    secondLibrary = (await seedLibrary({ code: 'L2', name: 'Branch', campusId: 32 })).id;
    await run(copies.acquisitionCreate, {
      type: 'purchase',
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 3,
      price: 500,
    });
  });

  const request = (copyIds = ['ACC-000001', 'ACC-000002']) =>
    run(
      transfers.transferRequest,
      { fromLibraryId: mainLibrary, toLibraryId: secondLibrary, copyIds },
      'src',
    );

  it('a transfer can be withdrawn before dispatch, cannot be approved by its requester, and can close short', async () => {
    const withdrawn = await request();
    await expect(
      run(transfers.transferCancel, { id: withdrawn.id, reason: '' }, 'src'),
    ).rejects.toThrow();
    await run(transfers.transferCancel, { id: withdrawn.id, reason: 'Not needed' }, 'src');
    expect((await get(`libraryTransfers/${withdrawn.id}`))?.status).toBe('cancelled');

    const own = await run(
      transfers.transferRequest,
      {
        fromLibraryId: mainLibrary,
        toLibraryId: secondLibrary,
        copyIds: ['ACC-000001', 'ACC-000002'],
      },
      'approver',
    );
    await expect(run(transfers.transferApprove, { id: own.id }, 'approver')).rejects.toThrow(
      /different user/,
    );
    await run(transfers.transferApprove, { id: own.id });
    await run(transfers.transferDispatch, { id: own.id }, 'src');
    await run(
      transfers.transferReceive,
      { id: own.id, copies: [{ copyId: 'ACC-000001' }] },
      'dest',
    );
    const closed = await run(
      transfers.transferCloseShort,
      { id: own.id, reason: 'Never arrived' },
      'dest',
    );
    expect(closed.shortfall).toBe(1);
    expect(await get(`libraryTransfers/${own.id}`)).toMatchObject({
      status: 'received',
      closedShort: true,
    });
    expect((await get('libraryCopies/ACC-000002'))?.status).toBe('lost');
  });

  it('request → approve → dispatch → receive moves copies; in-transit copies cannot be issued', async () => {
    const transfer = await request();
    expect((await get(`libraryTransfers/${transfer.id}`))?.status).toBe('requested');
    await expect(run(transfers.transferDispatch, { id: transfer.id }, 'src')).rejects.toThrow(
      /requested/,
    );
    await run(transfers.transferApprove, { id: transfer.id });
    await run(transfers.transferDispatch, { id: transfer.id }, 'src');
    expect((await get('libraryCopies/ACC-000001'))?.status).toBe('in_transit');

    await run(members.policyUpsert, {
      libraryId: mainLibrary,
      memberCategory: 'primary',
      name: 'P',
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
    await expect(
      run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000001' }),
    ).rejects.toThrow(/in_transit/);

    // only the destination campus may receive
    await expect(
      run(
        transfers.transferReceive,
        { id: transfer.id, copies: [{ copyId: 'ACC-000001' }] },
        'src',
      ),
    ).rejects.toThrow(/Campus/);
    const part = await run(
      transfers.transferReceive,
      { id: transfer.id, copies: [{ copyId: 'ACC-000001', condition: 'fair' }] },
      'dest',
    );
    expect(part.status).toBe('partially_received');
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      status: 'available',
      libraryId: secondLibrary,
      campusId: 32,
      condition: 'fair',
    });
    expect((await get('libraryCopies/ACC-000002'))?.status).toBe('in_transit');
    await expect(
      run(
        transfers.transferReceive,
        { id: transfer.id, copies: [{ copyId: 'ACC-000001' }] },
        'dest',
      ),
    ).rejects.toThrow(/already received/);

    const done = await run(
      transfers.transferReceive,
      { id: transfer.id, copies: [{ copyId: 'ACC-000002' }] },
      'dest',
    );
    expect(done.status).toBe('received');
    expect((await get(`libraryTransfers/${transfer.id}`))?.receivedDate).toBeTruthy();
  });

  it('rejects unavailable copies, same library and copies from another library', async () => {
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'damaged', reason: 'torn' });
    await expect(request(['ACC-000001'])).rejects.toThrow(/damaged/);
    await expect(
      run(transfers.transferRequest, {
        fromLibraryId: mainLibrary,
        toLibraryId: mainLibrary,
        copyIds: ['ACC-000002'],
      }),
    ).rejects.toThrow(/differ/);
    await expect(
      run(
        transfers.transferRequest,
        { fromLibraryId: secondLibrary, toLibraryId: mainLibrary, copyIds: ['ACC-000002'] },
        '1',
      ),
    ).rejects.toThrow(/not in the source/);
  });

  it('dispatch fails if a copy left the shelf after approval', async () => {
    const transfer = await request();
    await run(transfers.transferApprove, { id: transfer.id });
    await run(copies.copySetStatus, { id: 'ACC-000002', status: 'under_maintenance', reason: 'x' });
    await expect(run(transfers.transferDispatch, { id: transfer.id })).rejects.toThrow(
      /no longer available/,
    );
    expect((await get('libraryCopies/ACC-000001'))?.status).toBe('available');
  });

  it('received copies serve the destination waiting list first', async () => {
    await run(copies.acquisitionCreate, {
      type: 'purchase',
      catalogueId: title,
      libraryId: secondLibrary,
      quantity: 1,
      price: 500,
    });
    await run(copies.copySetStatus, { id: 'ACC-000004', status: 'damaged', reason: 'x' });
    await run(members.policyUpsert, {
      libraryId: secondLibrary,
      memberCategory: 'primary',
      name: 'P',
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
      personErpId: 502,
      memberCategory: 'primary',
      libraryIds: [secondLibrary],
      start: '2020-01-01',
    });
    await run(reservations.reservationCreate, {
      memberId: 'student_502',
      catalogueId: title,
      libraryId: secondLibrary,
    });

    const transfer = await request(['ACC-000001', 'ACC-000002']);
    await run(transfers.transferApprove, { id: transfer.id });
    await run(transfers.transferDispatch, { id: transfer.id }, 'src');
    await run(
      transfers.transferReceive,
      { id: transfer.id, copies: [{ copyId: 'ACC-000001' }, { copyId: 'ACC-000002' }] },
      'dest',
    );
    expect((await get('libraryCopies/ACC-000001'))?.status).toBe('reserved');
    expect((await get('libraryCopies/ACC-000002'))?.status).toBe('available');
  });

  describe('verification', () => {
    it('lists issued copies apart, flags missing and unexpected, and approves corrections', async () => {
      await run(copies.acquisitionCreate, {
        type: 'purchase',
        catalogueId: title,
        libraryId: secondLibrary,
        quantity: 1,
        price: 500,
      }); // ACC-000004 in L2
      await run(members.policyUpsert, {
        libraryId: mainLibrary,
        memberCategory: 'primary',
        name: 'P',
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
      await run(loans.loanIssue, { memberId: 'student_501', copyId: 'ACC-000003' });

      const session = await run(verification.verificationCreate, { libraryId: mainLibrary });
      expect(await get(`libraryVerifications/${session.id}`)).toMatchObject({
        status: 'counting',
        expected: ['ACC-000001', 'ACC-000002'],
        onLoanCopyIds: ['ACC-000003'],
      });

      await expect(
        run(verification.verificationScan, { id: session.id, accessionNumbers: ['ACC-999999'] }),
      ).rejects.toThrow(/Unknown/);
      await run(verification.verificationScan, {
        id: session.id,
        accessionNumbers: ['ACC-000001', 'ACC-000004'],
      });
      const scan = await run(verification.verificationScan, {
        id: session.id,
        accessionNumbers: ['ACC-000001'],
      }); // repeat is harmless
      expect(scan).toMatchObject({ scanned: 2, unexpected: 1 });

      const sub = await run(verification.verificationSubmit, { id: session.id });
      expect(sub).toMatchObject({ status: 'submitted', missing: 1, unexpected: 1 });
      await expect(
        run(verification.verificationScan, { id: session.id, accessionNumbers: ['ACC-000002'] }),
      ).rejects.toThrow(/submitted/);

      await expect(
        run(verification.verificationApprove, { id: session.id, lost: ['ACC-000001'] }, 'approver'),
      ).rejects.toThrow(/missing/);
      await expect(
        run(verification.verificationApprove, { id: session.id, lost: ['ACC-000002'] }, 'src'),
      ).rejects.toThrow(/Not allowed/);
      await run(
        verification.verificationApprove,
        {
          id: session.id,
          lost: ['ACC-000002'],
          move: ['ACC-000004'],
        },
        'approver',
      );
      expect((await get('libraryCopies/ACC-000002'))?.status).toBe('lost');
      expect(await get('libraryCopies/ACC-000004')).toMatchObject({
        libraryId: mainLibrary,
        campusId: 31,
      });
      expect((await get(`libraryVerifications/${session.id}`))?.status).toBe('approved');
    });

    it('a clean count is approved on submit; missing copies left alone are recorded for investigation', async () => {
      const cleanSession = await run(verification.verificationCreate, { libraryId: mainLibrary });
      await run(verification.verificationScan, {
        id: cleanSession.id,
        accessionNumbers: ['ACC-000001', 'ACC-000002', 'ACC-000003'],
      });
      expect(await run(verification.verificationSubmit, { id: cleanSession.id })).toMatchObject({
        status: 'approved',
      });

      const session = await run(verification.verificationCreate, { libraryId: mainLibrary });
      await run(verification.verificationScan, {
        id: session.id,
        accessionNumbers: ['ACC-000001'],
      });
      await run(verification.verificationSubmit, { id: session.id });
      await run(verification.verificationApprove, { id: session.id }, 'approver');
      expect((await get(`libraryVerifications/${session.id}`))?.investigate).toEqual([
        'ACC-000002',
        'ACC-000003',
      ]);
      expect((await get('libraryCopies/ACC-000002'))?.status).toBe('available');
    });
  });
});
