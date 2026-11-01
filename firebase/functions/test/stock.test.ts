import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { stock } from '../src/inventory/stock-ops';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
const ADMIN = ['inv.settings', 'inv.items.manage', 'inv.stock.operate'];
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const bal = async (id: string) => (await get(`invBalances/${id}`))!;
const moves = async () => (await db().collection(`schools/${SID}/invMovements`).get()).docs.map((d) => d.data());
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);
const fail = (code: string) => ({ code });

describe('inventory stock', () => {
  let s1: string, s2: string, pen: string, med: string, shirt: string, shirtM: string;
  const rcv = (extra: Record<string, unknown>, storeId = s1) =>
    run(stock.receiptConfirm, { storeId, source: 'opening', ...extra });
  const penIn = (q: number, cost = 10) => rcv({ lines: [{ itemId: pen, qtyAccepted: q, unitCost: cost }] });
  const request = async (qty: number, itemId = pen) =>
    (await run(stock.issueRequestSubmit, { storeId: s1, purpose: 'Class', lines: [{ itemId, qty }] }, 'u_req')).id as string;
  const approved = async (qty: number, itemId = pen) => {
    const id = await request(qty, itemId);
    await run(stock.issueRequestDecide, { id, decision: 'approve' }, 'u_apr');
    return id;
  };
  const recipient = { type: 'staff', erpId: 7 };

  beforeEach(async () => {
    await clearFirestore();
    const acc = (perms: string[]) => ({ perms, cmp: [31], all: false, eid: 5 });
    await db().doc(`schools/${SID}/userAccess/u_1`).set(acc(ADMIN));
    await db().doc(`schools/${SID}/userAccess/u_req`).set(acc(['inv.issue.request']));
    await db().doc(`schools/${SID}/userAccess/u_apr`).set(acc(['inv.issue.approve']));
    await db().doc(`schools/${SID}/userAccess/u_far`).set({ perms: ADMIN, cmp: [99], all: false });
    await run(masters.seedDefaults, {});
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'qty' })).id;
    const mk = (code: string, extra: Record<string, unknown>) =>
      run(masters.itemUpsert, { code, name: code, categoryId: cat, stockUnit: 'pcs', tracking: 'qty', ...extra }).then((r) => r.id as string);
    pen = await mk('PEN', { reorderLevel: 5 });
    med = await mk('MED', { tracking: 'batch' });
    shirt = await mk('SHIRT', { variantAttrs: ['size'] });
    shirtM = (await run(masters.variantUpsert, { itemId: shirt, code: 'SH-M', attrs: { size: 'M' } })).id;
    s1 = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 })).id;
    s2 = (await run(masters.storeUpsert, { code: 'S2', name: 'Branch', campusId: 31 })).id;
  });

  it('receives accepted stock only, with weighted cost, ledger rows and numbering', async () => {
    const r = await rcv({ lines: [{ itemId: pen, qtyAccepted: 10, qtyRejected: 2, unitCost: 10 }] });
    expect(r.number).toMatch(/^GRN\/\d{4}-\d{2}\/000001$/);
    await penIn(10, 20);
    expect(await bal(`${s1}__${pen}__-__-`)).toMatchObject({ qtyAvailable: 20, qtyReceivedTotal: 20, unitCost: 15, value: 300 });
    expect(await moves()).toHaveLength(2);
  });

  it('validates lines: variants, batches, assets, empty, store campus, future date', async () => {
    await expect(rcv({ lines: [{ itemId: shirt, qtyAccepted: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(rcv({ lines: [{ itemId: med, qtyAccepted: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(rcv({ lines: [{ itemId: pen, qtyAccepted: 0 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(rcv({ date: day(2), lines: [{ itemId: pen, qtyAccepted: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.receiptConfirm, { storeId: s1, source: 'other', lines: [{ itemId: pen, qtyAccepted: 1 }] }, 'u_far')).rejects.toMatchObject(fail('permission-denied'));
    await rcv({ lines: [{ itemId: shirt, variantId: shirtM, qtyAccepted: 3 }] });
    expect((await bal(`${s1}__${shirt}__${shirtM}__-`)).qtyAvailable).toBe(3);
  });

  it('issue flow: approval limits, FEFO, no expired stock, partial issue, ledger', async () => {
    const batch = (batchNo: string, expiryDate: string, q: number) => ({ itemId: med, qtyAccepted: q, batchNo, expiryDate });
    await rcv({ lines: [batch('LATE', day(90), 5), batch('SOON', day(10), 5), batch('OLD', day(-1), 5)] });
    const id = await approved(8, med);
    const issue = await run(stock.issueCreate, { issueRequestId: id, recipient, lines: [{ itemId: med, qty: 8 }] });
    expect((await bal(`${s1}__${med}__-__SOON`)).qtyAvailable).toBe(0);
    expect((await bal(`${s1}__${med}__-__LATE`)).qtyAvailable).toBe(2);
    expect((await bal(`${s1}__${med}__-__OLD`)).qtyAvailable).toBe(5);
    expect((await get(`invIssueRequests/${id}`))?.status).toBe('issued');
    expect((await get(`invIssues/${issue.id}`))?.lines).toHaveLength(2);
    // expired batch is never issuable, even when named explicitly
    const again = await approved(1, med);
    await expect(run(stock.issueCreate, { issueRequestId: again, recipient, lines: [{ itemId: med, qty: 1, balanceId: `${s1}__${med}__-__OLD` }] })).rejects.toMatchObject(fail('failed-precondition'));
  });

  it('approval is bounded by stock and by the request; reject needs a reason; partial issue', async () => {
    await penIn(10);
    await expect(request(1, pen)).resolves.toBeTruthy();
    const big = await request(11);
    await expect(run(stock.issueRequestDecide, { id: big, decision: 'approve' }, 'u_apr')).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.issueRequestDecide, { id: big, decision: 'reject' }, 'u_apr')).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.issueRequestDecide, { id: big, decision: 'reject', comment: 'No budget' }, 'u_apr');
    await expect(run(stock.issueRequestDecide, { id: big, decision: 'approve' }, 'u_apr')).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.issueCreate, { issueRequestId: big, recipient, lines: [{ itemId: pen, qty: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));

    const id = await approved(6);
    await run(stock.issueCreate, { issueRequestId: id, recipient, lines: [{ itemId: pen, qty: 4 }] });
    expect((await get(`invIssueRequests/${id}`))?.status).toBe('partially_issued');
    await expect(run(stock.issueCreate, { issueRequestId: id, recipient, lines: [{ itemId: pen, qty: 3 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.issueCreate, { issueRequestId: id, recipient, lines: [{ itemId: pen, qty: 2 }] });
    expect((await get(`invIssueRequests/${id}`))?.status).toBe('issued');
    expect(await bal(`${s1}__${pen}__-__-`)).toMatchObject({ qtyAvailable: 4, qtyIssuedTotal: 6, belowReorder: true });
    // low-stock event queued once
    expect((await db().collection(`schools/${SID}/outbox`).get()).docs.some((d) => d.id.startsWith('lowstock__'))).toBe(true);
  });

  it('only approvers decide; availability is rechecked at issuance', async () => {
    await penIn(5);
    const id = await request(5);
    await expect(run(stock.issueRequestDecide, { id, decision: 'approve' }, 'u_req')).rejects.toMatchObject(fail('permission-denied'));
    await run(stock.issueRequestDecide, { id, decision: 'approve' }, 'u_apr');
    await run(stock.adjustmentCreate, { storeId: s1, itemId: pen, delta: -3, reason: 'missing' });
    await expect(run(stock.issueCreate, { issueRequestId: id, recipient, lines: [{ itemId: pen, qty: 5 }] })).rejects.toMatchObject(fail('failed-precondition'));
  });

  it('returns: usable back to stock, damaged to register, never more than outstanding', async () => {
    await penIn(10);
    const id = await approved(6);
    const issue = await run(stock.issueCreate, { issueRequestId: id, recipient, lines: [{ itemId: pen, qty: 6 }] });
    const balanceId = `${s1}__${pen}__-__-`;
    await expect(run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lines: [{ balanceId, qtyUsable: 7 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lines: [{ balanceId, qtyUsable: 3, qtyDamaged: 1 }] });
    expect(await bal(balanceId)).toMatchObject({ qtyAvailable: 7, qtyDamaged: 1, qtyIssuedTotal: 2 });
    const reg = await db().collection(`schools/${SID}/invUnavailable`).get();
    expect(reg.docs[0].data()).toMatchObject({ qty: 1, bucket: 'damaged', status: 'open' });
    await expect(run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lines: [{ balanceId, qtyUsable: 3 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lines: [{ balanceId, qtyUsable: 2 }] });
    expect((await bal(balanceId)).qtyIssuedTotal).toBe(0);
  });

  it('transfers: dispatch drops source, partial receipt, final records discrepancy', async () => {
    await penIn(10);
    const t = await run(stock.transferRequest, { fromStoreId: s1, toStoreId: s2, lines: [{ itemId: pen, qty: 6 }] });
    await run(stock.transferDispatch, { id: t.id });
    expect((await bal(`${s1}__${pen}__-__-`)).qtyAvailable).toBe(4);
    await expect(run(stock.transferDispatch, { id: t.id })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.transferReceive, { id: t.id, lines: [{ index: 0, qtyReceived: 7 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.transferReceive, { id: t.id, lines: [{ index: 0, qtyReceived: 4 }] });
    expect((await get(`invTransfers/${t.id}`))?.status).toBe('partially_received');
    expect((await bal(`${s2}__${pen}__-__-`)).qtyAvailable).toBe(4);
    await run(stock.transferReceive, { id: t.id, final: true });
    expect(await get(`invTransfers/${t.id}`)).toMatchObject({ status: 'received', lines: [{ qtyReceived: 4, discrepancy: 2 }] });
    await expect(run(stock.transferRequest, { fromStoreId: s1, toStoreId: s1, lines: [{ itemId: pen, qty: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    const big = await run(stock.transferRequest, { fromStoreId: s1, toStoreId: s2, lines: [{ itemId: pen, qty: 50 }] });
    await expect(run(stock.transferDispatch, { id: big.id })).rejects.toMatchObject(fail('failed-precondition'));
  });

  it('adjustments: reasons, never below zero, immutable record with before/after', async () => {
    await penIn(5);
    await expect(run(stock.adjustmentCreate, { storeId: s1, itemId: pen, delta: -6, reason: 'count_correction' })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.adjustmentCreate, { storeId: s1, itemId: pen, delta: 1, reason: 'missing' })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.adjustmentCreate, { storeId: s1, itemId: pen, delta: 1, reason: 'other' })).rejects.toMatchObject(fail('failed-precondition'));
    const a = await run(stock.adjustmentCreate, { storeId: s1, itemId: pen, delta: -2, reason: 'missing' });
    expect(await get(`invAdjustments/${a.id}`)).toMatchObject({ before: 5, delta: -2, after: 3, status: 'completed' });
    await expect(run(stock.adjustmentCreate, { storeId: s2, itemId: pen, delta: -1, reason: 'missing' })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.adjustmentCreate, { storeId: s2, itemId: pen, delta: 2, reason: 'excess' });
    expect((await bal(`${s2}__${pen}__-__-`)).qtyAvailable).toBe(2);
  });

  it('unavailable stock: report, restore, write-off, repair; expired cannot be restored', async () => {
    await penIn(10);
    const key = { storeId: s1, itemId: pen };
    const d = await run(stock.unavailableReport, { ...key, qty: 4, reason: 'damaged', note: 'Wet' });
    expect(await bal(`${s1}__${pen}__-__-`)).toMatchObject({ qtyAvailable: 6, qtyDamaged: 4 });
    await expect(run(stock.unavailableReport, { ...key, qty: 7, reason: 'damaged', note: 'x' })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.unavailableReport, { ...key, qty: 1, reason: 'expired', note: 'x' })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.unavailableResolve, { id: d.id, resolution: 'repair' });
    expect((await get(`invUnavailable/${d.id}`))?.status).toBe('in_repair');
    await run(stock.unavailableResolve, { id: d.id, resolution: 'restore' });
    expect(await bal(`${s1}__${pen}__-__-`)).toMatchObject({ qtyAvailable: 10, qtyDamaged: 0 });
    await expect(run(stock.unavailableResolve, { id: d.id, resolution: 'restore' })).rejects.toMatchObject(fail('failed-precondition'));
    const lost = await run(stock.unavailableReport, { ...key, qty: 2, reason: 'lost', note: 'Missing' });
    expect(await get(`invUnavailable/${lost.id}`)).toMatchObject({ status: 'resolved', resolution: 'write_off' });
    expect((await bal(`${s1}__${pen}__-__-`)).qtyAvailable).toBe(8);

    await rcv({ lines: [{ itemId: med, qtyAccepted: 3, batchNo: 'E1', expiryDate: day(-2) }] });
    const e = await run(stock.unavailableReport, { storeId: s1, itemId: med, batchNo: 'E1', qty: 3, reason: 'expired', note: 'Expired' });
    expect(await bal(`${s1}__${med}__-__E1`)).toMatchObject({ qtyAvailable: 0, qtyExpired: 3 });
    await expect(run(stock.unavailableResolve, { id: e.id, resolution: 'restore' })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.unavailableResolve, { id: e.id, resolution: 'dispose' });
    expect((await bal(`${s1}__${med}__-__E1`)).qtyExpired).toBe(0);
  });

  it('is idempotent: a repeated requestId returns the first result without moving stock twice', async () => {
    const body = { requestId: 'same-request-1', storeId: s1, source: 'opening', lines: [{ itemId: pen, qtyAccepted: 4 }] };
    const call = () => runCallable(stock.receiptConfirm, { uid: 'u_1', token: { sid: 12, pt: 'staff' } }, body);
    const a = await call();
    expect(await call()).toEqual(a);
    expect((await bal(`${s1}__${pen}__-__-`)).qtyAvailable).toBe(4);
  });

  it('acknowledges an issue once', async () => {
    await penIn(3);
    const issue = await run(stock.issueCreate, { issueRequestId: await approved(3), recipient, lines: [{ itemId: pen, qty: 3 }] });
    await run(stock.issueAcknowledge, { id: issue.id });
    await expect(run(stock.issueAcknowledge, { id: issue.id })).rejects.toMatchObject(fail('failed-precondition'));
  });
});
