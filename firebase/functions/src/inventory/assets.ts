import '../region';
import { DocumentData, DocumentReference, FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Ctx } from '../shared/callable';
import { claimUniqueKey, nextNumber } from '../shared/keys';
import { def, failed, id, missing, note, usable } from '../shared/masters';
import { day, lineKey, person, qty, Stock, todayIST } from './stock';

/** Individual assets: registration, custody, condition, retirement (FRS 10.19) and maintenance (FRS 10.20). */

const condition = z.enum(['new', 'good', 'fair', 'poor', 'damaged']);
const money = z.number().min(0).max(100_000_000);
const text = z.string().trim().max(120).nullish();
// Maintenance status drives the asset status (architecture §6): `restoreTo` is what the asset was before.
const LIVE = ['open', 'assigned', 'in_progress', 'waiting_for_parts'];
const WORKING = { assigned: 'under_maintenance', waiting_for_parts: 'under_maintenance', in_progress: 'under_repair' } as const;
const UP = () => FieldValue.serverTimestamp();

async function loadAsset(ctx: Ctx, assetId: string) {
  const ref = ctx.doc(`invAssets/${assetId}`);
  const d = (await ctx.tx.get(ref)).data();
  if (!d) throw missing('Asset');
  ctx.requireCampus(d.campusId);
  return { ref, d };
}

/** Appends to the asset's history timeline (`invAssets/{id}/history`). */
function hist(ctx: Ctx, ref: DocumentReference, d: DocumentData, type: string, detail: Record<string, unknown> = {}) {
  ctx.set(ref.collection('history').doc(), { type, ...detail, campusId: d.campusId, by: ctx.uid, at: UP() });
}

const assignee = z.object({
  assignee: person,
  location: text,
  expectedReturn: day.nullish(),
  acknowledged: z.boolean().default(false),
  remarks: note,
});

/** Opens a custody record; the asset doc is updated by the caller. */
function openAssignment(ctx: Ctx, d: DocumentData, assetDocId: string, i: z.infer<typeof assignee>, cond: string, from?: string) {
  if (i.expectedReturn && i.expectedReturn < todayIST()) throw failed('Expected return date is in the past');
  const ref = ctx.newDoc('invAssetAssignments');
  ctx.set(ref, {
    assetId: assetDocId, assetCode: d.assetId, assetName: d.name, campusId: d.campusId, assignee: i.assignee,
    // A department ID is not a person's ERP ID, so it never matches a user's own-record rule.
    personErpId: i.assignee.type === 'department' ? null : i.assignee.erpId,
    location: i.location ?? null, assignedDate: todayIST(), assignedAt: UP(), assignedBy: ctx.uid,
    expectedReturn: i.expectedReturn ?? null, conditionOut: cond, ack: i.acknowledged ? { at: UP() } : null,
    remarks: i.remarks ?? null, transferredFrom: from ?? null, returnedAt: null, returnedDate: null, conditionIn: null, closedAs: null,
  });
  return ref;
}

async function closeAssignment(ctx: Ctx, d: DocumentData, closedAs: 'returned' | 'transferred' | 'lost', cond: string | null) {
  const ref = ctx.doc(`invAssetAssignments/${d.activeAssignmentId}`);
  if (!(await ctx.tx.get(ref)).exists) throw missing('Assignment');
  ctx.update(ref, { returnedAt: UP(), returnedDate: todayIST(), returnedBy: ctx.uid, conditionIn: cond, closedAs });
  return ref;
}

export const assets = {
  /** One physical asset per call; the asset ID (`AST/<fy>/<seq>`) doubles as its barcode / QR value. */
  register: def({
    name: 'inv.asset.register',
    perm: 'inv.assets.manage',
    input: z.object({
      itemId: id,
      storeId: id,
      name: z.string().trim().min(1).max(120).optional(),
      serialNo: text,
      make: text,
      model: text,
      poId: id.nullish(),
      vendorId: id.nullish(),
      purchaseDate: day.nullish(),
      price: money.nullish(),
      warrantyStart: day.nullish(),
      warrantyEnd: day.nullish(),
      condition: condition.default('new'),
      location: text,
    }),
    handler: async (ctx, i) => {
      const item = usable(await ctx.tx.get(ctx.doc(`invItems/${i.itemId}`)), 'Item', false);
      if (item.tracking !== 'asset') throw failed(`${item.name} is not tracked as an individual asset`);
      const store = usable(await ctx.tx.get(ctx.doc(`invStores/${i.storeId}`)), 'Store', false);
      ctx.requireCampus(store.campusId);
      if (i.warrantyStart && i.warrantyEnd && i.warrantyEnd < i.warrantyStart) throw failed('Warranty ends before it starts');
      let { vendorId, price } = { vendorId: i.vendorId ?? null, price: i.price ?? null };
      if (i.poId) {
        const po = (await ctx.tx.get(ctx.doc(`invPurchaseOrders/${i.poId}`))).data();
        if (!po) throw missing('Purchase order');
        if (po.deliveryCampusId !== store.campusId) throw failed('Store is not on the order\'s delivery campus');
        const line = (po.lines as Array<{ itemId: string; qtyAccepted: number; unitPrice: number }>).find((l) => l.itemId === i.itemId);
        if (!line) throw failed('Item is not on the order');
        const done = (await ctx.tx.get(ctx.coll('invAssets').where('poId', '==', i.poId).where('itemId', '==', i.itemId))).size;
        if (done >= line.qtyAccepted) throw failed('Every accepted unit of this item is already registered');
        vendorId = po.vendorId;
        price ??= line.unitPrice;
      }
      const assetId = await nextNumber(ctx, 'AST');
      const ref = ctx.newDoc('invAssets');
      await claimUniqueKey(ctx, 'invAsset', assetId, ref.path);
      const d = {
        assetId, itemId: i.itemId, name: i.name ?? item.name, categoryId: item.categoryId, serialNo: i.serialNo ?? null,
        make: i.make ?? null, model: i.model ?? null, poId: i.poId ?? null, vendorId, purchaseDate: i.purchaseDate ?? null, price,
        warranty: { start: i.warrantyStart ?? null, end: i.warrantyEnd ?? null }, condition: i.condition, campusId: store.campusId,
        storeId: i.storeId, location: i.location ?? null, status: 'available', activeAssignmentId: null, assignedTo: null,
        activeMaintenanceId: null, nextServiceDate: null, rfidTag: null, imagePath: null,
        createdAt: UP(), createdBy: ctx.uid, updatedAt: UP(),
      };
      ctx.set(ref, d);
      hist(ctx, ref, d, 'registered', { condition: i.condition });
      ctx.audit({ action: 'invAsset.register', ref: ref.path, after: { assetId, itemId: i.itemId } });
      return { id: ref.id, number: assetId };
    },
  }),

  assign: def({
    name: 'inv.asset.assign',
    perm: 'inv.assets.manage',
    input: assignee.extend({ id, condition: condition.optional() }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadAsset(ctx, i.id);
      if (d.status !== 'available' || d.activeAssignmentId) throw failed(`Asset is ${d.status}`);
      const cond = i.condition ?? d.condition;
      const aRef = openAssignment(ctx, d, ref.id, i, cond);
      ctx.update(ref, { status: 'assigned', activeAssignmentId: aRef.id, assignedTo: i.assignee, condition: cond, location: i.location ?? d.location, updatedAt: UP() });
      hist(ctx, ref, d, 'assigned', { assignee: i.assignee, assignmentId: aRef.id });
      ctx.audit({ action: 'invAsset.assign', ref: ref.path, before: { status: d.status }, after: { assignee: i.assignee } });
      return { id: ref.id, assignmentId: aRef.id };
    },
  }),

  /** Custody moves to another person or department; the previous assignment is closed and kept. */
  transfer: def({
    name: 'inv.asset.transfer',
    perm: 'inv.assets.manage',
    input: assignee.extend({ id, condition: condition.optional() }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadAsset(ctx, i.id);
      if (d.status !== 'assigned') throw failed(`Asset is ${d.status}`);
      const from = d.assignedTo as { type: string; erpId: number };
      if (from.type === i.assignee.type && from.erpId === i.assignee.erpId) throw failed('Asset is already assigned to this custodian');
      const cond = i.condition ?? d.condition;
      const oldRef = await closeAssignment(ctx, d, 'transferred', cond);
      const aRef = openAssignment(ctx, d, ref.id, i, cond, oldRef.id);
      ctx.update(ref, { activeAssignmentId: aRef.id, assignedTo: i.assignee, condition: cond, location: i.location ?? d.location, updatedAt: UP() });
      hist(ctx, ref, d, 'transferred', { from, to: i.assignee, assignmentId: aRef.id });
      ctx.audit({ action: 'invAsset.transfer', ref: ref.path, before: { assignedTo: from }, after: { assignedTo: i.assignee } });
      return { id: ref.id, assignmentId: aRef.id };
    },
  }),

  /** Back to the store; a damaged return makes the asset `damaged` until its condition is reviewed. */
  return: def({
    name: 'inv.asset.return',
    perm: 'inv.assets.manage',
    input: z.object({ id, condition, location: text, remarks: note }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadAsset(ctx, i.id);
      if (d.status !== 'assigned') throw failed(`Asset is ${d.status}`);
      await closeAssignment(ctx, d, 'returned', i.condition);
      const status = i.condition === 'damaged' ? 'damaged' : 'available';
      ctx.update(ref, { status, activeAssignmentId: null, assignedTo: null, condition: i.condition, location: i.location ?? d.location, updatedAt: UP() });
      hist(ctx, ref, d, 'returned', { condition: i.condition, remarks: i.remarks ?? null });
      ctx.audit({ action: 'invAsset.return', ref: ref.path, before: { status: d.status }, after: { status, condition: i.condition } });
      return { id: ref.id, status };
    },
  }),

  /**
   * Updates the condition, and optionally moves the asset between `available`, `damaged` and `lost`.
   * Maintenance owns the status while a job is live; an assigned asset can only be written off as lost.
   */
  setCondition: def({
    name: 'inv.asset.setCondition',
    perm: 'inv.assets.manage',
    input: z.object({ id, condition, status: z.enum(['available', 'damaged', 'lost']).optional(), remarks: note }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadAsset(ctx, i.id);
      if (['retired', 'disposed'].includes(d.status)) throw failed(`Asset is ${d.status}`);
      const patch: Record<string, unknown> = { condition: i.condition, updatedAt: UP() };
      if (i.status && i.status !== d.status) {
        if (d.activeMaintenanceId) throw failed('Asset is in maintenance');
        if (d.status === 'assigned') {
          if (i.status !== 'lost') throw failed('Return the asset first');
          await closeAssignment(ctx, d, 'lost', null);
          Object.assign(patch, { activeAssignmentId: null, assignedTo: null });
        }
        patch.status = i.status;
      }
      ctx.update(ref, patch);
      hist(ctx, ref, d, 'condition', { condition: i.condition, status: i.status ?? d.status, remarks: i.remarks ?? null });
      ctx.audit({ action: 'invAsset.setCondition', ref: ref.path, before: { status: d.status, condition: d.condition }, after: { status: patch.status ?? d.status, condition: i.condition } });
      return { id: ref.id };
    },
  }),

  /** Retire an unused asset, then optionally mark it disposed. Neither can be assigned again. */
  retire: def({
    name: 'inv.asset.retire',
    perm: 'inv.assets.manage',
    input: z.object({ id, kind: z.enum(['retired', 'disposed']), reason: z.string().trim().min(1).max(500) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadAsset(ctx, i.id);
      const from = ['available', 'damaged', 'lost'].concat(i.kind === 'disposed' ? ['retired'] : []);
      if (!from.includes(d.status)) throw failed(d.status === 'assigned' ? 'Return the asset first' : `Asset is ${d.status}`);
      ctx.update(ref, { status: i.kind, retireReason: i.reason, retiredAt: UP(), updatedAt: UP() });
      hist(ctx, ref, d, i.kind, { reason: i.reason });
      ctx.audit({ action: `invAsset.${i.kind}`, ref: ref.path, before: { status: d.status }, after: { status: i.kind }, reason: i.reason });
      return { id: ref.id };
    },
  }),
};

export const maintenance = {
  /** Reports a fault (no `id`) or edits a live job. Raising one puts the asset `under_maintenance`. */
  save: def({
    name: 'inv.maintenance.save',
    perm: 'inv.assets.manage',
    input: z.object({
      id: id.optional(),
      assetId: id,
      issue: z.string().trim().min(1).max(1000),
      priority: z.enum(['low', 'medium', 'high', 'urgent']),
      technician: text,
      reportedDate: day.optional(),
      nextServiceDate: day.nullish(),
    }),
    handler: async (ctx, i) => {
      const fields = {
        issue: i.issue, priority: i.priority, technician: i.technician ?? null, nextServiceDate: i.nextServiceDate ?? null, updatedAt: UP(),
      };
      if (i.id) {
        const ref = ctx.doc(`invMaintenance/${i.id}`);
        const m = (await ctx.tx.get(ref)).data();
        if (!m) throw missing('Maintenance request');
        ctx.requireCampus(m.campusId);
        if (m.assetId !== i.assetId) throw failed('Asset cannot change');
        if (!LIVE.includes(m.status)) throw failed(`Request is ${m.status}`);
        ctx.update(ref, { ...fields, ...(i.reportedDate ? { reportedDate: i.reportedDate } : {}) });
        ctx.audit({ action: 'invMaintenance.update', ref: ref.path, before: { priority: m.priority }, after: { priority: i.priority } });
        return { id: ref.id, number: m.number };
      }
      const { ref: aRef, d } = await loadAsset(ctx, i.assetId);
      if (['lost', 'retired', 'disposed'].includes(d.status)) throw failed(`Asset is ${d.status}`);
      if (d.activeMaintenanceId) throw failed('Asset already has an open maintenance request');
      const reported = i.reportedDate ?? todayIST();
      if (reported > todayIST()) throw failed('Reported date is in the future');
      const number = await nextNumber(ctx, 'MNT');
      const ref = ctx.newDoc('invMaintenance');
      ctx.set(ref, {
        ...fields, number, assetId: aRef.id, assetCode: d.assetId, assetName: d.name, campusId: d.campusId, reportedDate: reported,
        reportedBy: ctx.uid, reportedByErpId: ctx.access.eid ?? null, repairDetails: null, cost: null, partsUsed: [], attachments: [],
        status: 'open', restoreTo: d.status, completedDate: null, createdAt: UP(), createdBy: ctx.uid,
      });
      ctx.update(aRef, { status: 'under_maintenance', activeMaintenanceId: ref.id, updatedAt: UP() });
      hist(ctx, aRef, d, 'maintenance.open', { number, issue: i.issue });
      ctx.audit({ action: 'invMaintenance.create', ref: ref.path, after: { number, assetId: i.assetId } });
      return { id: ref.id, number };
    },
  }),

  /**
   * Moves a live job on. Completing needs the repair cost (0 is fine) and frees the asset; cancelling puts the
   * asset back as it was. Parts are drawn from store stock as `issue` movements, once per call (never reversed).
   */
  setStatus: def({
    name: 'inv.maintenance.setStatus',
    perm: 'inv.assets.manage',
    input: z.object({
      id,
      status: z.enum(['assigned', 'in_progress', 'waiting_for_parts', 'completed', 'cancelled']),
      technician: text,
      repairDetails: z.string().trim().max(1000).nullish(),
      cost: money.nullish(),
      nextServiceDate: day.nullish(),
      condition: condition.optional(),
      parts: z.array(z.object({ ...lineKey, storeId: id, qty })).max(20).default([]),
    }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invMaintenance/${i.id}`);
      const m = (await ctx.tx.get(ref)).data();
      if (!m) throw missing('Maintenance request');
      ctx.requireCampus(m.campusId);
      if (!LIVE.includes(m.status)) throw failed(`Request is ${m.status}`);
      const technician = i.technician ?? m.technician;
      const cost = i.cost ?? m.cost;
      if (i.status === 'assigned' && !technician) throw failed('Technician required');
      if (i.status === 'completed' && cost == null) throw failed('Repair cost required');
      const { ref: aRef, d } = await loadAsset(ctx, m.assetId);

      const used = [];
      if (i.parts.length) {
        if (!ctx.access.perms.includes('inv.stock.operate')) throw failed('Drawing parts needs stock access');
        const s = new Stock(ctx);
        for (const p of i.parts) {
          await s.store(p.storeId);
          const item = await s.item(p.itemId, p.variantId);
          for (const a of await s.allocate(p.storeId, item, p.variantId, p.qty)) {
            s.move(a.bal, 'available', -a.qty, { type: 'issue', refType: 'maintenance', refId: ref.id });
            used.push({ itemId: p.itemId, variantId: p.variantId ?? null, storeId: p.storeId, balanceId: a.bal.id, qty: a.qty, unitCost: a.bal.d.unitCost });
          }
        }
        await s.finish();
      }

      const done = i.status === 'completed' || i.status === 'cancelled';
      ctx.update(ref, {
        status: i.status, technician: technician ?? null, cost: cost ?? null, repairDetails: i.repairDetails ?? m.repairDetails,
        nextServiceDate: i.nextServiceDate ?? m.nextServiceDate, partsUsed: [...m.partsUsed, ...used],
        completedDate: done ? todayIST() : null, updatedAt: UP(),
      });
      const patch: Record<string, unknown> = { updatedAt: UP() };
      if (done) {
        // A repaired `damaged` asset is usable again; cancelling leaves it as it was.
        Object.assign(patch, {
          status: i.status === 'completed' && m.restoreTo === 'damaged' ? 'available' : m.restoreTo, activeMaintenanceId: null,
          ...(i.status === 'completed' && { nextServiceDate: i.nextServiceDate ?? m.nextServiceDate, ...(i.condition && { condition: i.condition }) }),
        });
      } else {
        patch.status = WORKING[i.status as keyof typeof WORKING];
      }
      ctx.update(aRef, patch);
      hist(ctx, aRef, d, `maintenance.${i.status}`, { number: m.number, cost: cost ?? null });
      ctx.audit({ action: 'invMaintenance.setStatus', ref: ref.path, before: { status: m.status }, after: { status: i.status, cost: cost ?? null } });
      return { id: ref.id, status: i.status };
    },
  }),
};
