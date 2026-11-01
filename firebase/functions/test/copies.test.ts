import { beforeEach, describe, expect, it } from 'vitest';
import { copies } from '../src/library/copies';
import { masters } from '../src/library/masters';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const count = async (coll: string) => (await db().collection(`schools/${SID}/${coll}`).get()).size;

describe('library copies and acquisitions', () => {
  let title: string, l1: string, l2: string;
  const buy = (extra: Record<string, unknown> = {}) =>
    run(copies.acquisitionCreate, { type: 'purchase', catalogueId: title, libraryId: l1, qty: 3, price: 250, ...extra });

  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SID}/userAccess/u_1`).set({ perms: ['lib.settings', 'lib.catalogue.manage'], cmp: [31, 32], all: false });
    await db().doc(`schools/${SID}/userAccess/u_2`).set({ perms: ['lib.catalogue.view'], cmp: [31], all: false });
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General' })).id;
    title = (await run(masters.catalogueUpsert, { title: 'Wings of Fire', authors: ['Kalam'], categoryId: cat })).id;
    l1 = (await run(masters.libraryUpsert, { code: 'L1', name: 'Main', campusId: 31 })).id;
    l2 = (await run(masters.libraryUpsert, { code: 'L2', name: 'Junior', campusId: 32 })).id;
  });

  it('acquisition creates one copy per unit with sequential school-wide accession numbers', async () => {
    const a = await buy();
    expect(a.copyIds).toEqual(['ACC-000001', 'ACC-000002', 'ACC-000003']);
    expect(await get('libCopies/ACC-000002')).toMatchObject({ accessionNo: 'ACC-000002', barcode: 'ACC-000002', status: 'available', campusId: 31, price: 250, source: 'purchase', catalogueId: title });
    expect(await get(`libAcquisitions/${a.id}`)).toMatchObject({ qty: 3, copyIds: a.copyIds });
    const b = await buy({ type: 'donation', price: 0, libraryId: l2, qty: 2 });
    expect(b.copyIds).toEqual(['ACC-000004', 'ACC-000005']);
    expect(await count('libCopies')).toBe(5);
    expect(await get('libCopies/ACC-000004')).toMatchObject({ campusId: 32, price: 0 });
  });

  it('acquisition rules: purchase needs a price, permission, campus scope, active title and library', async () => {
    await expect(buy({ price: 0 })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(buy({}, )).resolves.toBeTruthy();
    await expect(run(copies.acquisitionCreate, { type: 'donation', catalogueId: title, libraryId: l1, qty: 1 }, 'u_2')).rejects.toMatchObject({ code: 'permission-denied' });
    await db().doc(`schools/${SID}/userAccess/u_1`).update({ cmp: [32] });
    await expect(buy()).rejects.toMatchObject({ code: 'permission-denied' });
    await db().doc(`schools/${SID}/userAccess/u_1`).update({ cmp: [31, 32] });
    await run(masters.catalogueSetStatus, { id: title, status: 'inactive' });
    await expect(buy()).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(masters.catalogueSetStatus, { id: title, status: 'active' });
    await run(masters.librarySetStatus, { id: l1, status: 'inactive' });
    await expect(buy()).rejects.toMatchObject({ code: 'failed-precondition' });
    expect(await count('libCopies')).toBe(3); // only the one good purchase
  });

  it('update: unique RFID tag, released when cleared', async () => {
    await buy({ qty: 2 });
    await run(copies.copyUpdate, { id: 'ACC-000001', condition: 'fair', shelf: 'A-3', rfidTag: 'E200' });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ condition: 'fair', shelf: 'A-3', rfidTag: 'E200' });
    await expect(run(copies.copyUpdate, { id: 'ACC-000002', condition: 'good', rfidTag: 'e200' })).rejects.toMatchObject({ code: 'already-exists' });
    await run(copies.copyUpdate, { id: 'ACC-000001', condition: 'fair' });
    await expect(run(copies.copyUpdate, { id: 'ACC-000002', condition: 'good', rfidTag: 'E200' })).resolves.toBeTruthy();
  });

  it('move: only available copies, to another active library the user may use', async () => {
    await buy({ qty: 1 });
    await expect(run(copies.copyMove, { id: 'ACC-000001', libraryId: l1 })).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(copies.copyMove, { id: 'ACC-000001', libraryId: l2, shelf: 'J-1' });
    expect(await get('libCopies/ACC-000001')).toMatchObject({ libraryId: l2, campusId: 32, shelf: 'J-1' });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'under_maintenance' });
    await expect(run(copies.copyMove, { id: 'ACC-000001', libraryId: l1 })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('status: reason for damage/loss/withdrawal; lost and withdrawn are final; circulation states are untouchable', async () => {
    await buy({ qty: 3 });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'under_maintenance' });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'available' });
    await expect(run(copies.copySetStatus, { id: 'ACC-000001', status: 'damaged' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'damaged', reason: 'torn' });
    await run(copies.copySetStatus, { id: 'ACC-000001', status: 'withdrawn', reason: 'beyond repair' });
    await expect(run(copies.copySetStatus, { id: 'ACC-000001', status: 'available' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await db().doc(`schools/${SID}/libCopies/ACC-000002`).update({ status: 'issued' });
    await expect(run(copies.copySetStatus, { id: 'ACC-000002', status: 'lost', reason: 'x' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
