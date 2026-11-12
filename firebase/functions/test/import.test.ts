import { beforeEach, describe, expect, it } from 'vitest';
import { assets as a } from '../src/inventory/assets';
import { runImport } from '../src/inventory/import';
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
const imp = (type: string, rows: Record<string, string>[], uid = '1', importId = 'imp_000001') =>
  runImport(
    { uid, token: { orgId: 8, zoneId: 147, branchId: 427, personType: 'staff' } },
    { importId, type, rows },
  );
const code = (promise: Promise<unknown>) =>
  promise.then(
    () => 'ok',
    (error) => error.code,
  );

describe('import and RFID', () => {
  beforeEach(async () => {
    await clearFirestore();
    const permissionsList = (permissions: string[]) => ({
      permissions,
      personErpId: 5,
    });
    await db()
      .doc(`${BRANCH}/userAccess/1`)
      .set(
        permissionsList([
          'inventory.settings',
          'inventory.items.manage',
          'inventory.assets.manage',
        ]),
      );
    await db()
      .doc(`${BRANCH}/userAccess/none`)
      .set(permissionsList(['inventory.stock.view']));
    await run(masters.seedDefaults, {});
  });

  it('imports rows through the single-record rules, reporting bad rows and duplicates; replay is safe', async () => {
    const cats = [
      { code: 'GEN', name: 'General' },
      { code: 'GEN', name: 'Again' },
      { code: 'X', name: '' },
    ];
    const result = await imp('categories', cats);
    expect(result.results.map((result) => result.ok)).toEqual([true, false, false]);
    expect(result.results[1].error).toMatch(/already exists/);
    expect((await imp('categories', cats)).created).toBe(1); // same importId: replayed, no duplicate
    const items = await imp(
      'items',
      [
        { code: 'PEN', name: 'Pen', categoryCode: 'gen', stockUnit: 'pcs', reorderLevel: '5' },
        { code: 'BAD', name: 'Bad', categoryCode: 'nope' },
      ],
      '1',
      'imp_000002',
    );
    expect(items.results.map((result) => result.ok)).toEqual([true, false]);
    expect((await db().collection(`${BRANCH}/inventoryItems`).get()).size).toBe(1);
    expect(await code(imp('vendors', [{ code: 'V', name: 'V' }], 'none', 'imp_000003'))).toBe(
      'permission-denied',
    );
  });

  it('assigns a unique RFID tag, moves and clears it', async () => {
    const category = (
      await run(masters.categoryUpsert, { code: 'C', name: 'C', suggestedTracking: 'quantity' })
    ).id;
    const item = (
      await run(masters.itemUpsert, {
        code: 'L',
        name: 'L',
        categoryId: category,
        stockUnit: 'pcs',
        tracking: 'asset',
      })
    ).id;
    const store = (await seedStore({ name: 'Main' })).id;
    const [firstAsset, secondAsset] = [
      (await run(a.register, { itemId: item, storeId: store })).id,
      (await run(a.register, { itemId: item, storeId: store })).id,
    ];
    await run(a.setRfid, { id: firstAsset, rfidTag: 'E200AA' });
    expect(await code(run(a.setRfid, { id: secondAsset, rfidTag: 'e200aa' }))).toBe(
      'already-exists',
    );
    await run(a.setRfid, { id: firstAsset, rfidTag: 'E200BB' });
    await run(a.setRfid, { id: secondAsset, rfidTag: 'E200AA' }); // old tag was released
    await run(a.setRfid, { id: secondAsset, rfidTag: null });
    expect(
      (await db().doc(`${BRANCH}/inventoryAssets/${secondAsset}`).get()).data()!.rfidTag,
    ).toBeNull();
  });
});
