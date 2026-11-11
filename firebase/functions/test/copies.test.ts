import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { seedLibrary, seedLibraryCategory, seedLibraryTitle } from './fixtures';
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

describe('library copies and books', () => {
  let title: string, mainLibrary: string, secondLibrary: string;
  let barcodeSequence = 0;
  const buy = (extra: Record<string, unknown> = {}) => {
    const quantity = (extra.quantity as number | undefined) ?? 3;
    return run(copies.createBook, {
      catalogueId: title,
      libraryId: mainLibrary,
      quantity,
      price: 250,
      barcodes: Array.from(
        { length: quantity },
        () => `ACC-${String(++barcodeSequence).padStart(6, '0')}`,
      ),
      ...extra,
    });
  };

  beforeEach(async () => {
    await clearFirestore();
    barcodeSequence = 0;
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set({
        permissions: [],
        campusIds: [31, 32],
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
    secondLibrary = (await seedLibrary({ name: 'Junior', campusId: 32 })).id;
  });

  it('createBook creates one copy per unit with one copy per barcode, stored under the barcode', async () => {
    const purchase = await buy();
    expect(purchase.barcodes).toEqual(['ACC-000001', 'ACC-000002', 'ACC-000003']);
    expect(await get('libraryCopies/ACC-000002')).toMatchObject({
      barcode: 'ACC-000002',
      status: 'available',
      campusId: 31,
      price: 250,
      catalogueId: title,
    });
    expect(await get(`libraryBooks/${purchase.id}`)).toMatchObject({
      quantity: 3,
      barcodes: purchase.barcodes,
    });
    const donation = await buy({
      price: 0,
      libraryId: secondLibrary,
      quantity: 2,
    });
    expect(donation.barcodes).toEqual(['ACC-000004', 'ACC-000005']);
    expect(await count('libraryCopies')).toBe(5);
    expect(await get('libraryCopies/ACC-000004')).toMatchObject({ campusId: 32, price: 0 });
  });

  it('createBook stores scanned barcodes and rejects wrong counts or repeats', async () => {
    await buy({ quantity: 2, barcodes: ['9780001', '9780002'] });
    expect(await get('libraryCopies/9780002')).toMatchObject({ barcode: '9780002' });
    await expect(buy({ quantity: 2, barcodes: ['1'] })).rejects.toThrow();
    await expect(buy({ quantity: 2, barcodes: ['a', 'A'] })).rejects.toThrow();
    await expect(buy({ quantity: 1, barcodes: ['9780001'] })).rejects.toThrow();
  });

  it('createBook takes per-copy shelf, condition, price and date over the call defaults', async () => {
    const purchase = await buy({
      quantity: 3,
      shelf: 'A-1',
      details: [
        {},
        { shelf: 'B-2', condition: 'poor', price: 100, date: '2024-03-31' },
        { price: 0 },
      ],
    });
    expect(await get('libraryCopies/ACC-000001')).toMatchObject({
      shelf: 'A-1',
      condition: 'good',
      price: 250,
    });
    expect(await get('libraryCopies/ACC-000002')).toMatchObject({
      shelf: 'B-2',
      condition: 'poor',
      price: 100,
    });
    expect(await get('libraryCopies/ACC-000003')).toMatchObject({ price: 0 });
    expect(await get(`libraryBooks/${purchase.id}`)).toMatchObject({ totalPrice: 350 });
    await expect(buy({ quantity: 2, details: [{}] })).rejects.toThrow();
  });

  it('createBook creates up to 200 copies in one call and refuses 201', async () => {
    const barcodes = Array.from({ length: 200 }, (_, index) => `BULK-${index}`);
    const purchase = await buy({ quantity: 200, barcodes });
    expect(purchase.barcodes).toHaveLength(200);
    expect(await count('libraryCopies')).toBe(200);
    await expect(buy({ quantity: 201, barcodes: [...barcodes, 'BULK-200'] })).rejects.toThrow();
    await expect(buy({ quantity: 1, barcodes: ['BULK-137'] })).rejects.toMatchObject({
      code: 'already-exists',
    });
  });

  it('createBook issues LB running barcodes when none are scanned', async () => {
    const first = await buy({ quantity: 2, barcodes: undefined });
    expect(first.barcodes).toEqual(['LB000001', 'LB000002']);
    const next = await buy({ quantity: 1, barcodes: undefined });
    expect(next.barcodes).toEqual(['LB000003']);
    expect((await get('libraryCopies/LB000003'))?.barcode).toBe('LB000003');
    await buy({ quantity: 1 });
    expect((await buy({ quantity: 1, barcodes: undefined })).barcodes).toEqual(['LB000004']);
  });

  it('createBook rejects scanned barcodes in the system LB shape', async () => {
    await expect(buy({ quantity: 1, barcodes: ['LB000123'] })).rejects.toThrow();
    await expect(buy({ quantity: 1, barcodes: ['lb1234567'] })).rejects.toThrow();
    await buy({ quantity: 1, barcodes: ['LB12'] });
  });

  it('createBook rules: campus scope, active title and library', async () => {
    await expect(buy({})).resolves.toBeTruthy();
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .update({ campusIds: [32] });
    await expect(buy()).rejects.toMatchObject({ code: 'permission-denied' });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .update({ campusIds: [31, 32] });
    await db().doc(`schools/${SCHOOL_ID}/libraryCatalogue/${title}`).update({ status: 'inactive' });
    await expect(buy()).rejects.toMatchObject({ code: 'failed-precondition' });
    await db().doc(`schools/${SCHOOL_ID}/libraryCatalogue/${title}`).update({ status: 'active' });
    await db().doc(`schools/${SCHOOL_ID}/libraries/${mainLibrary}`).update({ status: 'inactive' });
    await expect(buy()).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(await count('libraryCopies')).toBe(3); // only the one good purchase
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
