import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const ALL = ['inventory.settings', 'inventory.items.manage'];
let requestSequence = 0;

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(
    definition,
    { uid, token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } },
    { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data },
  );
const get = async (path: string) => (await db().doc(`${BRANCH}/${path}`).get()).data();
const count = async (collection: string) =>
  (await db().collection(`${BRANCH}/${collection}`).get()).size;

const item = { name: 'Blue Pen', code: 'PEN-01', stockUnit: 'pcs', tracking: 'quantity' };

describe('inventory masters', () => {
  let category: string;
  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`${BRANCH}/userAccess/1`).set({ permissions: ALL });
    await db()
      .doc(`${BRANCH}/userAccess/2`)
      .set({ permissions: ['inventory.items.view'] });
    await run(masters.seedDefaults, {});
    category = (
      await run(masters.categoryUpsert, {
        code: 'GEN',
        name: 'General',
        suggestedTracking: 'quantity',
      })
    ).id;
  });

  const newItem = (extra: Record<string, unknown> = {}) =>
    run(masters.itemUpsert, { ...item, categoryId: category, ...extra });

  it('seeds defaults once', async () => {
    expect(await count('inventoryCategories')).toBe(15);
    expect(await count('inventoryUnits')).toBe(12);
    expect(await run(masters.seedDefaults, {})).toEqual({ categories: 0, units: 0 });
  });

  it('requires permission', async () => {
    await expect(
      run(masters.categoryUpsert, { code: 'X', name: 'X', suggestedTracking: 'quantity' }, '2'),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('keeps category codes unique and immutable, subcategories one level', async () => {
    expect(category).toBe('gen');
    await expect(
      run(masters.categoryUpsert, { code: 'a/b', name: 'Bad', suggestedTracking: 'quantity' }),
    ).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(
      run(masters.categoryUpsert, { code: 'gen', name: 'Dup', suggestedTracking: 'quantity' }),
    ).rejects.toMatchObject({ code: 'already-exists' });
    await expect(
      run(masters.categoryUpsert, {
        id: category,
        code: 'NEW',
        name: 'General',
        suggestedTracking: 'quantity',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
    const sub = await run(masters.categoryUpsert, {
      code: 'SUB',
      name: 'Sub',
      parentId: category,
      suggestedTracking: 'quantity',
    });
    await expect(
      run(masters.categoryUpsert, {
        code: 'SS',
        name: 'SubSub',
        parentId: sub.id,
        suggestedTracking: 'quantity',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('creates items; rejects duplicates, inactive categories, unknown units', async () => {
    const { id } = await newItem();
    expect(await get(`inventoryItems/${id}`)).toMatchObject({
      code: 'PEN-01',
      status: 'active',
      name: 'Blue Pen',
    });
    await expect(newItem()).rejects.toMatchObject({ code: 'already-exists' });
    await expect(newItem({ code: 'X1', stockUnit: 'nope' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    await db().doc(`${BRANCH}/inventoryCategories/${category}`).update({ status: 'inactive' });
    await expect(newItem({ code: 'X2' })).rejects.toMatchObject({ code: 'failed-precondition' });
    // existing item may be edited while its category stays the same
    await expect(newItem({ id, code: undefined, name: 'Blue Pen XL' })).resolves.toEqual({ id });
  });

  it('blocks unit/tracking change after stock moved', async () => {
    const { id } = await newItem();
    await run(masters.itemUpsert, {
      id,
      ...item,
      code: undefined,
      categoryId: category,
      tracking: 'batch',
    });
    await db().collection(`${BRANCH}/inventoryMovements`).add({ itemId: id });
    await expect(
      run(masters.itemUpsert, {
        id,
        ...item,
        code: undefined,
        categoryId: category,
        tracking: 'quantity',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('audits changes', async () => {
    await newItem();
    expect(await count('auditLogs')).toBeGreaterThan(2);
  });
});
