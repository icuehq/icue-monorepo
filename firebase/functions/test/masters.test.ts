import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { seedStore } from './fixtures';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
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

const item = { name: 'Blue Pen', stockUnit: 'pcs', tracking: 'quantity' };

describe('inventory masters', () => {
  let category: string;
  let store: string;
  beforeEach(async () => {
    await clearFirestore();
    await db().doc(`${BRANCH}/userAccess/1`).set({});
    store = (await seedStore({ name: 'Main' })).id;
    await db().collection(`${BRANCH}/inventoryUnits`).add({ storeId: store, name: 'pcs' });
    await run(masters.seedDefaults, {});
    category = (
      await run(masters.categoryUpsert, {
        storeId: store,
        name: 'General',
        suggestedTracking: 'quantity',
      })
    ).id;
  });

  const newItem = (extra: Record<string, unknown> = {}) =>
    run(masters.itemUpsert, { ...item, storeId: store, categoryId: category, ...extra });

  it('seeds defaults once', async () => {
    expect(await count('inventoryCategories')).toBe(15);
    expect(await run(masters.seedDefaults, {})).toEqual({ categories: 0 });
  });

  it('keeps categories and units per store', async () => {
    const other = (await seedStore({ name: 'Lab' })).id;
    expect(await run(masters.seedDefaults, {})).toEqual({ categories: 15 });
    await expect(newItem({ storeId: other })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    await expect(
      run(masters.categoryUpsert, {
        storeId: other,
        name: 'Sub',
        parentId: category,
        suggestedTracking: 'quantity',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('keeps subcategories to one level', async () => {
    const sub = await run(masters.categoryUpsert, {
      storeId: store,
      name: 'Sub',
      parentId: category,
      suggestedTracking: 'quantity',
    });
    await expect(
      run(masters.categoryUpsert, {
        storeId: store,
        name: 'SubSub',
        parentId: sub.id,
        suggestedTracking: 'quantity',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('creates items; rejects inactive categories, unknown units', async () => {
    const { id } = await newItem();
    expect(await get(`inventoryItems/${id}`)).toMatchObject({
      status: 'active',
      name: 'Blue Pen',
    });
    await expect(newItem({ stockUnit: 'nope' })).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    await db().doc(`${BRANCH}/inventoryCategories/${category}`).update({ status: 'inactive' });
    await expect(newItem()).rejects.toMatchObject({ code: 'failed-precondition' });
    // existing item may be edited while its category stays the same
    await expect(newItem({ id, name: 'Blue Pen XL' })).resolves.toEqual({ id });
  });

  it('blocks unit/tracking change after stock moved', async () => {
    const { id } = await newItem();
    await run(masters.itemUpsert, {
      id,
      ...item,
      storeId: store,
      categoryId: category,
      tracking: 'batch',
    });
    await db().collection(`${BRANCH}/inventoryMovements`).add({ itemId: id });
    await expect(
      run(masters.itemUpsert, {
        id,
        ...item,
        storeId: store,
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
