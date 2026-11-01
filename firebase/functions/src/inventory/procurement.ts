import '../region';
import { DocumentData, DocumentReference, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Ctx } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { code, def, failed, id, missing, name, note, saveMaster, setStatusDef, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { day, lineKey, qty, todayIST } from './stock';

/** Vendors (FRS 10.14) and purchase requests (FRS 10.13). Quotations and POs arrive with Inv-4. */

const text = (max: number) => z.string().trim().max(max).nullish();
const price = z.number().min(0).max(100_000_000);
const EDITABLE = ['draft', 'revision_requested'];
const CANCELLABLE = [...EDITABLE, 'pending', 'approved'];

/** Approval history entry; array elements cannot hold server timestamps. */
const hist = (ctx: Ctx, action: string, comment?: string | null) => ({
  action, by: ctx.uid, at: Timestamp.now(), comment: comment ?? null,
});

async function loadPr(ctx: Ctx, prId: string): Promise<{ ref: DocumentReference; pr: DocumentData }> {
  const ref = ctx.doc(`invPurchaseRequests/${prId}`);
  const pr = (await ctx.tx.get(ref)).data();
  if (!pr) throw missing('Purchase request');
  ctx.requireCampus(pr.campusId);
  return { ref, pr };
}

function ownDraft(ctx: Ctx, pr: DocumentData): void {
  if (pr.createdBy !== ctx.uid) throw failed('Only the requester can change this request');
  if (!EDITABLE.includes(pr.status)) throw failed(`Request is ${pr.status}`);
}

/** Checks items and variants (any tracking, assets included) and returns the stored lines. */
async function prLines(ctx: Ctx, ls: Array<{ itemId: string; variantId?: string | null; qty: number; estPrice: number }>) {
  if (new Set(ls.map((l) => `${l.itemId}__${l.variantId ?? '-'}`)).size !== ls.length) {
    throw failed('Each item (and variant) may appear once');
  }
  for (const l of ls) {
    const item = usable(await ctx.tx.get(ctx.doc(`invItems/${l.itemId}`)), 'Item', false);
    const hasVariants = (item.variantAttrs as string[]).length > 0;
    if (hasVariants !== !!l.variantId) throw failed(hasVariants ? `${item.name} needs a variant` : `${item.name} has no variants`);
    if (l.variantId) usable(await ctx.tx.get(ctx.doc(`invItems/${l.itemId}/variants/${l.variantId}`)), 'Variant', false);
  }
  return ls.map((l) => ({ itemId: l.itemId, variantId: l.variantId ?? null, qty: l.qty, estPrice: l.estPrice, qtyOrdered: 0 }));
}

async function notifyApprovers(ctx: Ctx, prId: string, pr: { number: string; campusId: number; purpose: string }, n: number) {
  await enqueue(ctx, `pr_submit__${prId}__${n}`, {
    to: { perm: 'inv.pr.approve', campusId: pr.campusId }, category: 'inv.purchaseRequest',
    title: 'Purchase request awaiting approval', body: `${pr.number}: ${pr.purpose}`, data: { id: prId },
  });
}

const header = {
  campusId: z.number().int(),
  departmentId: z.number().int().nullish(),
  requiredDate: day,
  priority: z.enum(['low', 'normal', 'high', 'urgent']).default('normal'),
  purpose: z.string().trim().min(1).max(500),
  remarks: z.string().trim().max(500).nullish(),
  lines: z.array(z.object({ ...lineKey, qty, estPrice: price.default(0) })).min(1).max(50),
};

export const procurement = {
  vendorUpsert: def({
    name: 'inv.vendor.upsert',
    perm: 'inv.vendors.manage',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      contactPerson: text(120),
      phone: text(30),
      email: z.union([z.email(), z.literal('')]).nullish(),
      address: note,
      taxNo: text(40),
      website: text(200),
      categoryIds: z.array(id).max(30).default([]),
      notes: note,
    }),
    handler: (ctx, i) =>
      saveMaster(ctx, {
        coll: 'invVendors',
        kind: 'invVendor',
        id: i.id,
        code: i.code,
        build: async (before) => {
          const cats = [...new Set(i.categoryIds)];
          if (cats.length) {
            const snaps = await ctx.tx.getAll(...cats.map((c) => ctx.doc(`invCategories/${c}`)));
            if (snaps.some((s) => !s.exists)) throw failed('Category not found');
          }
          return {
            name: i.name, contactPerson: i.contactPerson ?? null, phone: i.phone ?? null, email: i.email || null,
            address: i.address ?? null, taxNo: i.taxNo ?? null, website: i.website ?? null, categoryIds: cats,
            notes: i.notes ?? null,
            // ponytail: documents stay empty until uploads exist (files-getUploadPath).
            ...(before ? {} : { documents: [] }),
          };
        },
      }),
  }),
  vendorSetStatus: setStatusDef('inv.vendor.setStatus', 'inv.vendors.manage', 'invVendors', 'invVendor'),

  /** Creates or edits a draft / returned request; `submit` also sends it for approval. */
  prSave: def({
    name: 'inv.pr.save',
    perm: 'inv.pr.request',
    input: z.object({ id: id.optional(), ...header, submit: z.boolean().default(false) }),
    handler: async (ctx, i) => {
      if (i.requiredDate < todayIST()) throw failed('Required date is in the past');
      const lines = await prLines(ctx, i.lines);
      const fields = {
        departmentId: i.departmentId ?? null, requiredDate: i.requiredDate, priority: i.priority, purpose: i.purpose,
        remarks: i.remarks ?? null, lines, itemIds: [...new Set(lines.map((l) => l.itemId))],
        total: Math.round(lines.reduce((n, l) => n + l.qty * l.estPrice, 0) * 100) / 100,
      };
      const now = FieldValue.serverTimestamp();
      if (i.id) {
        const { ref, pr } = await loadPr(ctx, i.id);
        ownDraft(ctx, pr);
        if (pr.campusId !== i.campusId) throw failed('Campus cannot change');
        const history = i.submit ? [...pr.history, hist(ctx, 'submit')] : pr.history;
        ctx.update(ref, { ...fields, ...(i.submit ? { status: 'pending', history } : {}), updatedAt: now });
        ctx.audit({ action: 'invPurchaseRequest.update', ref: ref.path, before: { status: pr.status }, after: { status: i.submit ? 'pending' : pr.status } });
        if (i.submit) await notifyApprovers(ctx, ref.id, pr as never, history.length);
        return { id: ref.id, number: pr.number as string };
      }
      const ref = ctx.newDoc('invPurchaseRequests');
      const number = await nextNumber(ctx, 'PR');
      ctx.set(ref, {
        ...fields, number, campusId: i.campusId, requestedBy: ctx.access.eid ?? null, attachments: [], approval: null,
        status: i.submit ? 'pending' : 'draft', history: i.submit ? [hist(ctx, 'submit')] : [],
        requestDate: todayIST(), createdAt: now, createdBy: ctx.uid, updatedAt: now,
      });
      ctx.audit({ action: 'invPurchaseRequest.create', ref: ref.path, after: { number, status: i.submit ? 'pending' : 'draft' } });
      if (i.submit) await notifyApprovers(ctx, ref.id, { number, campusId: i.campusId, purpose: i.purpose }, 1);
      return { id: ref.id, number };
    },
  }),

  /** Sends a stored draft (or one returned for revision) for approval. */
  prSubmit: def({
    name: 'inv.pr.submit',
    perm: 'inv.pr.request',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const { ref, pr } = await loadPr(ctx, i.id);
      ownDraft(ctx, pr);
      const history = [...pr.history, hist(ctx, 'submit')];
      ctx.update(ref, { status: 'pending', history, updatedAt: FieldValue.serverTimestamp() });
      ctx.audit({ action: 'invPurchaseRequest.submit', ref: ref.path, before: { status: pr.status }, after: { status: 'pending' } });
      await notifyApprovers(ctx, ref.id, pr as never, history.length);
      return { id: ref.id, number: pr.number as string };
    },
  }),

  /** FRS 10.13: approval is mandatory before procurement; every decision stays in `history`. */
  prDecide: def({
    name: 'inv.pr.decide',
    perm: 'inv.pr.approve',
    input: z.object({ id, decision: z.enum(['approve', 'reject', 'revise']), comment: z.string().trim().max(500).nullish() }),
    handler: async (ctx, i) => {
      const { ref, pr } = await loadPr(ctx, i.id);
      if (pr.status !== 'pending') throw failed(`Request is ${pr.status}`);
      if (i.decision !== 'approve' && !i.comment) throw failed('A comment is required');
      const status = { approve: 'approved', reject: 'rejected', revise: 'revision_requested' }[i.decision];
      const history = [...pr.history, hist(ctx, i.decision, i.comment)];
      ctx.update(ref, {
        status, history, approval: { by: ctx.uid, at: FieldValue.serverTimestamp(), decision: i.decision, comment: i.comment ?? null },
        updatedAt: FieldValue.serverTimestamp(),
      });
      ctx.audit({ action: `invPurchaseRequest.${i.decision}`, ref: ref.path, reason: i.comment ?? undefined });
      await enqueue(ctx, `pr_decided__${ref.id}__${history.length}`, {
        to: { uids: [pr.createdBy] }, category: 'inv.purchaseRequest',
        title: `Purchase request ${status.replace('_', ' ')}`, body: `${pr.number}${i.comment ? `: ${i.comment}` : ''}`, data: { id: ref.id },
      });
      if (i.decision === 'approve') {
        await enqueue(ctx, `pr_approved__${ref.id}`, {
          to: { perm: 'inv.procure.operate', campusId: pr.campusId }, category: 'inv.purchaseRequest',
          title: 'Purchase request approved', body: `${pr.number} is ready for procurement`, data: { id: ref.id },
        });
      }
      return { id: ref.id, number: pr.number as string };
    },
  }),

  /** Cancelling keeps the request (FRS 10.13); an approved one with ordered quantity cannot be cancelled. */
  prCancel: def({
    name: 'inv.pr.cancel',
    perm: 'inv.pr.request',
    input: z.object({ id, reason: z.string().trim().max(500).nullish() }),
    handler: async (ctx, i) => {
      const { ref, pr } = await loadPr(ctx, i.id);
      if (pr.createdBy !== ctx.uid) throw failed('Only the requester can cancel this request');
      if (!CANCELLABLE.includes(pr.status)) throw failed(`Request is ${pr.status}`);
      if ((pr.lines as Array<{ qtyOrdered: number }>).some((l) => l.qtyOrdered > 0)) throw failed('Part of this request is already ordered');
      ctx.update(ref, { status: 'cancelled', history: [...pr.history, hist(ctx, 'cancel', i.reason)], updatedAt: FieldValue.serverTimestamp() });
      ctx.audit({ action: 'invPurchaseRequest.cancel', ref: ref.path, before: { status: pr.status }, reason: i.reason ?? undefined });
      return { id: ref.id, number: pr.number as string };
    },
  }),
};
