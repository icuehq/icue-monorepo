import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { orders as o } from '../src/inventory/orders';
import { procurement as p } from '../src/inventory/procurement';
import { receiving as r } from '../src/inventory/receiving';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { seedPurchaseRequest } from './fixtures';
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

describe('goods receiving', () => {
  let pen: string,
    ink: string,
    firstVendor: string,
    purchaseRequest: string,
    purchaseOrder: string,
    store: string;
  const receive = (
    lineItems: Record<string, unknown>[],
    extra: Record<string, unknown> = {},
    uid = 'store',
  ) =>
    run(
      r.purchaseOrderReceive,
      { purchaseOrderId: purchaseOrder, storeId: store, lineItems, ...extra },
      uid,
    );
  const balance = async (item: string) => (await get(`inventoryBalances/${store}__${item}__-__-`))!;

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
      .doc(`schools/${SCHOOL_ID}/userAccess/store`)
      .set(permissionsList(['inventory.stock.operate']));
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
      ).then((extra) => extra.id as string);
    [pen, ink] = [await item('PEN'), await item('INK')];
    store = (await run(masters.storeUpsert, { name: 'Main', campusId: 31 }, '1')).id;
    firstVendor = (await run(p.vendorUpsert, { code: 'V1', name: 'Acme' }, '1')).id;
    purchaseRequest = await seedPurchaseRequest([
      { itemId: pen, quantity: 100, estimatedPrice: 5 },
      { itemId: ink, quantity: 20, estimatedPrice: 10 },
    ]);
    purchaseOrder = (
      await run(o.purchaseOrderSave, {
        purchaseRequestId: purchaseRequest,
        vendorId: firstVendor,
        expectedDate: day(7),
        deliveryCampusId: 31,
        lineItems: [
          { itemId: pen, quantityOrdered: 100, unitPrice: 5 },
          { itemId: ink, quantityOrdered: 20, unitPrice: 10 },
        ],
      })
    ).id;
  });

  it('receives in several deliveries, validates quantities and moves the order and request to done', async () => {
    expect(await code(receive([{ itemId: pen, quantityAccepted: 1 }]))).toBe('failed-precondition'); // draft
    await run(o.purchaseOrderIssue, { id: purchaseOrder });
    expect(await code(receive([{ itemId: pen, quantityAccepted: 101 }]))).toBe(
      'failed-precondition',
    );
    expect(await code(receive([{ itemId: pen, quantityAccepted: 0 }]))).toBe('failed-precondition');
    expect(await code(receive([{ itemId: 'zz', quantityAccepted: 1 }]))).toBe(
      'failed-precondition',
    );
    expect(await code(receive([{ itemId: pen, quantityAccepted: 1 }], {}, 'far'))).toBe(
      'permission-denied',
    );

    const firstReceipt = await receive(
      [{ itemId: pen, quantityAccepted: 40, quantityRejected: 10, condition: 'dented' }],
      { deliveryRef: 'DC-1' },
    );
    expect(firstReceipt.purchaseOrderStatus).toBe('partially_received');
    expect((await balance(pen)).quantityAvailable).toBe(40);
    expect((await balance(pen)).unitCost).toBe(5);
    expect(await get(`inventoryReceipts/${firstReceipt.id}`)).toMatchObject({
      source: 'purchase_order',
      purchaseOrderId: purchaseOrder,
      reference: 'DC-1',
      inspection: { result: 'partial' },
      lineItems: [{ quantityReceived: 50, result: 'partial' }],
    });
    expect(await get(`inventoryPurchaseOrders/${purchaseOrder}`)).toMatchObject({
      status: 'partially_received',
      lineItems: [
        { quantityReceived: 50, quantityAccepted: 40, quantityRejected: 10 },
        { quantityReceived: 0 },
      ],
    });
    expect(await code(receive([{ itemId: pen, quantityAccepted: 61 }]))).toBe(
      'failed-precondition',
    ); // 60 still due: rejected units do not fill the order
    expect(await code(run(o.purchaseOrderCancel, { id: purchaseOrder, reason: 'x' }))).toBe(
      'failed-precondition',
    );

    const secondReceipt = await receive([
      { itemId: pen, quantityAccepted: 60 },
      { itemId: ink, quantityAccepted: 0, quantityRejected: 20 },
    ]);
    expect(secondReceipt.purchaseOrderStatus).toBe('partially_received'); // ink was all rejected, still due
    expect((await balance(pen)).quantityAvailable).toBe(100);
    expect(await get(`inventoryBalances/${store}__${ink}__-__-`)).toBeUndefined(); // rejected stock never enters the store
    const replacement = await receive([{ itemId: ink, quantityAccepted: 20 }]);
    expect(replacement.purchaseOrderStatus).toBe('fully_received');
    expect((await get(`inventoryPurchaseRequests/${purchaseRequest}`))!.status).toBe('completed');
    expect(await code(receive([{ itemId: pen, quantityAccepted: 1 }]))).toBe('failed-precondition'); // fully received
  });

  it('batch items need a batch; asset units are counted on the order but never enter stock', async () => {
    await run(o.purchaseOrderIssue, { id: purchaseOrder });
    await run(
      masters.itemUpsert,
      {
        code: 'MILK',
        name: 'Milk',
        categoryId: (await get(`inventoryItems/${pen}`))!.categoryId,
        stockUnit: 'pcs',
        tracking: 'batch',
      },
      '1',
    );
    await db().doc(`schools/${SCHOOL_ID}/inventoryItems/${ink}`).update({ tracking: 'asset' });
    expect(await code(receive([{ itemId: ink, quantityAccepted: 1.5 }]))).toBe(
      'failed-precondition',
    );
    const receipt = await receive([{ itemId: ink, quantityAccepted: 5, quantityRejected: 1 }]);
    expect(receipt.purchaseOrderStatus).toBe('partially_received');
    expect(await get(`inventoryBalances/${store}__${ink}__-__-`)).toBeUndefined();
    expect(await get(`inventoryPurchaseOrders/${purchaseOrder}`)).toMatchObject({
      lineItems: [{ quantityReceived: 0 }, { quantityAccepted: 5, quantityRejected: 1 }],
    });
  });
});
