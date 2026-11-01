import '../region';
import { DocumentData, DocumentReference, FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Ctx } from '../shared/callable';
import { nextNumber } from '../shared/keys';
import { def, failed, id, missing, note, usable } from '../shared/masters';
import { day, lineKey, qty, todayIST } from './stock';

/** Quotations (FRS 10.15) and purchase orders (FRS 10.16). Receiving and invoices are in receiving.ts. */

const money = z.number().min(0).max(100_000_000);
const text = (max: number) => z.string().trim().max(max).nullish();
const OPEN_PR = ['approved', 'partially_ordered'];
const r2 = (n: number) => Math.round(n * 100) / 100;

type Line = { itemId: string; variantId: string | null; qty: number };
const key = (l: { itemId: string; variantId?: string | null }) => `${l.itemId}__${l.variantId ?? '-'}`;

/** `subtotal - discount + tax + delivery`; a discount above the subtotal is rejected. */
function totals(lines: Array<{ qty: number; unitPrice: number }>, h: { discount: number; tax: number; delivery: number }) {
  const subtotal = r2(lines.reduce((n, l) => n + l.qty * l.unitPrice, 0));
  if (h.discount > subtotal) throw failed('Discount exceeds the subtotal');
  return { subtotal, total: r2(subtotal - h.discount + h.tax + h.delivery) };
}

function uniqueLines(ls: Array<{ itemId: string; variantId?: string | null }>) {
  if (new Set(ls.map(key)).size !== ls.length) throw failed('Each item (and variant) may appear once');
}

async function loadPr(ctx: Ctx, prId: string): Promise<{ ref: DocumentReference; pr: DocumentData }> {
  const ref = ctx.doc(`invPurchaseRequests/${prId}`);
  const pr = (await ctx.tx.get(ref)).data();
  if (!pr) throw missing('Purchase request');
  ctx.requireCampus(pr.campusId);
  if (!OPEN_PR.includes(pr.status)) throw failed(`Request is ${pr.status}; it must be approved`);
  return { ref, pr };
}

async function loadDoc(ctx: Ctx, path: string, what: string): Promise<{ ref: DocumentReference; d: DocumentData }> {
  const ref = ctx.doc(path);
  const d = (await ctx.tx.get(ref)).data();
  if (!d) throw missing(what);
  ctx.requireCampus(d.campusId);
  return { ref, d };
}

/** Request status follows the ordered quantity of its lines (set by PO issue / cancel). */
function prStatus(lines: Array<{ qty: number; qtyOrdered: number }>) {
  if (lines.every((l) => l.qtyOrdered >= l.qty)) return 'ordered';
  return lines.some((l) => l.qtyOrdered > 0) ? 'partially_ordered' : 'approved';
}

/** Moves ordered quantity on the request by [sign] × each PO line (floored at 0) and updates its status. */
function shiftOrdered(ctx: Ctx, ref: DocumentReference, pr: DocumentData, po: DocumentData, sign: 1 | -1) {
  const lines = (pr.lines as Array<{ itemId: string; variantId?: string | null; qty: number; qtyOrdered: number }>).map((l) => {
    const o = (po.lines as Line[]).find((x) => key(x) === key(l));
    return o ? { ...l, qtyOrdered: Math.max(0, l.qtyOrdered + sign * o.qty) } : l;
  });
  ctx.update(ref, { lines, status: prStatus(lines), updatedAt: FieldValue.serverTimestamp() });
}

const header = {
  discount: money.default(0),
  tax: money.default(0),
  delivery: money.default(0),
  remarks: z.string().trim().max(500).nullish(),
};

export const orders = {
  /** Draft or final quotation against an approved request; lines must be request lines in the item's stock unit. */
  quotationSave: def({
    name: 'inv.quotation.save',
    perm: 'inv.procure.operate',
    input: z.object({
      id: id.optional(),
      prId: id,
      vendorId: id,
      vendorRef: text(60),
      quotationDate: day.optional(),
      validUntil: day,
      deliveryDays: z.number().int().min(0).max(365).nullish(),
      lines: z.array(z.object({ ...lineKey, qty, unitPrice: money })).min(1).max(50),
      ...header,
      final: z.boolean().default(false),
    }),
    handler: async (ctx, i) => {
      const { pr } = await loadPr(ctx, i.prId);
      usable(await ctx.tx.get(ctx.doc(`invVendors/${i.vendorId}`)), 'Vendor', false);
      uniqueLines(i.lines);
      const prLines = pr.lines as Array<{ itemId: string; variantId?: string | null; qty: number }>;
      for (const l of i.lines) {
        const p = prLines.find((x) => key(x) === key(l));
        if (!p) throw failed('Quotation lines must be lines of the request');
        if (l.qty > p.qty) throw failed('Quoted quantity exceeds the requested quantity');
      }
      const date = i.quotationDate ?? todayIST();
      if (i.validUntil < date) throw failed('Valid until is before the quotation date');
      const lines = i.lines.map((l) => ({ itemId: l.itemId, variantId: l.variantId ?? null, qty: l.qty, unitPrice: l.unitPrice }));
      const t = totals(lines, i);
      const fields = {
        vendorId: i.vendorId, vendorRef: i.vendorRef ?? null, quotationDate: date, validUntil: i.validUntil,
        deliveryDays: i.deliveryDays ?? null, lines, discount: i.discount, tax: i.tax, delivery: i.delivery,
        remarks: i.remarks ?? null, ...t, status: i.final ? 'final' : 'draft', updatedAt: FieldValue.serverTimestamp(),
      };
      if (i.id) {
        const { ref, d } = await loadDoc(ctx, `invQuotations/${i.id}`, 'Quotation');
        if (d.prId !== i.prId) throw failed('Request cannot change');
        if (d.status !== 'draft') throw failed('Only draft quotations can be edited');
        ctx.update(ref, fields);
        ctx.audit({ action: 'invQuotation.update', ref: ref.path, before: { total: d.total }, after: { total: t.total, status: fields.status } });
        return { id: ref.id, number: d.number as string };
      }
      const ref = ctx.newDoc('invQuotations');
      const number = await nextNumber(ctx, 'QT');
      ctx.set(ref, {
        ...fields, number, prId: i.prId, campusId: pr.campusId, selected: false, selectionReason: null, attachments: [],
        createdAt: FieldValue.serverTimestamp(), createdBy: ctx.uid,
      });
      ctx.audit({ action: 'invQuotation.create', ref: ref.path, after: { number, total: t.total, status: fields.status } });
      return { id: ref.id, number };
    },
  }),

  /** One selected quotation per request, with a reason; changing it is blocked while a live PO uses the old one. */
  quotationSelect: def({
    name: 'inv.quotation.select',
    perm: 'inv.procure.operate',
    input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadDoc(ctx, `invQuotations/${i.id}`, 'Quotation');
      await loadPr(ctx, d.prId);
      if (d.status !== 'final') throw failed('Only final quotations can be selected');
      if (d.validUntil < todayIST()) throw failed('Quotation has expired');
      const others = (await ctx.tx.get(ctx.coll('invQuotations').where('prId', '==', d.prId))).docs.filter((o) => o.id !== ref.id && o.data().selected);
      for (const o of others) {
        const live = await ctx.tx.get(ctx.coll('invPurchaseOrders').where('quotationId', '==', o.id));
        if (live.docs.some((p) => p.data().status !== 'cancelled')) throw failed('A purchase order already uses the selected quotation');
        ctx.update(o.ref, { selected: false, selectionReason: null });
      }
      ctx.update(ref, { selected: true, selectionReason: i.reason, updatedAt: FieldValue.serverTimestamp() });
      ctx.audit({ action: 'invQuotation.select', ref: ref.path, reason: i.reason });
      return { id: ref.id, number: d.number as string };
    },
  }),

  /** Draft PO against an approved request; with a quotation the vendor and unit prices come from it. */
  poSave: def({
    name: 'inv.po.save',
    perm: 'inv.procure.operate',
    input: z.object({
      id: id.optional(),
      prId: id,
      quotationId: id.nullish(),
      vendorId: id.nullish(),
      deliveryCampusId: z.number().int().nullish(),
      expectedDate: day,
      terms: text(2000),
      lines: z.array(z.object({ ...lineKey, qtyOrdered: qty, unitPrice: money.default(0) })).min(1).max(50),
      ...header,
    }),
    handler: async (ctx, i) => {
      const { pr } = await loadPr(ctx, i.prId);
      uniqueLines(i.lines);
      let vendorId = i.vendorId;
      let quoted: Array<{ itemId: string; variantId?: string | null; unitPrice: number }> | null = null;
      if (i.quotationId) {
        const q = (await ctx.tx.get(ctx.doc(`invQuotations/${i.quotationId}`))).data();
        if (!q || q.prId !== i.prId) throw failed('Quotation does not belong to this request');
        if (!q.selected) throw failed('Quotation is not the selected one');
        vendorId = q.vendorId;
        quoted = q.lines;
      }
      if (!vendorId) throw failed('Vendor is required');
      usable(await ctx.tx.get(ctx.doc(`invVendors/${vendorId}`)), 'Vendor', false);
      const campus = i.deliveryCampusId ?? pr.campusId;
      ctx.requireCampus(campus);
      if (i.expectedDate < todayIST()) throw failed('Expected delivery date is in the past');
      const lines = i.lines.map((l) => {
        const q = quoted?.find((x) => key(x) === key(l));
        if (quoted && !q) throw failed('Order lines must be lines of the quotation');
        return { itemId: l.itemId, variantId: l.variantId ?? null, qty: l.qtyOrdered, unitPrice: q ? q.unitPrice : l.unitPrice };
      });
      checkRemaining(pr, lines);
      const t = totals(lines, i);
      const stored = lines.map((l) => ({
        itemId: l.itemId, variantId: l.variantId, qtyOrdered: l.qty, qtyReceived: 0, qtyAccepted: 0, qtyRejected: 0, unitPrice: l.unitPrice,
      }));
      const fields = {
        vendorId, quotationId: i.quotationId ?? null, deliveryCampusId: campus, expectedDate: i.expectedDate, terms: i.terms ?? null,
        lines: stored, discount: i.discount, tax: i.tax, delivery: i.delivery, remarks: i.remarks ?? null, ...t,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (i.id) {
        const { ref, d } = await loadDoc(ctx, `invPurchaseOrders/${i.id}`, 'Purchase order');
        if (d.status !== 'draft') throw failed('Only draft orders can be edited');
        if (d.prIds[0] !== i.prId) throw failed('Request cannot change');
        ctx.update(ref, fields);
        ctx.audit({ action: 'invPurchaseOrder.update', ref: ref.path, before: { total: d.total }, after: { total: t.total } });
        return { id: ref.id, number: d.number as string };
      }
      const ref = ctx.newDoc('invPurchaseOrders');
      const number = await nextNumber(ctx, 'PO');
      ctx.set(ref, {
        ...fields, number, prIds: [i.prId], campusId: pr.campusId, poDate: todayIST(), status: 'draft', ack: null, revision: 0,
        createdAt: FieldValue.serverTimestamp(), createdBy: ctx.uid,
      });
      ctx.audit({ action: 'invPurchaseOrder.create', ref: ref.path, after: { number, total: t.total } });
      return { id: ref.id, number };
    },
  }),

  /** Issuing reserves the ordered quantity on the request (its `qtyOrdered`). */
  poIssue: def({
    name: 'inv.po.issue',
    perm: 'inv.procure.operate',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadDoc(ctx, `invPurchaseOrders/${i.id}`, 'Purchase order');
      if (d.status !== 'draft') throw failed(`Order is ${d.status}`);
      const { ref: prRef, pr } = await loadPr(ctx, d.prIds[0]);
      usable(await ctx.tx.get(ctx.doc(`invVendors/${d.vendorId}`)), 'Vendor', false);
      const lines = (d.lines as Array<{ itemId: string; variantId: string | null; qtyOrdered: number }>).map((l) => ({ ...l, qty: l.qtyOrdered }));
      checkRemaining(pr, lines);
      shiftOrdered(ctx, prRef, pr, { lines }, 1);
      ctx.update(ref, { status: 'issued', issuedAt: FieldValue.serverTimestamp(), issuedBy: ctx.uid, updatedAt: FieldValue.serverTimestamp() });
      ctx.audit({ action: 'invPurchaseOrder.issue', ref: ref.path, before: { status: 'draft' }, after: { status: 'issued' } });
      return { id: ref.id, number: d.number as string };
    },
  }),

  /** Post-issue change (FRS 10.16): header terms and unit prices only, with the previous version kept in `revisions`. */
  poRevise: def({
    name: 'inv.po.revise',
    perm: 'inv.procure.operate',
    input: z.object({
      id,
      reason: z.string().trim().min(1).max(500),
      expectedDate: day.optional(),
      terms: text(2000),
      prices: z.array(z.object({ ...lineKey, unitPrice: money })).max(50).default([]),
      discount: money.optional(),
      tax: money.optional(),
      delivery: money.optional(),
      remarks: note,
    }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadDoc(ctx, `invPurchaseOrders/${i.id}`, 'Purchase order');
      if (!['issued', 'acknowledged'].includes(d.status)) throw failed(`Order is ${d.status}`);
      const lines = (d.lines as Array<{ itemId: string; variantId: string | null; qtyOrdered: number; unitPrice: number }>).map((l) => {
        const p = i.prices.find((x) => key(x) === key(l));
        return p ? { ...l, unitPrice: p.unitPrice } : l;
      });
      if (i.prices.some((p) => !lines.some((l) => key(l) === key(p)))) throw failed('Price given for an item not on the order');
      const h = { discount: i.discount ?? d.discount, tax: i.tax ?? d.tax, delivery: i.delivery ?? d.delivery };
      const t = totals(lines.map((l) => ({ qty: l.qtyOrdered, unitPrice: l.unitPrice })), h);
      ctx.set(ref.collection('revisions').doc(), { snapshot: d, changedBy: ctx.uid, reason: i.reason, at: FieldValue.serverTimestamp() });
      ctx.update(ref, {
        lines, ...h, ...t,
        expectedDate: i.expectedDate ?? d.expectedDate, terms: i.terms === undefined ? d.terms : i.terms ?? null,
        remarks: i.remarks === undefined ? d.remarks : i.remarks ?? null,
        revision: d.revision + 1, status: 'issued', ack: null, updatedAt: FieldValue.serverTimestamp(),
      });
      ctx.audit({ action: 'invPurchaseOrder.revise', ref: ref.path, before: { total: d.total }, after: { total: t.total }, reason: i.reason });
      return { id: ref.id, number: d.number as string };
    },
  }),

  poAcknowledge: def({
    name: 'inv.po.acknowledge',
    perm: 'inv.procure.operate',
    input: z.object({ id, vendorRef: text(60), note: text(500) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadDoc(ctx, `invPurchaseOrders/${i.id}`, 'Purchase order');
      if (d.status !== 'issued') throw failed(`Order is ${d.status}`);
      ctx.update(ref, {
        status: 'acknowledged', updatedAt: FieldValue.serverTimestamp(),
        ack: { by: ctx.uid, at: FieldValue.serverTimestamp(), vendorRef: i.vendorRef ?? null, note: i.note ?? null },
      });
      ctx.audit({ action: 'invPurchaseOrder.acknowledge', ref: ref.path, before: { status: 'issued' }, after: { status: 'acknowledged' } });
      return { id: ref.id, number: d.number as string };
    },
  }),

  /** Cancelled orders keep their record and release the ordered quantity; nothing received yet. */
  poCancel: def({
    name: 'inv.po.cancel',
    perm: 'inv.procure.operate',
    input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadDoc(ctx, `invPurchaseOrders/${i.id}`, 'Purchase order');
      if (!['draft', 'issued', 'acknowledged'].includes(d.status)) throw failed(`Order is ${d.status}`);
      if (d.status !== 'draft') {
        const prRef = ctx.doc(`invPurchaseRequests/${d.prIds[0]}`);
        const pr = (await ctx.tx.get(prRef)).data();
        if (pr) {
          const lines = (d.lines as Array<{ itemId: string; variantId: string | null; qtyOrdered: number }>).map((l) => ({ ...l, qty: l.qtyOrdered }));
          shiftOrdered(ctx, prRef, pr, { lines }, -1);
        }
      }
      ctx.update(ref, { status: 'cancelled', cancelReason: i.reason, updatedAt: FieldValue.serverTimestamp() });
      ctx.audit({ action: 'invPurchaseOrder.cancel', ref: ref.path, before: { status: d.status }, reason: i.reason });
      return { id: ref.id, number: d.number as string };
    },
  }),

  /** Closing a PO that is not fully received needs a reason. ponytail: unreceived quantity stays counted as ordered on the request. */
  poClose: def({
    name: 'inv.po.close',
    perm: 'inv.procure.operate',
    input: z.object({ id, reason: text(500) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadDoc(ctx, `invPurchaseOrders/${i.id}`, 'Purchase order');
      if (!['issued', 'acknowledged', 'partially_received', 'fully_received'].includes(d.status)) throw failed(`Order is ${d.status}`);
      if (d.status !== 'fully_received' && !i.reason) throw failed('A reason is required to close an order that is not fully received');
      ctx.update(ref, { status: 'closed', closeReason: i.reason ?? null, updatedAt: FieldValue.serverTimestamp() });
      ctx.audit({ action: 'invPurchaseOrder.close', ref: ref.path, before: { status: d.status }, reason: i.reason ?? undefined });
      return { id: ref.id, number: d.number as string };
    },
  }),
};

/** Ordered quantity per line may not exceed what the request still needs. */
function checkRemaining(pr: DocumentData, lines: Line[]) {
  for (const l of lines) {
    const p = (pr.lines as Array<{ itemId: string; variantId?: string | null; qty: number; qtyOrdered: number }>).find((x) => key(x) === key(l));
    if (!p) throw failed('Order lines must be lines of the request');
    if (l.qty > p.qty - p.qtyOrdered) throw failed('Ordered quantity exceeds what the request still needs');
  }
}
