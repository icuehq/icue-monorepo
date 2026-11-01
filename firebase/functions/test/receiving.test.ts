import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { orders as o } from '../src/inventory/orders';
import { procurement as p } from '../src/inventory/procurement';
import { invoices as inv, receiving as r } from '../src/inventory/receiving';
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

describe('goods receiving and invoices', () => {
  let pen: string, ink: string, v1: string, pr: string, po: string, store: string;
  const receive = (lines: Array<Record<string, unknown>>, extra: Record<string, unknown> = {}, uid = 'u_store') =>
    run(r.poReceive, { poId: po, storeId: store, lines, ...extra }, uid);
  const bal = async (item: string) => (await get(`invBalances/${store}__${item}__-__-`))!;

  beforeEach(async () => {
    await clearFirestore();
    const acc = (perms: string[], cmp = [31]) => ({ perms, cmp, all: false, eid: 5 });
    await db().doc(`schools/${SID}/userAccess/u_1`).set(acc(['inv.settings', 'inv.items.manage', 'inv.vendors.manage']));
    await db().doc(`schools/${SID}/userAccess/u_proc`).set(acc(['inv.procure.operate']));
    await db().doc(`schools/${SID}/userAccess/u_far`).set(acc(['inv.procure.operate'], [99]));
    await db().doc(`schools/${SID}/userAccess/u_store`).set(acc(['inv.stock.operate']));
    await db().doc(`schools/${SID}/userAccess/u_req`).set(acc(['inv.pr.request']));
    await db().doc(`schools/${SID}/userAccess/u_apr`).set(acc(['inv.pr.approve']));
    await run(masters.seedDefaults, {}, 'u_1');
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'qty' }, 'u_1')).id;
    const item = (c: string) => run(masters.itemUpsert, { code: c, name: c, categoryId: cat, stockUnit: 'pcs', tracking: 'qty' }, 'u_1').then((x) => x.id as string);
    [pen, ink] = [await item('PEN'), await item('INK')];
    store = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 }, 'u_1')).id;
    v1 = (await run(p.vendorUpsert, { code: 'V1', name: 'Acme' }, 'u_1')).id;
    pr = (await run(p.prSave, {
      campusId: 31, requiredDate: day(7), purpose: 'Term', submit: true, lines: [{ itemId: pen, qty: 100, estPrice: 5 }, { itemId: ink, qty: 20, estPrice: 10 }],
    }, 'u_req')).id;
    await run(p.prDecide, { id: pr, decision: 'approve' }, 'u_apr');
    po = (await run(o.poSave, {
      prId: pr, vendorId: v1, expectedDate: day(7), deliveryCampusId: 31,
      lines: [{ itemId: pen, qtyOrdered: 100, unitPrice: 5 }, { itemId: ink, qtyOrdered: 20, unitPrice: 10 }],
    })).id;
  });

  it('receives in several deliveries, validates quantities and moves the order and request to done', async () => {
    expect(await code(receive([{ itemId: pen, qtyAccepted: 1 }]))).toBe('failed-precondition'); // draft
    await run(o.poIssue, { id: po });
    expect(await code(receive([{ itemId: pen, qtyAccepted: 101 }]))).toBe('failed-precondition');
    expect(await code(receive([{ itemId: pen, qtyAccepted: 0 }]))).toBe('failed-precondition');
    expect(await code(receive([{ itemId: 'zz', qtyAccepted: 1 }]))).toBe('failed-precondition');
    expect(await code(receive([{ itemId: pen, qtyAccepted: 1 }], {}, 'u_far'))).toBe('permission-denied');

    const g1 = await receive([{ itemId: pen, qtyAccepted: 40, qtyRejected: 10, condition: 'dented' }], { deliveryRef: 'DC-1' });
    expect(g1.poStatus).toBe('partially_received');
    expect((await bal(pen)).qtyAvailable).toBe(40);
    expect((await bal(pen)).unitCost).toBe(5);
    expect(await get(`invReceipts/${g1.id}`)).toMatchObject({ source: 'purchase_order', poId: po, reference: 'DC-1', inspection: { result: 'partial' }, lines: [{ qtyReceived: 50, result: 'partial' }] });
    expect(await get(`invPurchaseOrders/${po}`)).toMatchObject({ status: 'partially_received', lines: [{ qtyReceived: 50, qtyAccepted: 40, qtyRejected: 10 }, { qtyReceived: 0 }] });
    expect(await code(receive([{ itemId: pen, qtyAccepted: 51 }]))).toBe('failed-precondition'); // 50 still due
    expect(await code(run(o.poCancel, { id: po, reason: 'x' }))).toBe('failed-precondition');

    const g2 = await receive([{ itemId: pen, qtyAccepted: 50 }, { itemId: ink, qtyAccepted: 0, qtyRejected: 20 }]);
    expect(g2.poStatus).toBe('fully_received');
    expect((await bal(pen)).qtyAvailable).toBe(90);
    expect(await get(`invBalances/${store}__${ink}__-__-`)).toBeUndefined(); // rejected stock never enters the store
    expect((await get(`invPurchaseRequests/${pr}`))!.status).toBe('completed');
    expect(await code(receive([{ itemId: pen, qtyAccepted: 1 }]))).toBe('failed-precondition'); // fully received
  });

  it('batch items need a batch; asset units are counted on the order but never enter stock', async () => {
    await run(o.poIssue, { id: po });
    await run(masters.itemUpsert, { code: 'MILK', name: 'Milk', categoryId: (await get(`invItems/${pen}`))!.categoryId, stockUnit: 'pcs', tracking: 'batch' }, 'u_1');
    await db().doc(`schools/${SID}/invItems/${ink}`).update({ tracking: 'asset' });
    expect(await code(receive([{ itemId: ink, qtyAccepted: 1.5 }]))).toBe('failed-precondition');
    const g = await receive([{ itemId: ink, qtyAccepted: 5, qtyRejected: 1 }]);
    expect(g.poStatus).toBe('partially_received');
    expect(await get(`invBalances/${store}__${ink}__-__-`)).toBeUndefined();
    expect(await get(`invPurchaseOrders/${po}`)).toMatchObject({ lines: [{ qtyReceived: 0 }, { qtyAccepted: 5, qtyRejected: 1 }] });
  });

  it('invoices: traceable to a live order, unique per vendor, payment recorded, cancel frees the number', async () => {
    const save = (x: Record<string, unknown> = {}, uid = 'u_proc') =>
      run(inv.invoiceSave, { poId: po, invoiceNo: 'INV-1', invoiceDate: day(0), subtotal: 1000, tax: 50, discount: 20, ...x }, uid);
    expect(await code(save())).toBe('failed-precondition'); // draft order
    await run(o.poIssue, { id: po });
    const g = (await receive([{ itemId: pen, qtyAccepted: 10 }])).id;
    expect(await code(save({ receiptIds: ['nope'] }))).toBe('failed-precondition');
    expect(await code(save({}, 'u_far'))).toBe('permission-denied');
    expect(await code(save({ discount: 5000 }))).toBe('failed-precondition');
    expect(await code(save({ dueDate: day(-3) }))).toBe('failed-precondition');
    const a = await save({ receiptIds: [g], dueDate: day(10) });
    expect(await get(`invInvoices/${a.id}`)).toMatchObject({ vendorId: v1, total: 1030, outstanding: 1030, paymentStatus: 'unpaid', poNumber: expect.any(String) });
    expect(await code(save())).toBe('already-exists');
    await run(inv.invoiceSave, { id: a.id, poId: po, invoiceNo: 'INV-1', invoiceDate: day(0), subtotal: 2000 });
    expect((await get(`invInvoices/${a.id}`))!.total).toBe(2000);

    expect(await code(run(inv.invoiceSetPayment, { id: a.id, paidAmount: 2001 }))).toBe('failed-precondition');
    await run(inv.invoiceSetPayment, { id: a.id, paidAmount: 500, reference: 'UTR9' });
    expect(await get(`invInvoices/${a.id}`)).toMatchObject({ paymentStatus: 'partially_paid', outstanding: 1500, payment: { reference: 'UTR9' } });
    expect(await code(run(inv.invoiceSave, { id: a.id, poId: po, invoiceNo: 'INV-1', invoiceDate: day(0), subtotal: 1 }))).toBe('failed-precondition');
    expect(await code(run(inv.invoiceCancel, { id: a.id, reason: 'x' }))).toBe('failed-precondition');
    await run(inv.invoiceSetPayment, { id: a.id, paidAmount: 2000 });
    expect((await get(`invInvoices/${a.id}`))!.paymentStatus).toBe('paid');

    const b = await save({ invoiceNo: 'INV-2' });
    await run(inv.invoiceCancel, { id: b.id, reason: 'typo' });
    expect((await get(`invInvoices/${b.id}`))!.paymentStatus).toBe('cancelled');
    expect(await code(run(inv.invoiceSetPayment, { id: b.id, paidAmount: 1 }))).toBe('failed-precondition');
    await save({ invoiceNo: 'INV-2' }); // number reusable
  });
});
