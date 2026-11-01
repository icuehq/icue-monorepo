import { beforeEach, describe, expect, it } from 'vitest';
import { assets as a, maintenance as m } from '../src/inventory/assets';
import { masters } from '../src/inventory/masters';
import { orders as o } from '../src/inventory/orders';
import { procurement as p } from '../src/inventory/procurement';
import { receiving as r } from '../src/inventory/receiving';
import { stock } from '../src/inventory/stock-ops';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_asset') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);
const code = (d: Promise<unknown>) => d.then(() => 'ok', (e) => e.code);
const staff = (erpId: number) => ({ assignee: { type: 'staff', erpId } });

describe('assets and maintenance', () => {
  let laptop: string, ink: string, store: string, asset: string;

  beforeEach(async () => {
    await clearFirestore();
    const acc = (perms: string[], cmp = [31]) => ({ perms, cmp, all: false, eid: 5 });
    await db().doc(`schools/${SID}/userAccess/u_1`).set(acc(['inv.settings', 'inv.items.manage']));
    await db().doc(`schools/${SID}/userAccess/u_asset`).set(acc(['inv.assets.manage']));
    await db().doc(`schools/${SID}/userAccess/u_both`).set(acc(['inv.assets.manage', 'inv.stock.operate']));
    await db().doc(`schools/${SID}/userAccess/u_far`).set(acc(['inv.assets.manage'], [99]));
    await run(masters.seedDefaults, {}, 'u_1');
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'qty' }, 'u_1')).id;
    const item = (c: string, tracking: string) => run(masters.itemUpsert, { code: c, name: c, categoryId: cat, stockUnit: 'pcs', tracking }, 'u_1').then((x) => x.id as string);
    [laptop, ink] = [await item('LAP', 'asset'), await item('INK', 'qty')];
    store = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 }, 'u_1')).id;
    asset = (await run(a.register, { itemId: laptop, storeId: store, serialNo: 'SN1' })).id;
  });

  it('registers with a unique ID; only asset-tracked items, only on the caller\'s campus', async () => {
    const d = (await get(`invAssets/${asset}`))!;
    expect(d).toMatchObject({ assetId: expect.stringMatching(/^AST\/\d{4}-\d{2}\/000001$/), name: 'LAP', status: 'available', campusId: 31, condition: 'new' });
    expect((await run(a.register, { itemId: laptop, storeId: store })).number).toMatch(/000002$/);
    expect(await code(run(a.register, { itemId: ink, storeId: store }))).toBe('failed-precondition');
    expect(await code(run(a.register, { itemId: laptop, storeId: store }, 'u_far'))).toBe('permission-denied');
    expect(await code(run(a.register, { itemId: laptop, storeId: store, warrantyStart: day(0), warrantyEnd: day(-1) }))).toBe('failed-precondition');
  });

  it('registration against a PO is capped at the accepted units and takes vendor and price from the order', async () => {
    await db().doc(`schools/${SID}/userAccess/u_proc`).set({ perms: ['inv.procure.operate', 'inv.pr.request', 'inv.pr.approve', 'inv.stock.operate', 'inv.vendors.manage'], cmp: [31], all: false });
    const v = (await run(p.vendorUpsert, { code: 'V1', name: 'Acme' }, 'u_proc')).id;
    const pr = (await run(p.prSave, { campusId: 31, requiredDate: day(7), purpose: 'IT', submit: true, lines: [{ itemId: laptop, qty: 3, estPrice: 500 }] }, 'u_proc')).id;
    await run(p.prDecide, { id: pr, decision: 'approve' }, 'u_proc');
    const po = (await run(o.poSave, { prId: pr, vendorId: v, expectedDate: day(7), deliveryCampusId: 31, lines: [{ itemId: laptop, qtyOrdered: 3, unitPrice: 450 }] }, 'u_proc')).id;
    await run(o.poIssue, { id: po }, 'u_proc');
    const reg = () => run(a.register, { itemId: laptop, storeId: store, poId: po });
    expect(await code(reg())).toBe('failed-precondition'); // nothing received yet
    await run(r.poReceive, { poId: po, storeId: store, lines: [{ itemId: laptop, qtyAccepted: 2, qtyRejected: 1 }] }, 'u_proc');
    const x = await reg();
    expect(await get(`invAssets/${x.id}`)).toMatchObject({ vendorId: v, price: 450, poId: po });
    await reg();
    expect(await code(reg())).toBe('failed-precondition'); // only 2 accepted
  });

  it('assign, transfer and return keep history; one custodian at a time', async () => {
    const assign = (x: Record<string, unknown> = {}) => run(a.assign, { id: asset, ...staff(7), location: 'Lab 1', expectedReturn: day(30), acknowledged: true, ...x });
    const g1 = (await assign()).assignmentId;
    expect(await get(`invAssets/${asset}`)).toMatchObject({ status: 'assigned', activeAssignmentId: g1, assignedTo: { type: 'staff', erpId: 7 } });
    expect(await get(`invAssetAssignments/${g1}`)).toMatchObject({ personErpId: 7, conditionOut: 'new', returnedAt: null, ack: { at: expect.anything() } });
    expect(await code(assign())).toBe('failed-precondition');
    expect(await code(run(a.assign, { id: asset, ...staff(8) }))).toBe('failed-precondition');

    expect(await code(run(a.transfer, { id: asset, ...staff(7) }))).toBe('failed-precondition'); // same custodian
    const g2 = (await run(a.transfer, { id: asset, assignee: { type: 'department', erpId: 3 }, condition: 'good' })).assignmentId;
    expect(await get(`invAssetAssignments/${g1}`)).toMatchObject({ closedAs: 'transferred', conditionIn: 'good' });
    expect(await get(`invAssetAssignments/${g2}`)).toMatchObject({ transferredFrom: g1, personErpId: null });
    expect((await get(`invAssets/${asset}`))!.activeAssignmentId).toBe(g2);

    expect(await run(a.return, { id: asset, condition: 'damaged' })).toMatchObject({ status: 'damaged' });
    expect(await get(`invAssets/${asset}`)).toMatchObject({ status: 'damaged', activeAssignmentId: null, assignedTo: null, condition: 'damaged' });
    expect(await get(`invAssetAssignments/${g2}`)).toMatchObject({ closedAs: 'returned', conditionIn: 'damaged' });
    expect(await code(run(a.return, { id: asset, condition: 'good' }))).toBe('failed-precondition');
    expect(await code(assign())).toBe('failed-precondition'); // damaged assets are not assignable
    const types = (await db().collection(`schools/${SID}/invAssets/${asset}/history`).get()).docs.map((h) => h.data().type);
    expect(types.sort()).toEqual(['assigned', 'registered', 'returned', 'transferred']);
  });

  it('condition changes, loss while assigned, retire and dispose', async () => {
    await run(a.setCondition, { id: asset, condition: 'fair' });
    expect((await get(`invAssets/${asset}`))!.condition).toBe('fair');
    await run(a.assign, { id: asset, ...staff(7) });
    expect(await code(run(a.setCondition, { id: asset, condition: 'good', status: 'available' }))).toBe('failed-precondition');
    expect(await code(run(a.retire, { id: asset, kind: 'retired', reason: 'old' }))).toBe('failed-precondition');
    const g = (await get(`invAssets/${asset}`))!.activeAssignmentId;
    await run(a.setCondition, { id: asset, condition: 'poor', status: 'lost' });
    expect(await get(`invAssets/${asset}`)).toMatchObject({ status: 'lost', activeAssignmentId: null });
    expect(await get(`invAssetAssignments/${g}`)).toMatchObject({ closedAs: 'lost' });
    await run(a.setCondition, { id: asset, condition: 'good', status: 'available' }); // found again
    await run(a.retire, { id: asset, kind: 'retired', reason: 'end of life' });
    expect(await code(run(a.assign, { id: asset, ...staff(7) }))).toBe('failed-precondition');
    expect(await code(run(a.retire, { id: asset, kind: 'retired', reason: 'again' }))).toBe('failed-precondition');
    await run(a.retire, { id: asset, kind: 'disposed', reason: 'scrapped' });
    expect(await code(run(a.setCondition, { id: asset, condition: 'good' }))).toBe('failed-precondition');
    expect((await get(`invAssets/${asset}`))!.status).toBe('disposed');
  });

  it('maintenance drives the asset status, needs a cost to complete and draws parts from stock', async () => {
    const save = (x: Record<string, unknown> = {}) => run(m.save, { assetId: asset, issue: 'Screen flickers', priority: 'high', ...x });
    const mt = await save();
    expect(mt.number).toMatch(/^MNT\/.*\/000001$/);
    expect(await get(`invAssets/${asset}`)).toMatchObject({ status: 'under_maintenance', activeMaintenanceId: mt.id });
    expect(await code(save())).toBe('failed-precondition'); // one job at a time
    expect(await code(run(a.assign, { id: asset, ...staff(7) }))).toBe('failed-precondition');
    await save({ id: mt.id, priority: 'urgent' });
    expect((await get(`invMaintenance/${mt.id}`))!.priority).toBe('urgent');

    const set = (x: Record<string, unknown>, uid = 'u_asset') => run(m.setStatus, { id: mt.id, ...x }, uid);
    expect(await code(set({ status: 'assigned' }))).toBe('failed-precondition'); // technician
    await set({ status: 'assigned', technician: 'Acme Service' });
    await set({ status: 'in_progress' });
    expect((await get(`invAssets/${asset}`))!.status).toBe('under_repair');

    await run(stock.receiptConfirm, { storeId: store, source: 'opening', lines: [{ itemId: ink, qtyAccepted: 10, unitCost: 4 }] }, 'u_both');
    const parts = [{ itemId: ink, storeId: store, qty: 2 }];
    expect(await code(set({ status: 'waiting_for_parts', parts }))).toBe('failed-precondition'); // no stock access
    await set({ status: 'waiting_for_parts', parts }, 'u_both');
    expect((await get(`invBalances/${store}__${ink}__-__-`))!.qtyAvailable).toBe(8);
    expect((await get(`invMaintenance/${mt.id}`))!.partsUsed).toMatchObject([{ itemId: ink, qty: 2 }]);
    expect((await get(`invAssets/${asset}`))!.status).toBe('under_maintenance');
    expect(await code(set({ status: 'completed' }))).toBe('failed-precondition'); // cost
    await set({ status: 'completed', cost: 0, condition: 'good', nextServiceDate: day(180) });
    expect(await get(`invAssets/${asset}`)).toMatchObject({ status: 'available', activeMaintenanceId: null, condition: 'good', nextServiceDate: day(180) });
    expect(await get(`invMaintenance/${mt.id}`)).toMatchObject({ status: 'completed', cost: 0, completedDate: day(0) });
    expect(await code(set({ status: 'in_progress' }))).toBe('failed-precondition'); // finished jobs stay as they are
  });

  it('cancelling restores the previous status; a repaired damaged asset becomes available', async () => {
    await run(a.assign, { id: asset, ...staff(7) });
    const j1 = await run(m.save, { assetId: asset, issue: 'x', priority: 'low' });
    expect((await get(`invAssets/${asset}`))!.status).toBe('under_maintenance');
    await run(m.setStatus, { id: j1.id, status: 'cancelled' });
    expect(await get(`invAssets/${asset}`)).toMatchObject({ status: 'assigned', activeMaintenanceId: null });
    await run(a.return, { id: asset, condition: 'damaged' });
    const j2 = await run(m.save, { assetId: asset, issue: 'cracked', priority: 'medium' });
    await run(m.setStatus, { id: j2.id, status: 'completed', cost: 1200 });
    expect((await get(`invAssets/${asset}`))!.status).toBe('available');
    expect(await code(run(m.save, { assetId: asset, issue: 'x', priority: 'low' }, 'u_far'))).toBe('permission-denied');
  });
});
