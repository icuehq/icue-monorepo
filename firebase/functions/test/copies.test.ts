import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { masters } from '../src/library/masters';
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
const count = async (collection: string) =>
  (await db().collection(`schools/${SCHOOL_ID}/${collection}`).get()).size;

describe('library copies and acquisitions', () => {
  let title: string, mainLibrary: string, secondLibrary: string;
  const buy = (extra: Record<string, unknown> = {}) =>
    run(copies.acquisitionCreate, {
      type: 'purchase',
      catalogueId: title,
      libraryId: mainLibrary,
      quantity: 3,
      price: 250,
      ...extra,
    });

  beforeEach(async () => {
    await clearFirestore();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: ['library.settings', 'library.catalogue.manage'],
        campusIds: [31, 32],
        hasAllCampuses: false,
      });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/2`)
      .set({ permissions: ['library.catalogue.view'], campusIds: [31], hasAllCampuses: false });
    const category = (await seedLibraryCategory({ code: 'GEN', name: 'General' })).id;
    title = (
      await run(masters.catalogueUpsert, {
        title: 'Wings of Fire',
        authors: ['Kalam'],
        categoryId: category,
      })
    ).id;
    mainLibrary = (await seedLibrary({ code: 'L1', name: 'Main', campusId: 31 })).id;
    secondLibrary = (await seedLibrary({ code: 'L2', name: 'Junior', campusId: 32 })).id;
  });

  it('acquisition creates one copy per unit with sequential school-wide accession numbers', async () => {
    const purchase = await buy();
    expect(purchase.copyIds).toEqual(['ACC-000001', 'ACC-000002', 'ACC-000003']);
    expect(await get('libraryCopies/ACC-000002')).toMatchObject({
      accessionNumber: 'ACC-000002',
      barcode: 'ACC-000002',
      status: 'available',
      campusId: 31,
      price: 250,
      source: 'purchase',
      catalogueId: title,
    });
    expect(await get(`libraryAcquisitions/${purchase.id}`)).toMatchObject({
      quantity: 3,
      copyIds: purchase.copyIds,
    });
    const donation = await buy({
      type: 'donation',
      price: 0,
      libraryId: secondLibrary,
      quantity: 2,
    });
    expect(donation.copyIds).toEqual(['ACC-000004', 'ACC-000005']);
    expect(await count('libraryCopies')).toBe(5);
    expect(await get('libraryCopies/ACC-000004')).toMatchObject({ campusId: 32, price: 0 });
  });

  it('acquisition rules: purchase needs a price, permission, campus scope, active title and library', async () => {
    await expect(buy({ price: 0 })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(buy({})).resolves.toBeTruthy();
    await expect(
      run(
        copies.acquisitionCreate,
        { type: 'donation', catalogueId: title, libraryId: mainLibrary, quantity: 1 },
        '2',
      ),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .update({ campusIds: [32] });
    await expect(buy()).rejects.toMatchObject({ code: 'permission-denied' });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .update({ campusIds: [31, 32] });
    await run(masters.catalogueSetStatus, { id: title, status: 'inactive' });
    await expect(buy()).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(masters.catalogueSetStatus, { id: title, status: 'active' });
    await db().doc(`schools/${SCHOOL_ID}/libraries/${mainLibrary}`).update({ status: 'inactive' });
    await expect(buy()).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(await count('libraryCopies')).toBe(3); // only the one good purchase
  });

  it('update: unique RFID tag, released when cleared', async () => {
    await buy({ quantity: 2 });
    await run(copies.copyUpdate, {
      id: 'ACC-000001',
      condition: 'fair',
      shelf: 'A-3',
      rfidTag: 'E200',
    });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      condition: 'fair',
      shelf: 'A-3',
      rfidTag: 'E200',
    });
    await expect(
      run(copies.copyUpdate, { id: 'ACC-000002', condition: 'good', rfidTag: 'e200' }),
    ).rejects.toMatchObject({ code: 'already-exists' });
    await run(copies.copyUpdate, { id: 'ACC-000001', condition: 'fair' });
    await expect(
      run(copies.copyUpdate, { id: 'ACC-000002', condition: 'good', rfidTag: 'E200' }),
    ).resolves.toBeTruthy();
  });

  it('move: only available copies, to another active library the user may use', async () => {
    await buy({ quantity: 1 });
    await expect(
      run(copies.copyMove, { id: 'ACC-000001', libraryId: mainLibrary }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(copies.copyMove, { id: 'ACC-000001', libraryId: secondLibrary, shelf: 'J-1' });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      libraryId: secondLibrary,
      campusId: 32,
      shelf: 'J-1',
    });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'under_maintenance' });
    await expect(
      run(copies.copyMove, { id: 'ACC-000001', libraryId: mainLibrary }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('status: reason for damage/loss/withdrawal; lost and withdrawn are final; circulation states are untouchable', async () => {
    await buy({ quantity: 3 });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'under_maintenance' });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'available' });
    await expect(
      run(copies.copySetStatus, { id: 'ACC-000001', status: 'damaged' }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'damaged', reason: 'torn' });
    await run(copies.copySetStatus, {
      id: 'ACC-000001',
      status: 'withdrawn',
      reason: 'beyond repair',
    });
    await expect(
      run(copies.copySetStatus, { id: 'ACC-000001', status: 'available' }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    await db().doc(`schools/${SCHOOL_ID}/libraryCopies/ACC-000002`).update({ status: 'issued' });
    await expect(
      run(copies.copySetStatus, { id: 'ACC-000002', status: 'lost', reason: 'x' }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
