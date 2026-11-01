import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { procurement as p } from '../src/inventory/procurement';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(definition, { uid, token: { schoolId: 12, personType: 'staff' } }, { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('vendors and purchase requests', () => {
  let pen: string, shirt: string;
  const draft = (extra: Record<string, unknown> = {}) =>
    run(p.purchaseRequestSave, {
      campusId: 31, requiredDate: day(7), purpose: 'Term supplies', lineItems: [{ itemId: pen, quantity: 10, estimatedPrice: 5 }], ...extra,
    }, 'req');
  const pending = async () => (await draft({ submit: true })).id as string;

  beforeEach(async () => {
    await clearFirestore();
    const permissionsList = (permissions: string[], campusIds = [31]) => ({ permissions, campusIds, hasAllCampuses: false, personErpId: 5 });
    await db().doc(`schools/${SCHOOL_ID}/userAccess/1`).set(permissionsList(['inventory.settings', 'inventory.items.manage', 'inventory.vendors.manage']));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/req`).set(permissionsList(['inventory.purchaseRequest.request']));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/other`).set(permissionsList(['inventory.purchaseRequest.request']));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/apr`).set(permissionsList(['inventory.purchaseRequest.approve']));
    await db().doc(`schools/${SCHOOL_ID}/userAccess/far`).set(permissionsList(['inventory.purchaseRequest.approve'], [99]));
    await run(masters.seedDefaults, {});
    const category = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'quantity' })).id;
    pen = (await run(masters.itemUpsert, { code: 'PEN', name: 'Pen', categoryId: category, stockUnit: 'pcs', tracking: 'quantity' })).id;
    shirt = (await run(masters.itemUpsert, { code: 'SH', name: 'Shirt', categoryId: category, stockUnit: 'pcs', tracking: 'quantity', variantAttrs: ['size'] })).id;
  });

  it('vendors: unique code, category check, deactivated vendor cannot be preferred', async () => {
    const category = (await db().collection(`schools/${SCHOOL_ID}/inventoryCategories`).limit(1).get()).docs[0].id;
    const vendor = await run(p.vendorUpsert, { code: 'V1', name: 'Acme', email: 'a@acme.in', categoryIds: [category] });
    expect(await get(`inventoryVendors/${vendor.id}`)).toMatchObject({ status: 'active', documents: [], email: 'a@acme.in', categoryIds: [category] });
    await expect(run(p.vendorUpsert, { code: 'v1', name: 'Dup' })).rejects.toMatchObject({ code: 'already-exists' });
    await expect(run(p.vendorUpsert, { code: 'V2', name: 'X', categoryIds: ['nope'] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(p.vendorUpsert, { id: vendor.id, code: 'V9', name: 'Acme' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(p.vendorUpsert, { id: vendor.id, name: 'Acme Ltd', email: '' });
    expect(await get(`inventoryVendors/${vendor.id}`)).toMatchObject({ name: 'Acme Ltd', email: null });
    await expect(run(p.vendorUpsert, { code: 'V3', name: 'X' }, 'req')).rejects.toMatchObject({ code: 'permission-denied' });

    const item = { name: 'Pen2', categoryId: category, stockUnit: 'pcs', tracking: 'quantity' };
    await run(masters.itemUpsert, { code: 'PEN2', ...item, preferredVendorId: vendor.id });
    await run(p.vendorSetStatus, { id: vendor.id, status: 'inactive' });
    await expect(run(masters.itemUpsert, { code: 'PEN3', ...item, preferredVendorId: vendor.id })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(masters.itemUpsert, { code: 'PEN4', ...item, preferredVendorId: 'nope' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('draft → submit → approve with numbering, total, history and notifications', async () => {
    const definition = await draft();
    expect(definition.number).toMatch(/^PR\/\d{4}-\d{2}\/000001$/);
    expect(await get(`inventoryPurchaseRequests/${definition.id}`)).toMatchObject({ status: 'draft', total: 50, requestedBy: 5, history: [] });
    await run(p.purchaseRequestSave, { id: definition.id, campusId: 31, requiredDate: day(3), purpose: 'Edited', lineItems: [{ itemId: pen, quantity: 20, estimatedPrice: 5 }] }, 'req');
    await run(p.purchaseRequestSubmit, { id: definition.id }, 'req');
    expect(await get(`inventoryPurchaseRequests/${definition.id}`)).toMatchObject({ status: 'pending', purpose: 'Edited', total: 100 });
    expect((await db().collection(`schools/${SCHOOL_ID}/outbox`).get()).docs.map((outboxDocument) => outboxDocument.data().to.permission)).toEqual(['inventory.purchaseRequest.approve']);

    await run(p.purchaseRequestDecide, { id: definition.id, decision: 'approve', comment: 'ok' }, 'apr');
    const purchaseRequest = (await get(`inventoryPurchaseRequests/${definition.id}`))!;
    expect(purchaseRequest).toMatchObject({ status: 'approved', approval: { performedBy: 'apr', decision: 'approve', comment: 'ok' } });
    expect(purchaseRequest.history.map((entry: { action: string }) => entry.action)).toEqual(['submit', 'approve']);
    await expect(run(p.purchaseRequestDecide, { id: definition.id, decision: 'reject', comment: 'x' }, 'apr')).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('reject and revise need a comment; revised requests can be edited and resubmitted', async () => {
    const id = await pending();
    await expect(run(p.purchaseRequestDecide, { id, decision: 'reject' }, 'apr')).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(p.purchaseRequestDecide, { id, decision: 'revise', comment: 'cut the quantity' }, 'apr');
    expect((await get(`inventoryPurchaseRequests/${id}`))!.status).toBe('revision_requested');
    await run(p.purchaseRequestSave, { id, campusId: 31, requiredDate: day(5), purpose: 'Less', lineItems: [{ itemId: pen, quantity: 2 }], submit: true }, 'req');
    expect((await get(`inventoryPurchaseRequests/${id}`))!).toMatchObject({ status: 'pending', total: 0 });
    await run(p.purchaseRequestDecide, { id, decision: 'reject', comment: 'no budget' }, 'apr');
    const actions = (await get(`inventoryPurchaseRequests/${id}`))!.history.map((purchaseRequest: { action: string }) => purchaseRequest.action);
    expect(actions).toEqual(['submit', 'revise', 'submit', 'reject']);
  });

  it('only the requester edits and cancels; approved-and-ordered or finished requests cannot be cancelled', async () => {
    const definition = (await draft()).id as string;
    await expect(run(p.purchaseRequestSubmit, { id: definition }, 'other')).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(p.purchaseRequestCancel, { id: definition, reason: 'not needed' }, 'req');
    expect(await get(`inventoryPurchaseRequests/${definition}`)).toMatchObject({ status: 'cancelled', history: [{ action: 'cancel', comment: 'not needed' }] });
    await expect(run(p.purchaseRequestSubmit, { id: definition }, 'req')).rejects.toMatchObject({ code: 'failed-precondition' });

    const first = await pending();
    await run(p.purchaseRequestDecide, { id: first, decision: 'approve' }, 'apr');
    await db().doc(`schools/${SCHOOL_ID}/inventoryPurchaseRequests/${first}`).update({ lineItems: [{ itemId: pen, quantity: 10, estimatedPrice: 5, quantityOrdered: 4 }] });
    await expect(run(p.purchaseRequestCancel, { id: first }, 'req')).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('validates lines, dates, campus and approver scope', async () => {
    await expect(draft({ requiredDate: day(-1) })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(draft({ lineItems: [{ itemId: shirt, quantity: 1 }] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(draft({ lineItems: [{ itemId: pen, quantity: 1 }, { itemId: pen, quantity: 2 }] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(draft({ lineItems: [{ itemId: pen, quantity: 0 }] })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(draft({ campusId: 32 })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(run(p.purchaseRequestSave, { campusId: 31, requiredDate: day(1), purpose: 'x', lineItems: [{ itemId: pen, quantity: 1 }] }, 'apr')).rejects.toMatchObject({ code: 'permission-denied' });

    const id = await pending();
    await expect(run(p.purchaseRequestDecide, { id, decision: 'approve' }, 'far')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(run(p.purchaseRequestDecide, { id, decision: 'approve' }, 'req')).rejects.toMatchObject({ code: 'permission-denied' });
    await run(p.vendorSetStatus, { id: 'nope', status: 'active' }).catch((error) => expect(error.code).toBe('not-found'));
  });
});
