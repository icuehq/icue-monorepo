import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { stock } from '../src/inventory/stock-operations';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
const ADMIN = ['inventory.settings', 'inventory.items.manage', 'inventory.stock.operate'];
let requestSequence = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, { uid, token: { schoolId: 12, personType: 'staff' } }, { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();
const balance = async (id: string) => (await get(`inventoryBalances/${id}`))!;
const moves = async () => (await db().collection(`schools/${SCHOOL_ID}/inventoryMovements`).get()).docs.map((movement) => movement.data());
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);
const fail = (code: string) => ({ code });

describe('inventory stock', () => {
  let firstStore: string, secondStore: string, pen: string, med: string, shirt: string, shirtM: string;
  const rcv = (extra: Record<string, unknown>, storeId = firstStore) =>
    run(stock.receiptConfirm, { storeId, source: 'opening', ...extra });
  const penIn = (quantity: number, cost = 10) => rcv({ lineItems: [{ itemId: pen, quantityAccepted: quantity, unitCost: cost }] });
  const request = async (quantity: number, itemId = pen) =>
    (await run(stock.issueRequestSubmit, { storeId: firstStore, purpose: 'Class', lineItems: [{ itemId, quantity }] }, 'req')).id as string;
  const approved = async (quantity: number, itemId = pen) => {
    const id = await request(quantity, itemId);
    await run(stock.issueRequestDecide, { id, decision: 'approve' }, 'apr');
    return id;
  };
  const recipient = { type: 'staff', personErpId: 7 };

  beforeEach(async () => {
    await clearFirestore();
    const permissionsList = (permissions: string[]) => ({ permissions, campusIds: [31], hasAllCampuses: false, personErpId: 5 });
    await db().doc(`schools/${SCHOOL_ID}/userAccess/1`).set(permissionsList(ADMIN));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/req`).set(permissionsList(['inventory.issue.request']));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/apr`).set(permissionsList(['inventory.issue.approve']));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/far`).set({ permissions: ADMIN, campusIds: [99], hasAllCampuses: false });
    await run(masters.seedDefaults, {});
    const category = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'quantity' })).id;
    const makeItem = (code: string, extra: Record<string, unknown>) =>
      run(masters.itemUpsert, { code, name: code, categoryId: category, stockUnit: 'pcs', tracking: 'quantity', ...extra }).then((result) => result.id as string);
    pen = await makeItem('PEN', { reorderLevel: 5 });
    med = await makeItem('MED', { tracking: 'batch' });
    shirt = await makeItem('SHIRT', { variantAttrs: ['size'] });
    shirtM = (await run(masters.variantUpsert, { itemId: shirt, code: 'SH-M', attrs: { size: 'M' } })).id;
    firstStore = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 })).id;
    secondStore = (await run(masters.storeUpsert, { code: 'S2', name: 'Branch', campusId: 31 })).id;
  });

  it('receives accepted stock only, with weighted cost, ledger rows and numbering', async () => {
    const result = await rcv({ lineItems: [{ itemId: pen, quantityAccepted: 10, quantityRejected: 2, unitCost: 10 }] });
    expect(result.number).toMatch(/^GRN\/\d{4}-\d{2}\/000001$/);
    await penIn(10, 20);
    expect(await balance(`${firstStore}__${pen}__-__-`)).toMatchObject({ quantityAvailable: 20, totalQuantityReceived: 20, unitCost: 15, value: 300 });
    expect(await moves()).toHaveLength(2);
  });

  it('validates lines: variants, batches, assets, empty, store campus, future date', async () => {
    await expect(rcv({ lineItems: [{ itemId: shirt, quantityAccepted: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(rcv({ lineItems: [{ itemId: med, quantityAccepted: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(rcv({ lineItems: [{ itemId: pen, quantityAccepted: 0 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(rcv({ date: day(2), lineItems: [{ itemId: pen, quantityAccepted: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.receiptConfirm, { storeId: firstStore, source: 'other', lineItems: [{ itemId: pen, quantityAccepted: 1 }] }, 'far')).rejects.toMatchObject(fail('permission-denied'));
    await rcv({ lineItems: [{ itemId: shirt, variantId: shirtM, quantityAccepted: 3 }] });
    expect((await balance(`${firstStore}__${shirt}__${shirtM}__-`)).quantityAvailable).toBe(3);
  });

  it('issue flow: approval limits, FEFO, no expired stock, partial issue, ledger', async () => {
    const batch = (batchNumber: string, expiryDate: string, quantity: number) => ({ itemId: med, quantityAccepted: quantity, batchNumber, expiryDate });
    await rcv({ lineItems: [batch('LATE', day(90), 5), batch('SOON', day(10), 5), batch('OLD', day(-1), 5)] });
    const id = await approved(8, med);
    const issue = await run(stock.issueCreate, { issueRequestId: id, recipient, lineItems: [{ itemId: med, quantity: 8 }] });
    expect((await balance(`${firstStore}__${med}__-__SOON`)).quantityAvailable).toBe(0);
    expect((await balance(`${firstStore}__${med}__-__LATE`)).quantityAvailable).toBe(2);
    expect((await balance(`${firstStore}__${med}__-__OLD`)).quantityAvailable).toBe(5);
    expect((await get(`inventoryIssueRequests/${id}`))?.status).toBe('issued');
    expect((await get(`inventoryIssues/${issue.id}`))?.lineItems).toHaveLength(2);
    // expired batch is never issuable, even when named explicitly
    const again = await approved(1, med);
    await expect(run(stock.issueCreate, { issueRequestId: again, recipient, lineItems: [{ itemId: med, quantity: 1, balanceId: `${firstStore}__${med}__-__OLD` }] })).rejects.toMatchObject(fail('failed-precondition'));
  });

  it('approval is bounded by stock and by the request; reject needs a reason; partial issue', async () => {
    await penIn(10);
    await expect(request(1, pen)).resolves.toBeTruthy();
    const big = await request(11);
    await expect(run(stock.issueRequestDecide, { id: big, decision: 'approve' }, 'apr')).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.issueRequestDecide, { id: big, decision: 'reject' }, 'apr')).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.issueRequestDecide, { id: big, decision: 'reject', comment: 'No budget' }, 'apr');
    await expect(run(stock.issueRequestDecide, { id: big, decision: 'approve' }, 'apr')).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.issueCreate, { issueRequestId: big, recipient, lineItems: [{ itemId: pen, quantity: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));

    const id = await approved(6);
    await run(stock.issueCreate, { issueRequestId: id, recipient, lineItems: [{ itemId: pen, quantity: 4 }] });
    expect((await get(`inventoryIssueRequests/${id}`))?.status).toBe('partially_issued');
    await expect(run(stock.issueCreate, { issueRequestId: id, recipient, lineItems: [{ itemId: pen, quantity: 3 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.issueCreate, { issueRequestId: id, recipient, lineItems: [{ itemId: pen, quantity: 2 }] });
    expect((await get(`inventoryIssueRequests/${id}`))?.status).toBe('issued');
    expect(await balance(`${firstStore}__${pen}__-__-`)).toMatchObject({ quantityAvailable: 4, totalQuantityIssued: 6, isBelowReorderLevel: true });
    // low-stock event queued once
    expect((await db().collection(`schools/${SCHOOL_ID}/outbox`).get()).docs.some((outboxDocument) => outboxDocument.id.startsWith('inventory-low-stock__'))).toBe(true);
  });

  it('only approvers decide; availability is rechecked at issuance', async () => {
    await penIn(5);
    const id = await request(5);
    await expect(run(stock.issueRequestDecide, { id, decision: 'approve' }, 'req')).rejects.toMatchObject(fail('permission-denied'));
    await run(stock.issueRequestDecide, { id, decision: 'approve' }, 'apr');
    await run(stock.adjustmentCreate, { storeId: firstStore, itemId: pen, delta: -3, reason: 'missing' });
    await expect(run(stock.issueCreate, { issueRequestId: id, recipient, lineItems: [{ itemId: pen, quantity: 5 }] })).rejects.toMatchObject(fail('failed-precondition'));
  });

  it('returns: usable back to stock, damaged to register, never more than outstanding', async () => {
    await penIn(10);
    const id = await approved(6);
    const issue = await run(stock.issueCreate, { issueRequestId: id, recipient, lineItems: [{ itemId: pen, quantity: 6 }] });
    const balanceId = `${firstStore}__${pen}__-__-`;
    await expect(run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lineItems: [{ balanceId, quantityUsable: 7 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lineItems: [{ balanceId, quantityUsable: 3, quantityDamaged: 1 }] });
    expect(await balance(balanceId)).toMatchObject({ quantityAvailable: 7, quantityDamaged: 1, totalQuantityIssued: 2 });
    const reg = await db().collection(`schools/${SCHOOL_ID}/inventoryUnavailableStock`).get();
    expect(reg.docs[0].data()).toMatchObject({ quantity: 1, bucket: 'damaged', status: 'open' });
    await expect(run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lineItems: [{ balanceId, quantityUsable: 3 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.returnCreate, { issueId: issue.id, returnedBy: recipient, lineItems: [{ balanceId, quantityUsable: 2 }] });
    expect((await balance(balanceId)).totalQuantityIssued).toBe(0);
  });

  it('transfers: dispatch drops source, partial receipt, final records discrepancy', async () => {
    await penIn(10);
    const transfer = await run(stock.transferRequest, { fromStoreId: firstStore, toStoreId: secondStore, lineItems: [{ itemId: pen, quantity: 6 }] });
    await run(stock.transferDispatch, { id: transfer.id });
    expect((await balance(`${firstStore}__${pen}__-__-`)).quantityAvailable).toBe(4);
    await expect(run(stock.transferDispatch, { id: transfer.id })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.transferReceive, { id: transfer.id, lineItems: [{ index: 0, quantityReceived: 7 }] })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.transferReceive, { id: transfer.id, lineItems: [{ index: 0, quantityReceived: 4 }] });
    expect((await get(`inventoryTransfers/${transfer.id}`))?.status).toBe('partially_received');
    expect((await balance(`${secondStore}__${pen}__-__-`)).quantityAvailable).toBe(4);
    await run(stock.transferReceive, { id: transfer.id, final: true });
    expect(await get(`inventoryTransfers/${transfer.id}`)).toMatchObject({ status: 'received', lineItems: [{ quantityReceived: 4, discrepancy: 2 }] });
    await expect(run(stock.transferRequest, { fromStoreId: firstStore, toStoreId: firstStore, lineItems: [{ itemId: pen, quantity: 1 }] })).rejects.toMatchObject(fail('failed-precondition'));
    const big = await run(stock.transferRequest, { fromStoreId: firstStore, toStoreId: secondStore, lineItems: [{ itemId: pen, quantity: 50 }] });
    await expect(run(stock.transferDispatch, { id: big.id })).rejects.toMatchObject(fail('failed-precondition'));
  });

  it('adjustments: reasons, never below zero, immutable record with before/after', async () => {
    await penIn(5);
    await expect(run(stock.adjustmentCreate, { storeId: firstStore, itemId: pen, delta: -6, reason: 'count_correction' })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.adjustmentCreate, { storeId: firstStore, itemId: pen, delta: 1, reason: 'missing' })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.adjustmentCreate, { storeId: firstStore, itemId: pen, delta: 1, reason: 'other' })).rejects.toMatchObject(fail('failed-precondition'));
    const first = await run(stock.adjustmentCreate, { storeId: firstStore, itemId: pen, delta: -2, reason: 'missing' });
    expect(await get(`inventoryAdjustments/${first.id}`)).toMatchObject({ before: 5, delta: -2, after: 3, status: 'completed' });
    await expect(run(stock.adjustmentCreate, { storeId: secondStore, itemId: pen, delta: -1, reason: 'missing' })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.adjustmentCreate, { storeId: secondStore, itemId: pen, delta: 2, reason: 'excess' });
    expect((await balance(`${secondStore}__${pen}__-__-`)).quantityAvailable).toBe(2);
  });

  it('unavailable stock: report, restore, write-off, repair; expired cannot be restored', async () => {
    await penIn(10);
    const key = { storeId: firstStore, itemId: pen };
    const definition = await run(stock.unavailableReport, { ...key, quantity: 4, reason: 'damaged', remarks: 'Wet' });
    expect(await balance(`${firstStore}__${pen}__-__-`)).toMatchObject({ quantityAvailable: 6, quantityDamaged: 4 });
    await expect(run(stock.unavailableReport, { ...key, quantity: 7, reason: 'damaged', remarks: 'x' })).rejects.toMatchObject(fail('failed-precondition'));
    await expect(run(stock.unavailableReport, { ...key, quantity: 1, reason: 'expired', remarks: 'x' })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.unavailableResolve, { id: definition.id, resolution: 'repair' });
    expect((await get(`inventoryUnavailableStock/${definition.id}`))?.status).toBe('in_repair');
    await run(stock.unavailableResolve, { id: definition.id, resolution: 'restore' });
    expect(await balance(`${firstStore}__${pen}__-__-`)).toMatchObject({ quantityAvailable: 10, quantityDamaged: 0 });
    await expect(run(stock.unavailableResolve, { id: definition.id, resolution: 'restore' })).rejects.toMatchObject(fail('failed-precondition'));
    const lost = await run(stock.unavailableReport, { ...key, quantity: 2, reason: 'lost', remarks: 'Missing' });
    expect(await get(`inventoryUnavailableStock/${lost.id}`)).toMatchObject({ status: 'resolved', resolution: 'write_off' });
    expect((await balance(`${firstStore}__${pen}__-__-`)).quantityAvailable).toBe(8);

    await rcv({ lineItems: [{ itemId: med, quantityAccepted: 3, batchNumber: 'E1', expiryDate: day(-2) }] });
    const error = await run(stock.unavailableReport, { storeId: firstStore, itemId: med, batchNumber: 'E1', quantity: 3, reason: 'expired', remarks: 'Expired' });
    expect(await balance(`${firstStore}__${med}__-__E1`)).toMatchObject({ quantityAvailable: 0, quantityExpired: 3 });
    await expect(run(stock.unavailableResolve, { id: error.id, resolution: 'restore' })).rejects.toMatchObject(fail('failed-precondition'));
    await run(stock.unavailableResolve, { id: error.id, resolution: 'dispose' });
    expect((await balance(`${firstStore}__${med}__-__E1`)).quantityExpired).toBe(0);
  });

  it('is idempotent: a repeated requestId returns the first result without moving stock twice', async () => {
    const body = { requestId: 'same-request-1', storeId: firstStore, source: 'opening', lineItems: [{ itemId: pen, quantityAccepted: 4 }] };
    const call = () => runCallable(stock.receiptConfirm, { uid: '1', token: { schoolId: 12, personType: 'staff' } }, body);
    const first = await call();
    expect(await call()).toEqual(first);
    expect((await balance(`${firstStore}__${pen}__-__-`)).quantityAvailable).toBe(4);
  });

  it('acknowledges an issue once', async () => {
    await penIn(3);
    const issue = await run(stock.issueCreate, { issueRequestId: await approved(3), recipient, lineItems: [{ itemId: pen, quantity: 3 }] });
    await run(stock.issueAcknowledge, { id: issue.id });
    await expect(run(stock.issueAcknowledge, { id: issue.id })).rejects.toMatchObject(fail('failed-precondition'));
  });
});
