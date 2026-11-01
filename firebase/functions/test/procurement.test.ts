import { beforeEach, describe, expect, it } from 'vitest';
import { masters } from '../src/inventory/masters';
import { procurement as p } from '../src/inventory/procurement';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { clearFirestore, db } from './setup';

const SID = '12';
let n = 0;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (d: CallableDef<any, any>, data: Record<string, unknown>, uid = 'u_1') =>
  runCallable(d, { uid, token: { sid: 12, pt: 'staff' } }, { requestId: `req-${String(++n).padStart(6, '0')}`, ...data });
const get = async (path: string) => (await db().doc(`schools/${SID}/${path}`).get()).data();
const day = (offset: number) => new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('vendors and purchase requests', () => {
  let pen: string, shirt: string;
  const draft = (extra: Record<string, unknown> = {}) =>
    run(p.prSave, {
      campusId: 31, requiredDate: day(7), purpose: 'Term supplies', lines: [{ itemId: pen, qty: 10, estPrice: 5 }], ...extra,
    }, 'u_req');
  const pending = async () => (await draft({ submit: true })).id as string;

  beforeEach(async () => {
    await clearFirestore();
    const acc = (perms: string[], cmp = [31]) => ({ perms, cmp, all: false, eid: 5 });
    await db().doc(`schools/${SID}/userAccess/u_1`).set(acc(['inv.settings', 'inv.items.manage', 'inv.vendors.manage']));
    await db().doc(`schools/${SID}/userAccess/u_req`).set(acc(['inv.pr.request']));
    await db().doc(`schools/${SID}/userAccess/u_other`).set(acc(['inv.pr.request']));
    await db().doc(`schools/${SID}/userAccess/u_apr`).set(acc(['inv.pr.approve']));
    await db().doc(`schools/${SID}/userAccess/u_far`).set(acc(['inv.pr.approve'], [99]));
    await run(masters.seedDefaults, {});
    const cat = (await run(masters.categoryUpsert, { code: 'GEN', name: 'General', suggestedTracking: 'qty' })).id;
    pen = (await run(masters.itemUpsert, { code: 'PEN', name: 'Pen', categoryId: cat, stockUnit: 'pcs', tracking: 'qty' })).id;
    shirt = (await run(masters.itemUpsert, { code: 'SH', name: 'Shirt', categoryId: cat, stockUnit: 'pcs', tracking: 'qty', variantAttrs: ['size'] })).id;
  });

  it('vendors: unique code, category check, deactivated vendor cannot be preferred', async () => {
    const cat = (await db().collection(`schools/${SID}/invCategories`).limit(1).get()).docs[0].id;
    const v = await run(p.vendorUpsert, { code: 'V1', name: 'Acme', email: 'a@acme.in', categoryIds: [cat] });
    expect(await get(`invVendors/${v.id}`)).toMatchObject({ status: 'active', documents: [], email: 'a@acme.in', categoryIds: [cat] });
    await expect(run(p.vendorUpsert, { code: 'v1', name: 'Dup' })).rejects.toMatchObject({ code: 'already-exists' });
    await expect(run(p.vendorUpsert, { code: 'V2', name: 'X', categoryIds: ['nope'] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(p.vendorUpsert, { id: v.id, code: 'V9', name: 'Acme' })).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(p.vendorUpsert, { id: v.id, name: 'Acme Ltd', email: '' });
    expect(await get(`invVendors/${v.id}`)).toMatchObject({ name: 'Acme Ltd', email: null });
    await expect(run(p.vendorUpsert, { code: 'V3', name: 'X' }, 'u_req')).rejects.toMatchObject({ code: 'permission-denied' });

    const item = { name: 'Pen2', categoryId: cat, stockUnit: 'pcs', tracking: 'qty' };
    await run(masters.itemUpsert, { code: 'PEN2', ...item, preferredVendorId: v.id });
    await run(p.vendorSetStatus, { id: v.id, status: 'inactive' });
    await expect(run(masters.itemUpsert, { code: 'PEN3', ...item, preferredVendorId: v.id })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(run(masters.itemUpsert, { code: 'PEN4', ...item, preferredVendorId: 'nope' })).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('draft → submit → approve with numbering, total, history and notifications', async () => {
    const d = await draft();
    expect(d.number).toMatch(/^PR\/\d{4}-\d{2}\/000001$/);
    expect(await get(`invPurchaseRequests/${d.id}`)).toMatchObject({ status: 'draft', total: 50, requestedBy: 5, history: [] });
    await run(p.prSave, { id: d.id, campusId: 31, requiredDate: day(3), purpose: 'Edited', lines: [{ itemId: pen, qty: 20, estPrice: 5 }] }, 'u_req');
    await run(p.prSubmit, { id: d.id }, 'u_req');
    expect(await get(`invPurchaseRequests/${d.id}`)).toMatchObject({ status: 'pending', purpose: 'Edited', total: 100 });
    expect((await db().collection(`schools/${SID}/outbox`).get()).docs.map((o) => o.data().to.perm)).toEqual(['inv.pr.approve']);

    await run(p.prDecide, { id: d.id, decision: 'approve', comment: 'ok' }, 'u_apr');
    const pr = (await get(`invPurchaseRequests/${d.id}`))!;
    expect(pr).toMatchObject({ status: 'approved', approval: { by: 'u_apr', decision: 'approve', comment: 'ok' } });
    expect(pr.history.map((h: { action: string }) => h.action)).toEqual(['submit', 'approve']);
    await expect(run(p.prDecide, { id: d.id, decision: 'reject', comment: 'x' }, 'u_apr')).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('reject and revise need a comment; revised requests can be edited and resubmitted', async () => {
    const id = await pending();
    await expect(run(p.prDecide, { id, decision: 'reject' }, 'u_apr')).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(p.prDecide, { id, decision: 'revise', comment: 'cut the quantity' }, 'u_apr');
    expect((await get(`invPurchaseRequests/${id}`))!.status).toBe('revision_requested');
    await run(p.prSave, { id, campusId: 31, requiredDate: day(5), purpose: 'Less', lines: [{ itemId: pen, qty: 2 }], submit: true }, 'u_req');
    expect((await get(`invPurchaseRequests/${id}`))!).toMatchObject({ status: 'pending', total: 0 });
    await run(p.prDecide, { id, decision: 'reject', comment: 'no budget' }, 'u_apr');
    const h = (await get(`invPurchaseRequests/${id}`))!.history.map((x: { action: string }) => x.action);
    expect(h).toEqual(['submit', 'revise', 'submit', 'reject']);
  });

  it('only the requester edits and cancels; approved-and-ordered or finished requests cannot be cancelled', async () => {
    const d = (await draft()).id as string;
    await expect(run(p.prSubmit, { id: d }, 'u_other')).rejects.toMatchObject({ code: 'failed-precondition' });
    await run(p.prCancel, { id: d, reason: 'not needed' }, 'u_req');
    expect(await get(`invPurchaseRequests/${d}`)).toMatchObject({ status: 'cancelled', history: [{ action: 'cancel', comment: 'not needed' }] });
    await expect(run(p.prSubmit, { id: d }, 'u_req')).rejects.toMatchObject({ code: 'failed-precondition' });

    const a = await pending();
    await run(p.prDecide, { id: a, decision: 'approve' }, 'u_apr');
    await db().doc(`schools/${SID}/invPurchaseRequests/${a}`).update({ lines: [{ itemId: pen, qty: 10, estPrice: 5, qtyOrdered: 4 }] });
    await expect(run(p.prCancel, { id: a }, 'u_req')).rejects.toMatchObject({ code: 'failed-precondition' });
  });

  it('validates lines, dates, campus and approver scope', async () => {
    await expect(draft({ requiredDate: day(-1) })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(draft({ lines: [{ itemId: shirt, qty: 1 }] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(draft({ lines: [{ itemId: pen, qty: 1 }, { itemId: pen, qty: 2 }] })).rejects.toMatchObject({ code: 'failed-precondition' });
    await expect(draft({ lines: [{ itemId: pen, qty: 0 }] })).rejects.toMatchObject({ code: 'invalid-argument' });
    await expect(draft({ campusId: 32 })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(run(p.prSave, { campusId: 31, requiredDate: day(1), purpose: 'x', lines: [{ itemId: pen, qty: 1 }] }, 'u_apr')).rejects.toMatchObject({ code: 'permission-denied' });

    const id = await pending();
    await expect(run(p.prDecide, { id, decision: 'approve' }, 'u_far')).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(run(p.prDecide, { id, decision: 'approve' }, 'u_req')).rejects.toMatchObject({ code: 'permission-denied' });
    await run(p.vendorSetStatus, { id: 'nope', status: 'active' }).catch((e) => expect(e.code).toBe('not-found'));
  });
});
