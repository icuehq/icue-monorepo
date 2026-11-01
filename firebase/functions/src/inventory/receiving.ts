import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Ctx } from '../shared/callable';
import { claimUniqueKey, uniqueKeyRef } from '../shared/keys';
import { def, failed, id, missing, note } from '../shared/masters';
import { Batch, day, lineKey, Stock, todayIST, txnFields } from './stock';
import { batch } from './stock-ops';

/** Goods receiving against purchase orders (FRS 10.17) and vendor invoice records (FRS 10.18). */

const money = z.number().min(0).max(100_000_000);
const r2 = (n: number) => Math.round(n * 100) / 100;
const key = (l: { itemId: string; variantId?: string | null }) => `${l.itemId}__${l.variantId ?? '-'}`;
const RECEIVABLE = ['issued', 'acknowledged', 'partially_received'];
// Firestore line items are untyped maps; shape is enforced by the callables that write them.
type PoLine = { itemId: string; variantId: string | null; qtyOrdered: number; qtyReceived: number; qtyAccepted: number; qtyRejected: number; unitPrice: number };

async function loadPo(ctx: Ctx, poId: string) {
  const ref = ctx.doc(`invPurchaseOrders/${poId}`);
  const po = (await ctx.tx.get(ref)).data();
  if (!po) throw missing('Purchase order');
  return { ref, po };
}

/** The request is `completed` once its last live PO is fully received. */
async function completeRequest(ctx: Ctx, prId: string, poId: string) {
  const prRef = ctx.doc(`invPurchaseRequests/${prId}`);
  const pr = (await ctx.tx.get(prRef)).data();
  if (!pr || pr.status !== 'ordered') return;
  const pos = await ctx.tx.get(ctx.coll('invPurchaseOrders').where('prIds', 'array-contains', prId));
  if (pos.docs.some((p) => p.id !== poId && ['issued', 'acknowledged', 'partially_received'].includes(p.data().status))) return;
  ctx.update(prRef, { status: 'completed', updatedAt: FieldValue.serverTimestamp() });
}

export const receiving = {
  /**
   * One delivery against a PO. Accepted quantity enters the store at the PO unit price; rejected quantity
   * is recorded but never becomes stock. ponytail: unit cost excludes PO discount/tax/delivery (no landed-cost split).
   */
  poReceive: def({
    name: 'inv.po.receive',
    perm: 'inv.stock.operate',
    input: z.object({
      ...txnFields,
      poId: id,
      storeId: id,
      deliveryRef: z.string().trim().max(60).nullish(),
      remarks: note,
      lines: z.array(z.object({
        ...lineKey, ...batch,
        qtyAccepted: z.number().min(0).max(1_000_000),
        qtyRejected: z.number().min(0).max(1_000_000).default(0),
        condition: z.string().trim().max(60).nullish(),
        remarks: note,
      })).min(1).max(50),
    }),
    handler: async (ctx, i) => {
      if (new Set(i.lines.map(key)).size !== i.lines.length) throw failed('Each item (and variant) may appear once');
      const { ref: poRef, po } = await loadPo(ctx, i.poId);
      if (!RECEIVABLE.includes(po.status)) throw failed(`Order is ${po.status}`);
      const s = new Stock(ctx, i);
      const store = await s.store(i.storeId);
      if (store.campusId !== po.deliveryCampusId) throw failed('Store is not on the order\'s delivery campus');
      const poLines = (po.lines as PoLine[]).map((l) => ({ ...l }));
      const ref = ctx.newDoc('invReceipts');
      const number = await s.num('GRN');
      const rows = [];
      for (const l of i.lines) {
        const p = poLines.find((x) => key(x) === key(l));
        if (!p) throw failed('Receiving lines must be lines of the order');
        const got = l.qtyAccepted + l.qtyRejected;
        if (got <= 0) throw failed('Each line needs a quantity');
        if (got > p.qtyOrdered - p.qtyAccepted - p.qtyRejected) throw failed('Received quantity exceeds what is still due on the order');
        // Asset units are counted on the order but never enter stock; each is registered individually (`inv-asset-register`).
        const asset = (await ctx.tx.get(ctx.doc(`invItems/${l.itemId}`))).data()?.tracking === 'asset';
        if (asset && !Number.isInteger(l.qtyAccepted + l.qtyRejected)) throw failed('Assets are received in whole units');
        let b: Required<Batch> = { batchNo: null, mfgDate: null, expiryDate: null };
        if (!asset) {
          const item = await s.item(l.itemId, l.variantId);
          b = s.batchOf(item, l);
          if (l.qtyAccepted > 0) {
            s.receive(await s.balance(i.storeId, item, l.variantId, b, true), l.qtyAccepted, 'receive', 'receipt', ref.id, p.unitPrice);
          }
        }
        p.qtyReceived += got;
        p.qtyAccepted += l.qtyAccepted;
        p.qtyRejected += l.qtyRejected;
        rows.push({
          itemId: l.itemId, variantId: l.variantId ?? null, ...b, unitCost: p.unitPrice, condition: l.condition ?? null, remarks: l.remarks ?? null,
          qtyReceived: got, qtyAccepted: l.qtyAccepted, qtyRejected: l.qtyRejected,
          result: l.qtyRejected === 0 ? 'accepted' : l.qtyAccepted === 0 ? 'rejected' : 'partial',
        });
      }
      const accepted = rows.reduce((n, r) => n + r.qtyAccepted, 0);
      const result = rows.every((r) => r.result === 'accepted') ? 'accepted' : accepted === 0 ? 'rejected' : 'partial';
      const full = poLines.every((l) => l.qtyAccepted + l.qtyRejected >= l.qtyOrdered);
      const status = full ? 'fully_received' : 'partially_received';
      ctx.set(ref, {
        number, storeId: i.storeId, source: 'purchase_order', poId: i.poId, poNumber: po.number, vendorId: po.vendorId,
        reference: i.deliveryRef ?? null, remarks: i.remarks ?? null, lines: rows, itemIds: [...new Set(rows.map((r) => r.itemId))],
        attachments: [], inspection: { result, by: ctx.uid, at: FieldValue.serverTimestamp() }, status: 'confirmed', ...s.header(store.campusId),
      });
      ctx.update(poRef, { lines: poLines, status, updatedAt: FieldValue.serverTimestamp() });
      if (full) await completeRequest(ctx, po.prIds[0], i.poId);
      ctx.audit({ action: 'invPurchaseOrder.receive', ref: poRef.path, before: { status: po.status }, after: { status, grn: number, result } });
      await s.finish();
      return { id: ref.id, number, poStatus: status };
    },
  }),
};

const amounts = z.object({ subtotal: money, tax: money.default(0), discount: money.default(0) });
const total = (a: { subtotal: number; tax: number; discount: number }) => {
  if (a.discount > a.subtotal) throw failed('Discount exceeds the subtotal');
  return r2(a.subtotal - a.discount + a.tax);
};

async function loadInvoice(ctx: Ctx, invoiceId: string) {
  const ref = ctx.doc(`invInvoices/${invoiceId}`);
  const d = (await ctx.tx.get(ref)).data();
  if (!d) throw missing('Invoice');
  ctx.requireCampus(d.campusId);
  return { ref, d };
}

export const invoices = {
  /** Record of a vendor's invoice against a PO (and optionally its receipts). Payment is Finance's; this only stores it. */
  invoiceSave: def({
    name: 'inv.invoice.save',
    perm: 'inv.procure.operate',
    input: amounts.extend({
      id: id.optional(),
      poId: id,
      invoiceNo: z.string().trim().min(1).max(60),
      invoiceDate: day,
      dueDate: day.nullish(),
      receiptIds: z.array(id).max(50).default([]),
      remarks: note,
    }),
    handler: async (ctx, i) => {
      const { po } = await loadPo(ctx, i.poId);
      ctx.requireCampus(po.campusId);
      if (['draft', 'cancelled'].includes(po.status)) throw failed(`Order is ${po.status}`);
      if (i.invoiceDate > todayIST()) throw failed('Invoice date is in the future');
      if (i.dueDate && i.dueDate < i.invoiceDate) throw failed('Due date is before the invoice date');
      for (const rid of i.receiptIds) {
        const g = (await ctx.tx.get(ctx.doc(`invReceipts/${rid}`))).data();
        if (g?.poId !== i.poId) throw failed('Receiving reference does not belong to this order');
      }
      const t = total(i);
      const fields = {
        invoiceDate: i.invoiceDate, dueDate: i.dueDate ?? null, receiptIds: i.receiptIds, subtotal: i.subtotal, tax: i.tax,
        discount: i.discount, total: t, outstanding: t, remarks: i.remarks ?? null, updatedAt: FieldValue.serverTimestamp(),
      };
      if (i.id) {
        const { ref, d } = await loadInvoice(ctx, i.id);
        if (d.poId !== i.poId || d.invoiceNo !== i.invoiceNo) throw failed('Order and invoice number cannot change');
        if (d.paymentStatus !== 'unpaid') throw failed(`Invoice is ${d.paymentStatus}`);
        ctx.update(ref, fields);
        ctx.audit({ action: 'invInvoice.update', ref: ref.path, before: { total: d.total }, after: { total: t } });
        return { id: ref.id };
      }
      const ref = ctx.newDoc('invInvoices');
      await claimUniqueKey(ctx, 'invInvoice', `${po.vendorId}__${i.invoiceNo}`, ref.path);
      ctx.set(ref, {
        ...fields, vendorId: po.vendorId, poId: i.poId, poNumber: po.number, invoiceNo: i.invoiceNo, campusId: po.campusId,
        paymentStatus: 'unpaid', paidAmount: 0, payment: null, attachments: [], createdAt: FieldValue.serverTimestamp(), createdBy: ctx.uid,
      });
      ctx.audit({ action: 'invInvoice.create', ref: ref.path, after: { invoiceNo: i.invoiceNo, total: t } });
      return { id: ref.id };
    },
  }),

  /** Records the cumulative amount Finance reports as paid. `overdue` is derived by readers from `dueDate`. */
  invoiceSetPayment: def({
    name: 'inv.invoice.setPayment',
    perm: 'inv.procure.operate',
    input: z.object({ id, paidAmount: money, reference: z.string().trim().max(60).nullish(), paidDate: day.optional() }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadInvoice(ctx, i.id);
      if (d.paymentStatus === 'cancelled') throw failed('Invoice is cancelled');
      if (i.paidAmount > d.total) throw failed('Paid amount exceeds the invoice total');
      const paymentStatus = i.paidAmount >= d.total ? 'paid' : i.paidAmount > 0 ? 'partially_paid' : 'unpaid';
      ctx.update(ref, {
        paidAmount: i.paidAmount, outstanding: r2(d.total - i.paidAmount), paymentStatus,
        payment: { reference: i.reference ?? null, date: i.paidDate ?? todayIST(), by: ctx.uid }, updatedAt: FieldValue.serverTimestamp(),
      });
      ctx.audit({ action: 'invInvoice.setPayment', ref: ref.path, before: { paidAmount: d.paidAmount }, after: { paidAmount: i.paidAmount, paymentStatus } });
      return { id: ref.id, paymentStatus };
    },
  }),

  /** Only an unpaid invoice can be cancelled; its number is released so a corrected entry can reuse it. */
  invoiceCancel: def({
    name: 'inv.invoice.cancel',
    perm: 'inv.procure.operate',
    input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
    handler: async (ctx, i) => {
      const { ref, d } = await loadInvoice(ctx, i.id);
      if (d.paymentStatus !== 'unpaid') throw failed(`Invoice is ${d.paymentStatus}`);
      ctx.update(ref, { paymentStatus: 'cancelled', cancelReason: i.reason, updatedAt: FieldValue.serverTimestamp() });
      ctx.delete(uniqueKeyRef(ctx, 'invInvoice', `${d.vendorId}__${d.invoiceNo}`));
      ctx.audit({ action: 'invInvoice.cancel', ref: ref.path, reason: i.reason });
      return { id: ref.id };
    },
  }),
};
