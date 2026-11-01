import { beforeEach, describe, expect, it } from 'vitest';
import { runImport } from '../src/inventory/import';
import { assets as a } from '../src/inventory/assets';
import { masters } from '../src/inventory/masters';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, { uid, token: { schoolId: 12, personType: 'staff' } }, { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data });
const imp = (type: string, rows: Record<string, string>[], uid = '1', importId = 'imp_000001') =>
  runImport({ uid, token: { schoolId: 12, personType: 'staff' } }, { importId, type, rows });
const code = (promise: Promise<unknown>) => promise.then(() => 'ok', (error) => error.code);

describe('import and RFID', () => {
  beforeEach(async () => {
    await clearFirestore();
    const permissionsList = (permissions: string[]) => ({ permissions, campusIds: [31], hasAllCampuses: false, personErpId: 5 });
    await db().doc(`schools/${SCHOOL_ID}/userAccess/1`).set(permissionsList(['inventory.settings', 'inventory.items.manage', 'inventory.assets.manage']));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/none`).set(permissionsList(['inventory.stock.view']));
    await run(masters.seedDefaults, {});
  });

  it('imports rows through the single-record rules, reporting bad rows and duplicates; replay is safe', async () => {
    const cats = [{ code: 'GEN', name: 'General' }, { code: 'GEN', name: 'Again' }, { code: 'X', name: '' }];
    const result = await imp('categories', cats);
    expect(result.results.map((result) => result.ok)).toEqual([true, false, false]);
    expect(result.results[1].error).toMatch(/already exists/);
    expect((await imp('categories', cats)).created).toBe(1); // same importId: replayed, no duplicate
    const items = await imp('items', [{ code: 'PEN', name: 'Pen', categoryCode: 'gen', stockUnit: 'pcs', reorderLevel: '5' }, { code: 'BAD', name: 'Bad', categoryCode: 'nope' }], '1', 'imp_000002');
    expect(items.results.map((result) => result.ok)).toEqual([true, false]);
    expect((await db().collection(`schools/${SCHOOL_ID}/inventoryItems`).get()).size).toBe(1);
    expect(await code(imp('stores', [{ code: 'S', name: 'S', campusId: '31' }], 'none', 'imp_000003'))).toBe('permission-denied');
  });

  it('assigns a unique RFID tag, moves and clears it', async () => {
    const category = (await run(masters.categoryUpsert, { code: 'C', name: 'C', suggestedTracking: 'quantity' })).id;
    const item = (await run(masters.itemUpsert, { code: 'L', name: 'L', categoryId: category, stockUnit: 'pcs', tracking: 'asset' })).id;
    const store = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 })).id;
    const [firstAsset, secondAsset] = [(await run(a.register, { itemId: item, storeId: store })).id, (await run(a.register, { itemId: item, storeId: store })).id];
    await run(a.setRfid, { id: firstAsset, rfidTag: 'E200AA' });
    expect(await code(run(a.setRfid, { id: secondAsset, rfidTag: 'e200aa' }))).toBe('already-exists');
    await run(a.setRfid, { id: firstAsset, rfidTag: 'E200BB' });
    await run(a.setRfid, { id: secondAsset, rfidTag: 'E200AA' }); // old tag was released
    await run(a.setRfid, { id: secondAsset, rfidTag: null });
    expect((await db().doc(`schools/${SCHOOL_ID}/inventoryAssets/${secondAsset}`).get()).data()!.rfidTag).toBeNull();
  });
});
