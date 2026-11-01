import { beforeEach, describe, expect, it } from 'vitest';
import { runDailyInventory } from '../src/inventory/daily';
import { masters } from '../src/inventory/masters';
import { stock } from '../src/inventory/stock-ops';
import { verification as v } from '../src/inventory/verification';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const col = async (path: string) => (await db().collection(`schools/${SID}/${path}`).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
const code = (p: Promise<unknown>) => p.then(() => 'ok', (e) => e.code);
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('stock verification and daily job', () => {
  let store: string, pen: string, ink: string, med: string;
  const bid = (item: string, batch = '-') => `${store}__${item}__-__${batch}`;
  const open = async () => (await run(v.create, { storeId: store })) as { id: string };
  const count = (id: string, lines: Array<Record<string, unknown>>) => run(v.count, { id, lines });

  beforeEach(async () => {
    await clearFirestore();
    const acc = (perms: string[], cmp = [31]) => ({ perms, cmp, all: false, eid: 5 });
    await db().doc(`schools/${SID}/userAccess/u_1`).set(acc(['inv.settings', 'inv.items.manage', 'inv.stock.operate']));
    await db().doc(`schools/${SID}/userAccess/u_apr`).set(acc(['inv.adjustment.approve']));
    await db().doc(`schools/${SID}/userAccess/u_far`).set(acc(['inv.stock.operate'], [99]));
    await run(masters.seedDefaults, {});
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'qty' })).id;
    const mk = (c: string, extra: Record<string, unknown> = {}) =>
      run(masters.itemUpsert, { code: c, name: c, categoryId: cat, stockUnit: 'pcs', tracking: 'qty', ...extra }).then((r) => r.id as string);
    [pen, ink, med] = [await mk('PEN'), await mk('INK'), await mk('MED', { tracking: 'batch' })];
    store = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 })).id;
    await run(stock.receiptConfirm, { storeId: store, source: 'opening', lines: [
      { itemId: pen, qtyAccepted: 10, unitCost: 5 }, { itemId: ink, qtyAccepted: 4, unitCost: 20 },
      { itemId: med, qtyAccepted: 6, unitCost: 2, batchNo: 'B1', expiryDate: day(10) },
    ] });
  });

  it('snapshots expected quantities, needs every line counted and every difference explained', async () => {
    const { id } = await open();
    expect((await col(`invVerifications/${id}/lines`)).map((l) => l.expected as number).sort((a, b) => a - b)).toEqual([4, 6, 10]);
    expect(await code(run(v.create, { storeId: store }, 'u_far'))).toBe('permission-denied');
    expect(await code(run(v.submit, { id }))).toBe('failed-precondition'); // nothing counted
    await count(id, [{ balanceId: bid(pen), counted: 8 }, { balanceId: bid(ink), counted: 4 }, { balanceId: bid(med, 'B1'), counted: 6 }]);
    expect(await code(run(v.submit, { id }))).toBe('failed-precondition'); // pen difference has no reason
    await count(id, [{ balanceId: bid(pen), counted: 8, reason: 'excess' }]);
    expect(await code(run(v.submit, { id }))).toBe('failed-precondition'); // reason contradicts direction
    await count(id, [{ balanceId: bid(pen), counted: 8, reason: 'missing' }]);
    expect(await run(v.submit, { id })).toMatchObject({ diffs: 1 });
    expect(await code(count(id, [{ balanceId: bid(pen), counted: 9 }]))).toBe('failed-precondition'); // counting is closed
  });

  it('approval applies differences as adjustments that reference the session; rejection reopens counting', async () => {
    const { id } = await open();
    await count(id, [{ balanceId: bid(pen), counted: 8, reason: 'missing' }, { balanceId: bid(ink), counted: 5, reason: 'excess' }, { balanceId: bid(med, 'B1'), counted: 6 }]);
    await run(v.submit, { id });
    expect(await code(run(v.decide, { id, decision: 'approve' }))).toBe('permission-denied'); // u_1 cannot approve
    await run(v.decide, { id, decision: 'reject', comment: 'Recount pens' }, 'u_apr');
    expect((await get(`invVerifications/${id}`))!.status).toBe('counting');
    await run(v.submit, { id });
    expect(await run(v.decide, { id, decision: 'approve' }, 'u_apr')).toMatchObject({ applied: 2 });
    expect((await get(`invBalances/${bid(pen)}`))!.qtyAvailable).toBe(8);
    expect((await get(`invBalances/${bid(ink)}`))!.qtyAvailable).toBe(5);
    expect(await col('invAdjustments')).toEqual(expect.arrayContaining([expect.objectContaining({ verificationId: id, delta: -2, reason: 'missing', status: 'completed' })]));
    expect((await col('invMovements')).filter((m) => m.refType === 'verification')).toHaveLength(2);
    expect(await get(`invVerifications/${id}`)).toMatchObject({ status: 'applied', adjustmentCount: 2 });
    expect(await code(run(v.decide, { id, decision: 'approve' }, 'u_apr'))).toBe('failed-precondition');
  });

  it('a session without differences closes itself', async () => {
    const { id } = await open();
    await count(id, [{ balanceId: bid(pen), counted: 10 }, { balanceId: bid(ink), counted: 4 }, { balanceId: bid(med, 'B1'), counted: 6 }]);
    expect(await run(v.submit, { id })).toMatchObject({ diffs: 0 });
    expect((await get(`invVerifications/${id}`))!.status).toBe('applied');
  });

  it('daily job moves expired batches once and posts reminders', async () => {
    expect((await get(`invBalances/${bid(med, 'B1')}`))!.expKey).toBe(day(10));
    await runDailyInventory(SID, day(0));
    expect(await col('outbox')).toEqual(expect.arrayContaining([expect.objectContaining({ category: 'inv.expiry', title: 'Stock nearing expiry' })]));
    await runDailyInventory(SID, day(11));
    await runDailyInventory(SID, day(11));
    expect(await get(`invBalances/${bid(med, 'B1')}`)).toMatchObject({ qtyAvailable: 0, qtyExpired: 6, expKey: null });
    expect((await col('invMovements')).filter((m) => m.type === 'expire')).toHaveLength(2);
    expect((await col('invUnavailable')).filter((u) => u.reason === 'expired')).toHaveLength(1);
    expect((await col('outbox')).filter((o) => o.title === 'Stock expired')).toHaveLength(1);
  });

  it('out of stock is announced once when an issue empties a balance', async () => {
    await run(stock.adjustmentCreate, { storeId: store, itemId: ink, delta: -4, reason: 'missing' });
    const out = (await col('outbox')).filter((o) => o.category === 'inv.outOfStock');
    expect(out).toHaveLength(1);
  });
});
