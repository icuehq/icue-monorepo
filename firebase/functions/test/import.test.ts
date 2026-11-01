import { beforeEach, describe, expect, it } from 'vitest';
import { runImport } from '../src/inventory/import';
import { assets as a } from '../src/inventory/assets';
import { masters } from '../src/inventory/masters';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const imp = (type: string, rows: Record<string, string>[], uid = 'u_1', importId = 'imp_000001') =>
  runImport({ uid, token: { sid: 12, pt: 'staff' } }, { importId, type, rows });
const code = (d: Promise<unknown>) => d.then(() => 'ok', (e) => e.code);

describe('import and RFID', () => {
  beforeEach(async () => {
    await clearFirestore();
    const acc = (perms: string[]) => ({ perms, cmp: [31], all: false, eid: 5 });
    await db().doc(`schools/${SID}/userAccess/u_1`).set(acc(['inv.settings', 'inv.items.manage', 'inv.assets.manage']));
    await db().doc(`schools/${SID}/userAccess/u_none`).set(acc(['inv.stock.view']));
    await run(masters.seedDefaults, {});
  });

  it('imports rows through the single-record rules, reporting bad rows and duplicates; replay is safe', async () => {
    const cats = [{ code: 'GEN', name: 'General' }, { code: 'GEN', name: 'Again' }, { code: 'X', name: '' }];
    const r = await imp('categories', cats);
    expect(r.results.map((x) => x.ok)).toEqual([true, false, false]);
    expect(r.results[1].error).toMatch(/already exists/);
    expect((await imp('categories', cats)).created).toBe(1); // same importId: replayed, no duplicate
    const items = await imp('items', [{ code: 'PEN', name: 'Pen', categoryCode: 'gen', stockUnit: 'pcs', reorderLevel: '5' }, { code: 'BAD', name: 'Bad', categoryCode: 'nope' }], 'u_1', 'imp_000002');
    expect(items.results.map((x) => x.ok)).toEqual([true, false]);
    expect((await db().collection(`schools/${SID}/invItems`).get()).size).toBe(1);
    expect(await code(imp('stores', [{ code: 'S', name: 'S', campusId: '31' }], 'u_none', 'imp_000003'))).toBe('permission-denied');
  });

  it('assigns a unique RFID tag, moves and clears it', async () => {
    const cat = (await run(masters.categoryUpsert, { code: 'C', name: 'C', suggestedTracking: 'qty' })).id;
    const item = (await run(masters.itemUpsert, { code: 'L', name: 'L', categoryId: cat, stockUnit: 'pcs', tracking: 'asset' })).id;
    const store = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 })).id;
    const [x, y] = [(await run(a.register, { itemId: item, storeId: store })).id, (await run(a.register, { itemId: item, storeId: store })).id];
    await run(a.setRfid, { id: x, rfidTag: 'E200AA' });
    expect(await code(run(a.setRfid, { id: y, rfidTag: 'e200aa' }))).toBe('already-exists');
    await run(a.setRfid, { id: x, rfidTag: 'E200BB' });
    await run(a.setRfid, { id: y, rfidTag: 'E200AA' }); // old tag was released
    await run(a.setRfid, { id: y, rfidTag: null });
    expect((await db().doc(`schools/${SID}/invAssets/${y}`).get()).data()!.rfidTag).toBeNull();
  });
});
