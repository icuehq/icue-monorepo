import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
const ALL = ['inventory.settings', 'inventory.items.manage'];
let requestSequence = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, { uid, token: { schoolId: 12, personType: 'staff' } }, { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();
const count = async (collection: string) => (await db().collection(`schools/${SCHOOL_ID}/${collection}`).get()).size;

const item = { name: 'Blue Pen', code: 'PEN-01', stockUnit: 'pcs', tracking: 'quantity' };

describe('inventory masters', () => {
  let category: string;
  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`schools/${SCHOOL_ID}/userAccess/1`).set({ permissions: ALL, campusIds: [31], hasAllCampuses: false });
    await db().doc(`schools/${SCHOOL_ID}/userAccess/2`).set({ permissions: ['inventory.items.view'], campusIds: [31], hasAllCampuses: false });
    await run(masters.seedDefaults, {});
    category = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'quantity' })).id;
  });

  const newItem = (extra: Record<string, unknown> = {}) =>
    run(masters.itemUpsert, { ...item, categoryId: category, ...extra });

  it('seeds defaults once', async () => {
    expect(await count('inventoryCategories')).toBe(15);
    expect(await count('inventoryUnits')).toBe(12);
    expect(await run(masters.seedDefaults, {})).toEqual({ categories: 0, units: 0 });
  });

  it('requires permission', async () => {
    await expect(run(masters.categoryUpsert, { code: 'X', name: 'X', suggestedTracking: 'quantity' }, '2')).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('keeps category codes unique and immutable, subcategories one level', async () => {
    expect(category).toBe('gen');
    await expect(run(masters.categoryUpsert, { code: 'a/b', name: 'Bad', suggestedTracking: 'quantity' })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(run(masters.categoryUpsert, { code: 'gen', name: 'Dup', suggestedTracking: 'quantity' })).rejects.toMatchObject({ code: 'already-exists' });
    await expect(run(masters.categoryUpsert, { id: category, code: 'NEW', name: 'General', suggestedTracking: 'quantity' })).rejects.toMatchObject({ code: 'failed-precondition' });
    const sub = await run(masters.categoryUpsert, { code: 'SUB', name: 'Sub', parentId: category, suggestedTracking: 'quantity' });
    await expect(run(masters.categoryUpsert, { code: 'SS', name: 'SubSub', parentId: sub.id, suggestedTracking: 'quantity' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('creates items; rejects duplicates, inactive categories, unknown units', async () => {
    const { id } = await newItem();
    expect(await get(`inventoryItems/${id}`)).toMatchObject({ code: 'PEN-01', status: 'active', name: 'Blue Pen' });
    await expect(newItem()).rejects.toMatchObject({ code: 'already-exists' });
    await expect(newItem({ code: 'X1', stockUnit: 'nope' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(masters.categorySetStatus, { id: category, status: 'inactive' });
    await expect(newItem({ code: 'X2' })).rejects.toMatchObject({ code: 'failed-precondition' });
    // existing item may be edited while its category stays the same
    await expect(newItem({ id, code: undefined, name: 'Blue Pen XL' })).resolves.toEqual({ id });
  });

  it('blocks unit/tracking change after stock moved', async () => {
    const { id } = await newItem();
    await run(masters.itemUpsert, { id, ...item, code: undefined, categoryId: category, tracking: 'batch' });
    await db().collection(`schools/${SCHOOL_ID}/inventoryMovements`).add({ itemId: id });
    await expect(run(masters.itemUpsert, { id, ...item, code: undefined, categoryId: category, tracking: 'quantity' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('variants need declared attributes and unique SKUs', async () => {
    const { id } = await newItem({ code: 'SHIRT', variantAttrs: ['size'] });
    await run(masters.variantUpsert, { itemId: id, code: 'SH-M', attrs: { size: 'M' } });
    await expect(run(masters.variantUpsert, { itemId: id, code: 'SH-C', attrs: { color: 'red' } })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(masters.variantUpsert, { itemId: id, code: 'sh-m', attrs: { size: 'L' } })).rejects.toMatchObject({ code: 'already-exists' });
    expect(await count(`inventoryItems/${id}/variants`)).toBe(1);
  });

  it('stores: campus scope enforced, campus fixed after creation', async () => {
    await expect(run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 99 })).rejects.toMatchObject({ code: 'permission-denied' });
    const { id } = await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31, storekeeperIds: [5, 5, 6] });
    expect((await get(`inventoryStores/${id}`))?.storekeeperIds).toEqual([5, 6]);
    await db().doc(`schools/${SCHOOL_ID}/userAccess/1`).update({ campusIds: [31, 32] });
    await expect(run(masters.storeUpsert, { id, name: 'Main', campusId: 32 })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('audits changes', async () => {
    await newItem();
    expect(await count('auditLogs')).toBeGreaterThan(2);
  });
});
