import '../region';
import { DocumentData, DocumentReference, Timestamp } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { code, defineCallable, failed, id, missing, name, optionalText, saveMaster, defineSetStatus, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { lineKey, positiveQuantity } from './stock';
import { isoDate, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';

/** Vendors (FRS 10.14) and purchase requests (FRS 10.13). Quotations and POs arrive with Inv-4. */

const text = (max: number) => z.string().trim().max(max).nullish();
const price = z.number().min(0).max(100_000_000);
const EDITABLE = ['draft', 'revision_requested'];
const CANCELLABLE = [...EDITABLE, 'pending', 'approved'];

/** Approval history entry; array elements cannot hold server timestamps. */
const hist = (context: CallableContext, action: string, comment?: string | null) => ({
  action, performedBy: context.uid, performedAt: Timestamp.now(), comment: comment ?? null,
});

async function loadPurchaseRequest(context: CallableContext, purchaseRequestId: string): Promise<{ ref: DocumentReference; purchaseRequest: DocumentData }> {
  const ref = context.doc(`inventoryPurchaseRequests/${purchaseRequestId}`);
  const purchaseRequest = (await context.transaction.get(ref)).data();
  if (!purchaseRequest) throw missing('Purchase request');
  context.requireCampus(purchaseRequest.campusId);
  return { ref, purchaseRequest: purchaseRequest };
}

function ownDraft(context: CallableContext, purchaseRequest: DocumentData): void {
  if (purchaseRequest.createdBy !== context.uid) throw failed('Only the requester can change this request');
  if (!EDITABLE.includes(purchaseRequest.status)) throw failed(`Request is ${purchaseRequest.status}`);
}

/** Checks items and variants (any tracking, assets included) and returns the stored lines. */
async function purchaseRequestLines(context: CallableContext, lineItems: Array<{ itemId: string; variantId?: string | null; quantity: number; estimatedPrice: number }>) {
  if (new Set(lineItems.map((requestLine) => `${requestLine.itemId}__${requestLine.variantId ?? '-'}`)).size !== lineItems.length) {
    throw failed('Each item (and variant) may appear once');
  }
  for (const lineItem of lineItems) {
    const item = usable(await context.transaction.get(context.doc(`inventoryItems/${lineItem.itemId}`)), 'Item', false);
    const hasVariants = (item.variantAttrs as string[]).length > 0;
    if (hasVariants !== !!lineItem.variantId) throw failed(hasVariants ? `${item.name} needs a variant` : `${item.name} has no variants`);
    if (lineItem.variantId) usable(await context.transaction.get(context.doc(`inventoryItems/${lineItem.itemId}/variants/${lineItem.variantId}`)), 'Variant', false);
  }
  return lineItems.map((requestLine) => ({ itemId: requestLine.itemId, variantId: requestLine.variantId ?? null, quantity: requestLine.quantity, estimatedPrice: requestLine.estimatedPrice, quantityOrdered: 0 }));
}

async function notifyApprovers(context: CallableContext, purchaseRequestId: string, purchaseRequest: { number: string; campusId: number; purpose: string }, submissionNumber: number) {
  await enqueue(context, `inventory-purchase-request-submitted__${purchaseRequestId}__${submissionNumber}`, {
    to: { permission: 'inventory.purchaseRequest.approve', campusId: purchaseRequest.campusId }, category: 'inventory.purchaseRequest',
    title: 'Purchase request awaiting approval', body: `${purchaseRequest.number}: ${purchaseRequest.purpose}`, data: { id: purchaseRequestId },
  });
}

const header = {
  campusId: z.number().int(),
  departmentId: z.number().int().nullish(),
  requiredDate: isoDate,
  priority: z.enum(['low', 'normal', 'high', 'urgent']).default('normal'),
  purpose: z.string().trim().min(1).max(500),
  remarks: z.string().trim().max(500).nullish(),
  lineItems: z.array(z.object({ ...lineKey, quantity: positiveQuantity, estimatedPrice: price.default(0) })).min(1).max(50),
};

export const procurement = {
  vendorUpsert: defineCallable({
    name: 'inventory.vendor.upsert',
    permission: 'inventory.vendors.manage',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      contactPerson: text(120),
      phone: text(30),
      email: z.union([z.email(), z.literal('')]).nullish(),
      address: optionalText,
      taxNumber: text(40),
      website: text(200),
      categoryIds: z.array(id).max(30).default([]),
      remarks: optionalText,
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'inventoryVendors',
        entityType: 'inventoryVendor',
        id: i.id,
        code: i.code,
        build: async (before) => {
          const cats = [...new Set(i.categoryIds)];
          if (cats.length) {
            const snapshots = await context.transaction.getAll(...cats.map((category) => context.doc(`inventoryCategories/${category}`)));
            if (snapshots.some((snapshot) => !snapshot.exists)) throw failed('Category not found');
          }
          return {
            name: i.name, contactPerson: i.contactPerson ?? null, phone: i.phone ?? null, email: i.email || null,
            address: i.address ?? null, taxNumber: i.taxNumber ?? null, website: i.website ?? null, categoryIds: cats,
            remarks: i.remarks ?? null,
            // Known limit: documents stay empty until uploads exist (files-getUploadPath).
            ...(before ? {} : { documents: [] }),
          };
        },
      }),
  }),
  vendorSetStatus: defineSetStatus('inventory.vendor.setStatus', 'inventory.vendors.manage', 'inventoryVendors', 'inventoryVendor'),

  /** Creates or edits a draft / returned request; `submit` also sends it for approval. */
  purchaseRequestSave: defineCallable({
    name: 'inventory.purchaseRequest.save',
    permission: 'inventory.purchaseRequest.request',
    input: z.object({ id: id.optional(), ...header, submit: z.boolean().default(false) }),
    handler: async (context, i) => {
      if (i.requiredDate < todayIST()) throw failed('Required date is in the past');
      const lineItems = await purchaseRequestLines(context, i.lineItems);
      const fields = {
        departmentId: i.departmentId ?? null, requiredDate: i.requiredDate, priority: i.priority, purpose: i.purpose,
        remarks: i.remarks ?? null, lineItems, itemIds: [...new Set(lineItems.map((lineItem) => lineItem.itemId))],
        total: Math.round(lineItems.reduce((total, lineItem) => total + lineItem.quantity * lineItem.estimatedPrice, 0) * 100) / 100,
      };
      const now = serverTimestamp();
      if (i.id) {
        const { ref, purchaseRequest: purchaseRequest } = await loadPurchaseRequest(context, i.id);
        ownDraft(context, purchaseRequest);
        if (purchaseRequest.campusId !== i.campusId) throw failed('Campus cannot change');
        const history = i.submit ? [...purchaseRequest.history, hist(context, 'submit')] : purchaseRequest.history;
        context.update(ref, { ...fields, ...(i.submit ? { status: 'pending', history } : {}), updatedAt: now });
        context.audit({ action: 'inventoryPurchaseRequest.update', documentPath: ref.path, before: { status: purchaseRequest.status }, after: { status: i.submit ? 'pending' : purchaseRequest.status } });
        if (i.submit) await notifyApprovers(context, ref.id, purchaseRequest as never, history.length);
        return { id: ref.id, number: purchaseRequest.number as string };
      }
      const ref = context.newDoc('inventoryPurchaseRequests');
      const number = await nextNumber(context, 'PR');
      context.set(ref, {
        ...fields, number, campusId: i.campusId, requestedBy: context.access.personErpId ?? null, attachments: [], approval: null,
        status: i.submit ? 'pending' : 'draft', history: i.submit ? [hist(context, 'submit')] : [],
        requestedDate: todayIST(), createdAt: now, createdBy: context.uid, updatedAt: now,
      });
      context.audit({ action: 'inventoryPurchaseRequest.create', documentPath: ref.path, after: { number, status: i.submit ? 'pending' : 'draft' } });
      if (i.submit) await notifyApprovers(context, ref.id, { number, campusId: i.campusId, purpose: i.purpose }, 1);
      return { id: ref.id, number };
    },
  }),

  /** Sends a stored draft (or one returned for revision) for approval. */
  purchaseRequestSubmit: defineCallable({
    name: 'inventory.purchaseRequest.submit',
    permission: 'inventory.purchaseRequest.request',
    input: z.object({ id }),
    handler: async (context, i) => {
      const { ref, purchaseRequest: purchaseRequest } = await loadPurchaseRequest(context, i.id);
      ownDraft(context, purchaseRequest);
      const history = [...purchaseRequest.history, hist(context, 'submit')];
      context.update(ref, { status: 'pending', history, updatedAt: serverTimestamp() });
      context.audit({ action: 'inventoryPurchaseRequest.submit', documentPath: ref.path, before: { status: purchaseRequest.status }, after: { status: 'pending' } });
      await notifyApprovers(context, ref.id, purchaseRequest as never, history.length);
      return { id: ref.id, number: purchaseRequest.number as string };
    },
  }),

  /** FRS 10.13: approval is mandatory before procurement; every decision stays in `history`. */
  purchaseRequestDecide: defineCallable({
    name: 'inventory.purchaseRequest.decide',
    permission: 'inventory.purchaseRequest.approve',
    input: z.object({ id, decision: z.enum(['approve', 'reject', 'revise']), comment: z.string().trim().max(500).nullish() }),
    handler: async (context, i) => {
      const { ref, purchaseRequest: purchaseRequest } = await loadPurchaseRequest(context, i.id);
      if (purchaseRequest.status !== 'pending') throw failed(`Request is ${purchaseRequest.status}`);
      if (i.decision !== 'approve' && !i.comment) throw failed('A comment is required');
      const status = { approve: 'approved', reject: 'rejected', revise: 'revision_requested' }[i.decision];
      const history = [...purchaseRequest.history, hist(context, i.decision, i.comment)];
      context.update(ref, {
        status, history, approval: { performedBy: context.uid, performedAt: serverTimestamp(), decision: i.decision, comment: i.comment ?? null },
        updatedAt: serverTimestamp(),
      });
      context.audit({ action: `inventoryPurchaseRequest.${i.decision}`, documentPath: ref.path, reason: i.comment ?? undefined });
      await enqueue(context, `inventory-purchase-request-decided__${ref.id}__${history.length}`, {
        to: { uids: [purchaseRequest.createdBy] }, category: 'inventory.purchaseRequest',
        title: `Purchase request ${status.replace('_', ' ')}`, body: `${purchaseRequest.number}${i.comment ? `: ${i.comment}` : ''}`, data: { id: ref.id },
      });
      if (i.decision === 'approve') {
        await enqueue(context, `inventory-purchase-request-approved__${ref.id}`, {
          to: { permission: 'inventory.procure.operate', campusId: purchaseRequest.campusId }, category: 'inventory.purchaseRequest',
          title: 'Purchase request approved', body: `${purchaseRequest.number} is ready for procurement`, data: { id: ref.id },
        });
      }
      return { id: ref.id, number: purchaseRequest.number as string };
    },
  }),

  /** Cancelling keeps the request (FRS 10.13); an approved one with ordered quantity cannot be cancelled. */
  purchaseRequestCancel: defineCallable({
    name: 'inventory.purchaseRequest.cancel',
    permission: 'inventory.purchaseRequest.request',
    input: z.object({ id, reason: z.string().trim().max(500).nullish() }),
    handler: async (context, i) => {
      const { ref, purchaseRequest: purchaseRequest } = await loadPurchaseRequest(context, i.id);
      if (purchaseRequest.createdBy !== context.uid) throw failed('Only the requester can cancel this request');
      if (!CANCELLABLE.includes(purchaseRequest.status)) throw failed(`Request is ${purchaseRequest.status}`);
      if ((purchaseRequest.lineItems as Array<{ quantityOrdered: number }>).some((lineItem) => lineItem.quantityOrdered > 0)) throw failed('Part of this request is already ordered');
      context.update(ref, { status: 'cancelled', history: [...purchaseRequest.history, hist(context, 'cancel', i.reason)], updatedAt: serverTimestamp() });
      context.audit({ action: 'inventoryPurchaseRequest.cancel', documentPath: ref.path, before: { status: purchaseRequest.status }, reason: i.reason ?? undefined });
      return { id: ref.id, number: purchaseRequest.number as string };
    },
  }),
};
