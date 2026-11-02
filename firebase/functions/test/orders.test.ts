import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { orders as o } from '../src/inventory/orders';
import { procurement as p } from '../src/inventory/procurement';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { seedPurchaseRequest, seedQuotation } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = 'proc') =>
  runCallable(
    definition,
    { uid, token: { schoolId: 12, personType: 'staff' } },
    { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data },
  );
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();
const day = (offset: number) =>
  new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);
const code = (promise: Promise<unknown>) =>
  promise.then(
    () => 'ok',
    (error) => error.code,
  );

describe('purchase orders', () => {
  let pen: string, ink: string, firstVendor: string, secondVendor: string, purchaseRequest: string;
  const quote = (vendorId: string, selected = false) =>
    seedQuotation(
      purchaseRequest,
      vendorId,
      [
        { itemId: pen, quantity: 100, unitPrice: 4 },
        { itemId: ink, quantity: 20, unitPrice: 10 },
      ],
      { selected, validUntil: day(10) },
    );
  const purchaseOrder = (extra: Record<string, unknown> = {}) =>
    run(o.purchaseOrderSave, {
      purchaseRequestId: purchaseRequest,
      vendorId: firstVendor,
      expectedDate: day(7),
      lineItems: [{ itemId: pen, quantityOrdered: 60, unitPrice: 5 }],
      ...extra,
    });
  const purchaseRequestLines = async () =>
    (await get(`inventoryPurchaseRequests/${purchaseRequest}`))!;

  beforeEach(async () => {
    await clearFirestore();
    const permissionsList = (permissions: string[], campusIds = [31]) => ({
      permissions,
      campusIds,
      hasAllCampuses: false,
      personErpId: 5,
    });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set(
        permissionsList([
          'inventory.settings',
          'inventory.items.manage',
          'inventory.vendors.manage',
        ]),
      );
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/proc`)
      .set(permissionsList(['inventory.procure.operate']));
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/far`)
      .set(permissionsList(['inventory.procure.operate'], [99]));
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/req`)
      .set(permissionsList(['inventory.purchaseRequest.request']));
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/apr`)
      .set(permissionsList(['inventory.purchaseRequest.approve']));
    await run(masters.seedDefaults, {}, '1');
    const category = (
      await run(
        masters.categoryUpsert,
        { code: 'GEN', name: 'General', suggestedTracking: 'quantity' },
        '1',
      )
    ).id;
    const item = (itemCode: string) =>
      run(
        masters.itemUpsert,
        {
          code: itemCode,
          name: itemCode,
          categoryId: category,
          stockUnit: 'pcs',
          tracking: 'quantity',
        },
        '1',
      ).then((result) => result.id as string);
    [pen, ink] = [await item('PEN'), await item('INK')];
    firstVendor = (await run(p.vendorUpsert, { code: 'V1', name: 'Acme' }, '1')).id;
    secondVendor = (await run(p.vendorUpsert, { code: 'V2', name: 'Bolt' }, '1')).id;
    purchaseRequest = await seedPurchaseRequest([
      { itemId: pen, quantity: 100, estimatedPrice: 5 },
      { itemId: ink, quantity: 20, estimatedPrice: 10 },
    ]);
  });

  it('PO: quotation prices win, issue reserves quantity, cancel releases it', async () => {
    const quotation = await quote(secondVendor);
    expect(await code(purchaseOrder({ quotationId: quotation }))).toBe('failed-precondition'); // not selected
    await db()
      .doc(`schools/${SCHOOL_ID}/inventoryQuotations/${quotation}`)
      .update({ selected: true, selectionReason: 'best' });
    const definition = await purchaseOrder({
      quotationId: quotation,
      vendorId: firstVendor,
      discount: 10,
      tax: 5,
    });
    expect(definition.number).toMatch(/^PO\/\d{4}-\d{2}\/000001$/);
    expect(await get(`inventoryPurchaseOrders/${definition.id}`)).toMatchObject({
      vendorId: secondVendor,
      status: 'draft',
      subtotal: 240,
      total: 235,
      purchaseRequestIds: [purchaseRequest],
      lineItems: [{ unitPrice: 4, quantityOrdered: 60, quantityReceived: 0 }],
    });
    expect(
      await code(
        purchaseOrder({
          quotationId: quotation,
          lineItems: [{ itemId: pen, quantityOrdered: 101 }],
        }),
      ),
    ).toBe('failed-precondition');
    expect(
      await code(
        purchaseOrder({
          vendorId: firstVendor,
          lineItems: [
            { itemId: pen, quantityOrdered: 1 },
            { itemId: pen, quantityOrdered: 1 },
          ],
        }),
      ),
    ).toBe('failed-precondition');
    expect(await code(purchaseOrder({ expectedDate: day(-1) }))).toBe('failed-precondition');

    await run(o.purchaseOrderIssue, { id: definition.id });
    expect((await purchaseRequestLines()).status).toBe('partially_ordered');
    expect((await purchaseRequestLines()).lineItems[0].quantityOrdered).toBe(60);
    expect(await code(run(o.purchaseOrderIssue, { id: definition.id }))).toBe(
      'failed-precondition',
    );
    expect(
      await code(
        run(o.purchaseOrderSave, {
          id: definition.id,
          purchaseRequestId: purchaseRequest,
          vendorId: firstVendor,
          expectedDate: day(3),
          lineItems: [{ itemId: pen, quantityOrdered: 1 }],
        }),
      ),
    ).toBe('failed-precondition');
    expect(await code(purchaseOrder({ lineItems: [{ itemId: pen, quantityOrdered: 41 }] }))).toBe(
      'failed-precondition',
    ); // only 40 left

    const rest = await purchaseOrder({
      lineItems: [
        { itemId: pen, quantityOrdered: 40 },
        { itemId: ink, quantityOrdered: 20, unitPrice: 9 },
      ],
    });
    await run(o.purchaseOrderIssue, { id: rest.id });
    expect((await purchaseRequestLines()).status).toBe('ordered');
    await run(o.purchaseOrderCancel, { id: rest.id, reason: 'wrong vendor' });
    expect(await get(`inventoryPurchaseOrders/${rest.id}`)).toMatchObject({
      status: 'cancelled',
      cancelReason: 'wrong vendor',
    });
    expect((await purchaseRequestLines()).status).toBe('partially_ordered');
    await run(o.purchaseOrderCancel, { id: definition.id, reason: 'again' });
    expect((await purchaseRequestLines()).status).toBe('approved');
    expect(await code(run(o.purchaseOrderIssue, { id: definition.id }))).toBe(
      'failed-precondition',
    );
  });

  it('each order line is checked against its own request line', async () => {
    expect(await code(purchaseOrder({ lineItems: [{ itemId: ink, quantityOrdered: 21 }] }))).toBe(
      'failed-precondition',
    ); // ink asks for 20; pen's 100 must not count
    expect(await code(purchaseOrder({ lineItems: [{ itemId: ink, quantityOrdered: 20 }] }))).toBe(
      'ok',
    );
  });

  it('acknowledge, revise (recorded), close, and campus scope', async () => {
    const id = (await purchaseOrder()).id as string;
    expect(await code(run(o.purchaseOrderAcknowledge, { id }))).toBe('failed-precondition'); // draft
    expect(await code(run(o.purchaseOrderIssue, { id }, 'far'))).toBe('permission-denied');
    await run(o.purchaseOrderIssue, { id });
    await run(o.purchaseOrderAcknowledge, { id, vendorRef: 'SO-7' });
    expect(await get(`inventoryPurchaseOrders/${id}`)).toMatchObject({
      status: 'acknowledged',
      acknowledgement: { performedBy: 'proc', vendorRef: 'SO-7' },
    });

    expect(await code(run(o.purchaseOrderRevise, { id, reason: '' }))).toBe('invalid-argument');
    expect(
      await code(
        run(o.purchaseOrderRevise, { id, reason: 'x', prices: [{ itemId: ink, unitPrice: 1 }] }),
      ),
    ).toBe('failed-precondition');
    await run(o.purchaseOrderRevise, {
      id,
      reason: 'price agreed',
      prices: [{ itemId: pen, unitPrice: 4 }],
      expectedDate: day(9),
      delivery: 12,
    });
    expect(await get(`inventoryPurchaseOrders/${id}`)).toMatchObject({
      status: 'issued',
      acknowledgement: null,
      revision: 1,
      total: 252,
      expectedDate: day(9),
    });
    const revs = await db()
      .collection(`schools/${SCHOOL_ID}/inventoryPurchaseOrders/${id}/revisions`)
      .get();
    expect(revs.docs[0].data()).toMatchObject({
      reason: 'price agreed',
      changedBy: 'proc',
      snapshot: { total: 300 },
    });

    expect(await code(run(o.purchaseOrderClose, { id }))).toBe('failed-precondition'); // reason needed
    await run(o.purchaseOrderClose, { id, reason: 'vendor short-shipped' });
    expect(await get(`inventoryPurchaseOrders/${id}`)).toMatchObject({ status: 'closed' });
    expect(await code(run(o.purchaseOrderCancel, { id, reason: 'x' }))).toBe('failed-precondition');
  });
});
