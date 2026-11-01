import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { orders as o } from '../src/inventory/orders';
import { procurement as p } from '../src/inventory/procurement';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_proc') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);
const code = (d: Promise<unknown>) => d.then(() => 'ok', (e) => e.code);

describe('quotations and purchase orders', () => {
  let pen: string, ink: string, v1: string, v2: string, pr: string;
  const quote = (vendorId: string, extra: Record<string, unknown> = {}) =>
    run(o.quotationSave, {
      prId: pr, vendorId, validUntil: day(10), final: true, lines: [{ itemId: pen, qty: 100, unitPrice: 4 }, { itemId: ink, qty: 20, unitPrice: 10 }],
      ...extra,
    });
  const po = (extra: Record<string, unknown> = {}) =>
    run(o.poSave, { prId: pr, vendorId: v1, expectedDate: day(7), lines: [{ itemId: pen, qtyOrdered: 60, unitPrice: 5 }], ...extra });
  const prLines = async () => (await get(`invPurchaseRequests/${pr}`))!;

  beforeEach(async () => {
    await clearFirestore();
    const acc = (perms: string[], cmp = [31]) => ({ perms, cmp, all: false, eid: 5 });
    await db().doc(`schools/${SID}/userAccess/u_1`).set(acc(['inv.settings', 'inv.items.manage', 'inv.vendors.manage']));
    await db().doc(`schools/${SID}/userAccess/u_proc`).set(acc(['inv.procure.operate']));
    await db().doc(`schools/${SID}/userAccess/u_far`).set(acc(['inv.procure.operate'], [99]));
    await db().doc(`schools/${SID}/userAccess/u_req`).set(acc(['inv.pr.request']));
    await db().doc(`schools/${SID}/userAccess/u_apr`).set(acc(['inv.pr.approve']));
    await run(masters.seedDefaults, {}, 'u_1');
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'qty' }, 'u_1')).id;
    const item = (c: string) => run(masters.itemUpsert, { code: c, name: c, categoryId: cat, stockUnit: 'pcs', tracking: 'qty' }, 'u_1').then((r) => r.id as string);
    [pen, ink] = [await item('PEN'), await item('INK')];
    v1 = (await run(p.vendorUpsert, { code: 'V1', name: 'Acme' }, 'u_1')).id;
    v2 = (await run(p.vendorUpsert, { code: 'V2', name: 'Bolt' }, 'u_1')).id;
    pr = (await run(p.prSave, {
      campusId: 31, requiredDate: day(7), purpose: 'Term', submit: true, lines: [{ itemId: pen, qty: 100, estPrice: 5 }, { itemId: ink, qty: 20, estPrice: 10 }],
    }, 'u_req')).id;
  });

  it('quotations need an approved request, request lines and valid dates; totals are computed', async () => {
    expect(await code(quote(v1))).toBe('failed-precondition');
    await run(p.prDecide, { id: pr, decision: 'approve' }, 'u_apr');
    const q = await quote(v1, { discount: 40, tax: 20, delivery: 10 });
    expect(q.number).toMatch(/^QT\/\d{4}-\d{2}\/000001$/);
    expect(await get(`invQuotations/${q.id}`)).toMatchObject({ subtotal: 600, total: 590, status: 'final', selected: false, campusId: 31 });
    expect(await code(quote(v1, { lines: [{ itemId: pen, qty: 101, unitPrice: 1 }] }))).toBe('failed-precondition');
    expect(await code(quote(v1, { lines: [{ itemId: 'zz', qty: 1, unitPrice: 1 }] }))).toBe('failed-precondition');
    expect(await code(quote(v1, { validUntil: day(-1) }))).toBe('failed-precondition');
    expect(await code(quote(v1, { discount: 1000 }))).toBe('failed-precondition');
    expect(await code(quote(v1, {}).then(() => run(o.quotationSave, { prId: pr, vendorId: v1, validUntil: day(1), lines: [{ itemId: pen, qty: 1, unitPrice: 1 }] }, 'u_far')))).toBe('permission-denied');
    const d = await quote(v1, { final: false });
    await run(o.quotationSave, { id: d.id, prId: pr, vendorId: v2, validUntil: day(5), lines: [{ itemId: pen, qty: 10, unitPrice: 2 }] });
    expect(await get(`invQuotations/${d.id}`)).toMatchObject({ vendorId: v2, total: 20, status: 'draft' });
    await run(o.quotationSave, { id: d.id, prId: pr, vendorId: v2, validUntil: day(5), final: true, lines: [{ itemId: pen, qty: 10, unitPrice: 2 }] });
    expect(await code(run(o.quotationSave, { id: d.id, prId: pr, vendorId: v2, validUntil: day(5), lines: [{ itemId: pen, qty: 1, unitPrice: 1 }] }))).toBe('failed-precondition');
  });

  it('selection needs a final quotation and a reason, and is single per request', async () => {
    await run(p.prDecide, { id: pr, decision: 'approve' }, 'u_apr');
    const draft = (await quote(v1, { final: false })).id;
    const a = (await quote(v1)).id, b = (await quote(v2)).id;
    expect(await code(run(o.quotationSelect, { id: draft, reason: 'x' }))).toBe('failed-precondition');
    expect(await code(run(o.quotationSelect, { id: a, reason: '' }))).toBe('invalid-argument');
    await run(o.quotationSelect, { id: a, reason: 'cheapest' });
    await run(o.quotationSelect, { id: b, reason: 'faster' });
    expect(await get(`invQuotations/${a}`)).toMatchObject({ selected: false, selectionReason: null });
    expect(await get(`invQuotations/${b}`)).toMatchObject({ selected: true, selectionReason: 'faster' });
    await run(o.poSave, { prId: pr, quotationId: b, expectedDate: day(3), lines: [{ itemId: pen, qtyOrdered: 10 }] });
    expect(await code(run(o.quotationSelect, { id: a, reason: 'switch' }))).toBe('failed-precondition');
  });

  it('PO: quotation prices win, issue reserves quantity, cancel releases it', async () => {
    expect(await code(po())).toBe('failed-precondition');
    await run(p.prDecide, { id: pr, decision: 'approve' }, 'u_apr');
    const q = (await quote(v2)).id;
    expect(await code(po({ quotationId: q }))).toBe('failed-precondition'); // not selected
    await run(o.quotationSelect, { id: q, reason: 'best' });
    const d = await po({ quotationId: q, vendorId: v1, discount: 10, tax: 5 });
    expect(d.number).toMatch(/^PO\/\d{4}-\d{2}\/000001$/);
    expect(await get(`invPurchaseOrders/${d.id}`)).toMatchObject({ vendorId: v2, status: 'draft', subtotal: 240, total: 235, prIds: [pr], lines: [{ unitPrice: 4, qtyOrdered: 60, qtyReceived: 0 }] });
    expect(await code(po({ quotationId: q, lines: [{ itemId: pen, qtyOrdered: 101 }] }))).toBe('failed-precondition');
    expect(await code(po({ vendorId: v1, lines: [{ itemId: pen, qtyOrdered: 1 }, { itemId: pen, qtyOrdered: 1 }] }))).toBe('failed-precondition');
    expect(await code(po({ expectedDate: day(-1) }))).toBe('failed-precondition');

    await run(o.poIssue, { id: d.id });
    expect((await prLines()).status).toBe('partially_ordered');
    expect((await prLines()).lines[0].qtyOrdered).toBe(60);
    expect(await code(run(o.poIssue, { id: d.id }))).toBe('failed-precondition');
    expect(await code(run(o.poSave, { id: d.id, prId: pr, vendorId: v1, expectedDate: day(3), lines: [{ itemId: pen, qtyOrdered: 1 }] }))).toBe('failed-precondition');
    expect(await code(po({ lines: [{ itemId: pen, qtyOrdered: 41 }] }))).toBe('failed-precondition'); // only 40 left

    const rest = await po({ lines: [{ itemId: pen, qtyOrdered: 40 }, { itemId: ink, qtyOrdered: 20, unitPrice: 9 }] });
    await run(o.poIssue, { id: rest.id });
    expect((await prLines()).status).toBe('ordered');
    expect(await code(run(p.prCancel, { id: pr }, 'u_req'))).toBe('failed-precondition');
    await run(o.poCancel, { id: rest.id, reason: 'wrong vendor' });
    expect(await get(`invPurchaseOrders/${rest.id}`)).toMatchObject({ status: 'cancelled', cancelReason: 'wrong vendor' });
    expect((await prLines()).status).toBe('partially_ordered');
    await run(o.poCancel, { id: d.id, reason: 'again' });
    expect((await prLines()).status).toBe('approved');
    expect(await code(run(o.poIssue, { id: d.id }))).toBe('failed-precondition');
  });

  it('acknowledge, revise (recorded), close, and campus scope', async () => {
    await run(p.prDecide, { id: pr, decision: 'approve' }, 'u_apr');
    const id = (await po()).id as string;
    expect(await code(run(o.poAcknowledge, { id }))).toBe('failed-precondition'); // draft
    expect(await code(run(o.poIssue, { id }, 'u_far'))).toBe('permission-denied');
    await run(o.poIssue, { id });
    await run(o.poAcknowledge, { id, vendorRef: 'SO-7' });
    expect(await get(`invPurchaseOrders/${id}`)).toMatchObject({ status: 'acknowledged', ack: { by: 'u_proc', vendorRef: 'SO-7' } });

    expect(await code(run(o.poRevise, { id, reason: '' }))).toBe('invalid-argument');
    expect(await code(run(o.poRevise, { id, reason: 'x', prices: [{ itemId: ink, unitPrice: 1 }] }))).toBe('failed-precondition');
    await run(o.poRevise, { id, reason: 'price agreed', prices: [{ itemId: pen, unitPrice: 4 }], expectedDate: day(9), delivery: 12 });
    expect(await get(`invPurchaseOrders/${id}`)).toMatchObject({ status: 'issued', ack: null, revision: 1, total: 252, expectedDate: day(9) });
    const revs = await db().collection(`schools/${SID}/invPurchaseOrders/${id}/revisions`).get();
    expect(revs.docs[0].data()).toMatchObject({ reason: 'price agreed', changedBy: 'u_proc', snapshot: { total: 300 } });

    expect(await code(run(o.poClose, { id }))).toBe('failed-precondition'); // reason needed
    await run(o.poClose, { id, reason: 'vendor short-shipped' });
    expect(await get(`invPurchaseOrders/${id}`)).toMatchObject({ status: 'closed' });
    expect(await code(run(o.poCancel, { id, reason: 'x' }))).toBe('failed-precondition');
  });
});
