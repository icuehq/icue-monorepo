import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { orders as o } from '../src/inventory/orders';
import { procurement as p } from '../src/inventory/procurement';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { dayTimestamp } from '../src/shared/dates';
import { seedPurchaseOrder, seedPurchaseRequest } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;

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
  let pen: string, ink: string, firstVendor: string, purchaseRequest: string;
  const purchaseOrder = (
    lines = [{ itemId: pen, quantityOrdered: 60, unitPrice: 5 }],
    options: { discount?: number; tax?: number } = {},
  ) => seedPurchaseOrder(purchaseRequest, firstVendor, lines, options);
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
    purchaseRequest = await seedPurchaseRequest([
      { itemId: pen, quantity: 100, estimatedPrice: 5 },
      { itemId: ink, quantity: 20, estimatedPrice: 10 },
    ]);
  });

  it('PO: issue reserves quantity, cancel releases it', async () => {
    const definition = await purchaseOrder();
    expect(await get(`inventoryPurchaseOrders/${definition}`)).toMatchObject({ status: 'draft' });

    await run(o.purchaseOrderIssue, { id: definition });
    expect((await purchaseRequestLines()).status).toBe('partially_ordered');
    expect((await purchaseRequestLines()).lineItems[0].quantityOrdered).toBe(60);
    expect(await code(run(o.purchaseOrderIssue, { id: definition }))).toBe('failed-precondition');
    // only 40 pens are left on the request
    const tooMany = await purchaseOrder([{ itemId: pen, quantityOrdered: 41, unitPrice: 5 }]);
    expect(await code(run(o.purchaseOrderIssue, { id: tooMany }))).toBe('failed-precondition');

    const rest = await purchaseOrder([
      { itemId: pen, quantityOrdered: 40, unitPrice: 5 },
      { itemId: ink, quantityOrdered: 20, unitPrice: 9 },
    ]);
    await run(o.purchaseOrderIssue, { id: rest });
    expect((await purchaseRequestLines()).status).toBe('ordered');
    await run(o.purchaseOrderCancel, { id: rest, reason: 'wrong vendor' });
    expect(await get(`inventoryPurchaseOrders/${rest}`)).toMatchObject({
      status: 'cancelled',
      cancelReason: 'wrong vendor',
    });
    await run(o.purchaseOrderCancel, { id: definition, reason: 'again' });
    expect((await purchaseRequestLines()).status).toBe('approved');
    expect(await code(run(o.purchaseOrderIssue, { id: definition }))).toBe('failed-precondition');
  });

  it('acknowledge, revise (recorded), close, and campus scope', async () => {
    const id = await purchaseOrder();
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
      expectedDate: dayTimestamp(day(9)),
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
    // The unreceived quantity went back to the request, so it can be ordered again.
    const released = await get(`inventoryPurchaseRequests/${purchaseRequest}`);
    expect(released!.status).toBe('approved');
    expect(
      released!.lineItems.every((line: { quantityOrdered: number }) => line.quantityOrdered === 0),
    ).toBe(true);
    expect(await code(run(o.purchaseOrderCancel, { id, reason: 'x' }))).toBe('failed-precondition');
  });
});
