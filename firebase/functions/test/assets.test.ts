import { beforeEach, describe, expect, it } from 'vitest';
import { assets as a, maintenance as m } from '../src/inventory/assets';
import { masters } from '../src/inventory/masters';
import { orders as o } from '../src/inventory/orders';
import { procurement as p } from '../src/inventory/procurement';
import { receiving as r } from '../src/inventory/receiving';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { receiveStock, seedPurchaseRequest } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;
 
const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = 'asset') =>
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
const staff = (personErpId: number) => ({ assignee: { type: 'staff', personErpId } });

describe('assets and maintenance', () => {
  let laptop: string, ink: string, store: string, asset: string;

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
      .set(permissionsList(['inventory.settings', 'inventory.items.manage']));
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/asset`)
      .set(permissionsList(['inventory.assets.manage']));
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/both`)
      .set(permissionsList(['inventory.assets.manage', 'inventory.stock.operate']));
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/far`)
      .set(permissionsList(['inventory.assets.manage'], [99]));
    await run(masters.seedDefaults, {}, '1');
    const category = (
      await run(
        masters.categoryUpsert,
        { code: 'GEN', name: 'General', suggestedTracking: 'quantity' },
        '1',
      )
    ).id;
    const item = (itemCode: string, tracking: string) =>
      run(
        masters.itemUpsert,
        { code: itemCode, name: itemCode, categoryId: category, stockUnit: 'pcs', tracking },
        '1',
      ).then((extra) => extra.id as string);
    [laptop, ink] = [await item('LAP', 'asset'), await item('INK', 'quantity')];
    store = (await run(masters.storeUpsert, { code: 'S1', name: 'Main', campusId: 31 }, '1')).id;
    asset = (await run(a.register, { itemId: laptop, storeId: store, serialNumber: 'SN1' })).id;
  });

  it("registers with a unique ID; only asset-tracked items, only on the caller's campus", async () => {
    const assetDocument = (await get(`inventoryAssets/${asset}`))!;
    expect(assetDocument).toMatchObject({
      assetId: expect.stringMatching(/^AST\/\d{4}-\d{2}\/000001$/),
      name: 'LAP',
      status: 'available',
      campusId: 31,
      condition: 'new',
    });
    expect((await run(a.register, { itemId: laptop, storeId: store })).number).toMatch(/000002$/);
    expect(await code(run(a.register, { itemId: ink, storeId: store }))).toBe(
      'failed-precondition',
    );
    expect(await code(run(a.register, { itemId: laptop, storeId: store }, 'far'))).toBe(
      'permission-denied',
    );
    expect(
      await code(
        run(a.register, {
          itemId: laptop,
          storeId: store,
          warrantyStart: day(0),
          warrantyEnd: day(-1),
        }),
      ),
    ).toBe('failed-precondition');
  });

  it('registration against a PO is capped at the accepted units and takes vendor and price from the order', async () => {
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/proc`)
      .set({
        permissions: [
          'inventory.procure.operate',
          'inventory.purchaseRequest.request',
          'inventory.purchaseRequest.approve',
          'inventory.stock.operate',
          'inventory.vendors.manage',
        ],
        campusIds: [31],
        hasAllCampuses: false,
      });
    const vendor = (await run(p.vendorUpsert, { code: 'V1', name: 'Acme' }, 'proc')).id;
    const purchaseRequest = await seedPurchaseRequest([
      { itemId: laptop, quantity: 3, estimatedPrice: 500 },
    ]);
    const purchaseOrder = (
      await run(
        o.purchaseOrderSave,
        {
          purchaseRequestId: purchaseRequest,
          vendorId: vendor,
          expectedDate: day(7),
          deliveryCampusId: 31,
          lineItems: [{ itemId: laptop, quantityOrdered: 3, unitPrice: 450 }],
        },
        'proc',
      )
    ).id;
    await run(o.purchaseOrderIssue, { id: purchaseOrder }, 'proc');
    const reg = () =>
      run(a.register, { itemId: laptop, storeId: store, purchaseOrderId: purchaseOrder });
    expect(await code(reg())).toBe('failed-precondition'); // nothing received yet
    await run(
      r.purchaseOrderReceive,
      {
        purchaseOrderId: purchaseOrder,
        storeId: store,
        lineItems: [{ itemId: laptop, quantityAccepted: 2, quantityRejected: 1 }],
      },
      'proc',
    );
    const assetDocument = await reg();
    expect(await get(`inventoryAssets/${assetDocument.id}`)).toMatchObject({
      vendorId: vendor,
      price: 450,
      purchaseOrderId: purchaseOrder,
    });
    await reg();
    expect(await code(reg())).toBe('failed-precondition'); // only 2 accepted
  });

  it('assign, transfer and return keep history; one custodian at a time', async () => {
    const assign = (overrides: Record<string, unknown> = {}) =>
      run(a.assign, {
        id: asset,
        ...staff(7),
        location: 'Lab 1',
        expectedReturn: day(30),
        acknowledged: true,
        ...overrides,
      });
    const firstAssignmentId = (await assign()).assignmentId;
    expect(await get(`inventoryAssets/${asset}`)).toMatchObject({
      status: 'assigned',
      activeAssignmentId: firstAssignmentId,
      assignedTo: { type: 'staff', personErpId: 7 },
    });
    expect(await get(`inventoryAssetAssignments/${firstAssignmentId}`)).toMatchObject({
      personErpId: 7,
      conditionOut: 'new',
      returnedAt: null,
      acknowledgement: { performedAt: expect.anything() },
    });
    expect(await code(assign())).toBe('failed-precondition');
    expect(await code(run(a.assign, { id: asset, ...staff(8) }))).toBe('failed-precondition');

    expect(await code(run(a.transfer, { id: asset, ...staff(7) }))).toBe('failed-precondition'); // same custodian
    const secondAssignmentId = (
      await run(a.transfer, {
        id: asset,
        assignee: { type: 'department', personErpId: 3 },
        condition: 'good',
      })
    ).assignmentId;
    expect(await get(`inventoryAssetAssignments/${firstAssignmentId}`)).toMatchObject({
      closedAs: 'transferred',
      conditionIn: 'good',
    });
    expect(await get(`inventoryAssetAssignments/${secondAssignmentId}`)).toMatchObject({
      transferredFrom: firstAssignmentId,
      personErpId: null,
    });
    expect((await get(`inventoryAssets/${asset}`))!.activeAssignmentId).toBe(secondAssignmentId);

    expect(await run(a.return, { id: asset, condition: 'damaged' })).toMatchObject({
      status: 'damaged',
    });
    expect(await get(`inventoryAssets/${asset}`)).toMatchObject({
      status: 'damaged',
      activeAssignmentId: null,
      assignedTo: null,
      condition: 'damaged',
    });
    expect(await get(`inventoryAssetAssignments/${secondAssignmentId}`)).toMatchObject({
      closedAs: 'returned',
      conditionIn: 'damaged',
    });
    expect(await code(run(a.return, { id: asset, condition: 'good' }))).toBe('failed-precondition');
    expect(await code(assign())).toBe('failed-precondition'); // damaged assets are not assignable
    const types = (
      await db().collection(`schools/${SCHOOL_ID}/inventoryAssets/${asset}/history`).get()
    ).docs.map((assetDocument) => assetDocument.data().type);
    expect(types.sort()).toEqual(['assigned', 'registered', 'returned', 'transferred']);
  });

  it('condition changes, loss while assigned, retire and dispose', async () => {
    await run(a.setCondition, { id: asset, condition: 'fair' });
    expect((await get(`inventoryAssets/${asset}`))!.condition).toBe('fair');
    await run(a.assign, { id: asset, ...staff(7) });
    expect(
      await code(run(a.setCondition, { id: asset, condition: 'good', status: 'available' })),
    ).toBe('failed-precondition');
    expect(await code(run(a.retire, { id: asset, status: 'retired', reason: 'old' }))).toBe(
      'failed-precondition',
    );
    const assignmentId = (await get(`inventoryAssets/${asset}`))!.activeAssignmentId;
    await run(a.setCondition, { id: asset, condition: 'poor', status: 'lost' });
    expect(await get(`inventoryAssets/${asset}`)).toMatchObject({
      status: 'lost',
      activeAssignmentId: null,
    });
    expect(await get(`inventoryAssetAssignments/${assignmentId}`)).toMatchObject({
      closedAs: 'lost',
    });
    await run(a.setCondition, { id: asset, condition: 'good', status: 'available' }); // found again
    await run(a.retire, { id: asset, status: 'retired', reason: 'end of life' });
    expect(await code(run(a.assign, { id: asset, ...staff(7) }))).toBe('failed-precondition');
    expect(await code(run(a.retire, { id: asset, status: 'retired', reason: 'again' }))).toBe(
      'failed-precondition',
    );
    await run(a.retire, { id: asset, status: 'disposed', reason: 'scrapped' });
    expect(await code(run(a.setCondition, { id: asset, condition: 'good' }))).toBe(
      'failed-precondition',
    );
    expect((await get(`inventoryAssets/${asset}`))!.status).toBe('disposed');
  });

  it('maintenance drives the asset status, needs a cost to complete and draws parts from stock', async () => {
    const save = (result: Record<string, unknown> = {}) =>
      run(m.save, { assetId: asset, issue: 'Screen flickers', priority: 'high', ...result });
    const maintenanceJob = await save();
    expect(maintenanceJob.number).toMatch(/^MNT\/.*\/000001$/);
    expect(await get(`inventoryAssets/${asset}`)).toMatchObject({
      status: 'under_maintenance',
      activeMaintenanceId: maintenanceJob.id,
    });
    expect(await code(save())).toBe('failed-precondition'); // one job at a time
    expect(await code(run(a.assign, { id: asset, ...staff(7) }))).toBe('failed-precondition');
    await save({ id: maintenanceJob.id, priority: 'urgent' });
    expect((await get(`inventoryMaintenanceJobs/${maintenanceJob.id}`))!.priority).toBe('urgent');

    const set = (result: Record<string, unknown>, uid = 'asset') =>
      run(m.setStatus, { id: maintenanceJob.id, ...result }, uid);
    expect(await code(set({ status: 'assigned' }))).toBe('failed-precondition'); // technician
    await set({ status: 'assigned', technician: 'Acme Service' });
    await set({ status: 'in_progress' });
    expect((await get(`inventoryAssets/${asset}`))!.status).toBe('under_repair');

    await run(
      receiveStock,
      {
        storeId: store,
        source: 'opening',
        lineItems: [{ itemId: ink, quantityAccepted: 10, unitCost: 4 }],
      },
      'both',
    );
    const parts = [{ itemId: ink, storeId: store, quantity: 2 }];
    expect(await code(set({ status: 'waiting_for_parts', parts }))).toBe('failed-precondition'); // no stock access
    await set({ status: 'waiting_for_parts', parts }, 'both');
    expect((await get(`inventoryBalances/${store}__${ink}__-__-`))!.quantityAvailable).toBe(8);
    expect((await get(`inventoryMaintenanceJobs/${maintenanceJob.id}`))!.partsUsed).toMatchObject([
      { itemId: ink, quantity: 2 },
    ]);
    expect((await get(`inventoryAssets/${asset}`))!.status).toBe('under_maintenance');
    expect(await code(set({ status: 'completed' }))).toBe('failed-precondition'); // cost
    await set({ status: 'completed', cost: 0, condition: 'good', nextServiceDate: day(180) });
    expect(await get(`inventoryAssets/${asset}`)).toMatchObject({
      status: 'available',
      activeMaintenanceId: null,
      condition: 'good',
      nextServiceDate: day(180),
    });
    expect(await get(`inventoryMaintenanceJobs/${maintenanceJob.id}`)).toMatchObject({
      status: 'completed',
      cost: 0,
      completedDate: day(0),
    });
    expect(await code(set({ status: 'in_progress' }))).toBe('failed-precondition'); // finished jobs stay as they are
  });

  it('cancelling restores the previous status; a repaired damaged asset becomes available', async () => {
    await run(a.assign, { id: asset, ...staff(7) });
    const firstJob = await run(m.save, { assetId: asset, issue: 'x', priority: 'low' });
    expect((await get(`inventoryAssets/${asset}`))!.status).toBe('under_maintenance');
    await run(m.setStatus, { id: firstJob.id, status: 'cancelled' });
    expect(await get(`inventoryAssets/${asset}`)).toMatchObject({
      status: 'assigned',
      activeMaintenanceId: null,
    });
    await run(a.return, { id: asset, condition: 'damaged' });
    const secondJob = await run(m.save, { assetId: asset, issue: 'cracked', priority: 'medium' });
    await run(m.setStatus, { id: secondJob.id, status: 'completed', cost: 1200 });
    expect((await get(`inventoryAssets/${asset}`))!.status).toBe('available');
    expect(await code(run(m.save, { assetId: asset, issue: 'x', priority: 'low' }, 'far'))).toBe(
      'permission-denied',
    );
  });
});
