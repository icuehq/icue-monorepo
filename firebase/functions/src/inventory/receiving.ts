import '../region';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { claimUniqueKey, uniqueKeyRef } from '../shared/keys';
import { defineCallable, failed, id, missing, optionalText } from '../shared/masters';
import { Batch, lineKey, Stock, transactionFields } from './stock';
import { batch } from './stock-operations';
import { isoDate, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';

/** Goods receiving against purchase orders (FRS 10.17) and vendor invoice records (FRS 10.18). */

const money = z.number().min(0).max(100_000_000);
const roundToCents = (amount: number) => Math.round(amount * 100) / 100;
const key = (lineItem: { itemId: string; variantId?: string | null }) => `${lineItem.itemId}__${lineItem.variantId ?? '-'}`;
const RECEIVABLE = ['issued', 'acknowledged', 'partially_received'];
// Firestore line items are untyped maps; shape is enforced by the callables that write them.
type PurchaseOrderLine = { itemId: string; variantId: string | null; quantityOrdered: number; quantityReceived: number; quantityAccepted: number; quantityRejected: number; unitPrice: number };

async function loadPurchaseOrder(context: CallableContext, purchaseOrderId: string) {
  const ref = context.doc(`inventoryPurchaseOrders/${purchaseOrderId}`);
  const purchaseOrder = (await context.transaction.get(ref)).data();
  if (!purchaseOrder) throw missing('Purchase order');
  return { ref, purchaseOrder: purchaseOrder };
}

/** The request is `completed` once its last live PO is fully received. */
async function completeRequest(context: CallableContext, purchaseRequestId: string, purchaseOrderId: string) {
  const purchaseRequestRef = context.doc(`inventoryPurchaseRequests/${purchaseRequestId}`);
  const purchaseRequest = (await context.transaction.get(purchaseRequestRef)).data();
  if (!purchaseRequest || purchaseRequest.status !== 'ordered') return;
  const purchaseOrders = await context.transaction.get(context.coll('inventoryPurchaseOrders').where('purchaseRequestIds', 'array-contains', purchaseRequestId));
  if (purchaseOrders.docs.some((purchaseOrder) => purchaseOrder.id !== purchaseOrderId && ['issued', 'acknowledged', 'partially_received'].includes(purchaseOrder.data().status))) return;
  context.update(purchaseRequestRef, { status: 'completed', updatedAt: serverTimestamp() });
}

export const receiving = {
  /**
   * One delivery against a PO. Accepted quantity enters the store at the PO unit price; rejected quantity
   * is recorded but never becomes stock. Known limit: unit cost excludes PO discount/tax/delivery (no landed-cost split).
   */
  purchaseOrderReceive: defineCallable({
    name: 'inventory.purchaseOrder.receive',
    permission: 'inventory.stock.operate',
    input: z.object({
      ...transactionFields,
      purchaseOrderId: id,
      storeId: id,
      deliveryRef: z.string().trim().max(60).nullish(),
      remarks: optionalText,
      lineItems: z.array(z.object({
        ...lineKey, ...batch,
        quantityAccepted: z.number().min(0).max(1_000_000),
        quantityRejected: z.number().min(0).max(1_000_000).default(0),
        condition: z.string().trim().max(60).nullish(),
        remarks: optionalText,
      })).min(1).max(50),
    }),
    handler: async (context, i) => {
      if (new Set(i.lineItems.map(key)).size !== i.lineItems.length) throw failed('Each item (and variant) may appear once');
      const { ref: purchaseOrderRef, purchaseOrder: purchaseOrder } = await loadPurchaseOrder(context, i.purchaseOrderId);
      if (!RECEIVABLE.includes(purchaseOrder.status)) throw failed(`Order is ${purchaseOrder.status}`);
      const stock = new Stock(context, i);
      const store = await stock.store(i.storeId);
      if (store.campusId !== purchaseOrder.deliveryCampusId) throw failed('Store is not on the order\'s delivery campus');
      const purchaseOrderLines = (purchaseOrder.lineItems as PurchaseOrderLine[]).map((lineItem) => ({ ...lineItem }));
      const ref = context.newDoc('inventoryReceipts');
      const number = await stock.num('GRN');
      const rows = [];
      for (const lineItem of i.lineItems) {
        const orderLine = purchaseOrderLines.find((purchaseOrderLine) => key(purchaseOrderLine) === key(lineItem));
        if (!orderLine) throw failed('Receiving lines must be lines of the order');
        const got = lineItem.quantityAccepted + lineItem.quantityRejected;
        if (got <= 0) throw failed('Each line needs a quantity');
        if (got > orderLine.quantityOrdered - orderLine.quantityAccepted - orderLine.quantityRejected) throw failed('Received quantity exceeds what is still due on the order');
        // Asset units are counted on the order but never enter stock; each is registered individually (`inventory-asset-register`).
        const asset = (await context.transaction.get(context.doc(`inventoryItems/${lineItem.itemId}`))).data()?.tracking === 'asset';
        if (asset && !Number.isInteger(lineItem.quantityAccepted + lineItem.quantityRejected)) throw failed('Assets are received in whole units');
        let batch: Required<Batch> = { batchNumber: null, manufacturingDate: null, expiryDate: null };
        if (!asset) {
          const item = await stock.item(lineItem.itemId, lineItem.variantId);
          batch = stock.batchOf(item, lineItem);
          if (lineItem.quantityAccepted > 0) {
            stock.receive(await stock.balance(i.storeId, item, lineItem.variantId, batch, true), lineItem.quantityAccepted, 'receive', 'receipt', ref.id, orderLine.unitPrice);
          }
        }
        orderLine.quantityReceived += got;
        orderLine.quantityAccepted += lineItem.quantityAccepted;
        orderLine.quantityRejected += lineItem.quantityRejected;
        rows.push({
          itemId: lineItem.itemId, variantId: lineItem.variantId ?? null, ...batch, unitCost: orderLine.unitPrice, condition: lineItem.condition ?? null, remarks: lineItem.remarks ?? null,
          quantityReceived: got, quantityAccepted: lineItem.quantityAccepted, quantityRejected: lineItem.quantityRejected,
          result: lineItem.quantityRejected === 0 ? 'accepted' : lineItem.quantityAccepted === 0 ? 'rejected' : 'partial',
        });
      }
      const accepted = rows.reduce((sum, row) => sum + row.quantityAccepted, 0);
      const result = rows.every((row) => row.result === 'accepted') ? 'accepted' : accepted === 0 ? 'rejected' : 'partial';
      const full = purchaseOrderLines.every((purchaseOrderLine) => purchaseOrderLine.quantityAccepted + purchaseOrderLine.quantityRejected >= purchaseOrderLine.quantityOrdered);
      const status = full ? 'fully_received' : 'partially_received';
      context.set(ref, {
        number, storeId: i.storeId, source: 'purchase_order', purchaseOrderId: i.purchaseOrderId, purchaseOrderNumber: purchaseOrder.number, vendorId: purchaseOrder.vendorId,
        reference: i.deliveryRef ?? null, remarks: i.remarks ?? null, lineItems: rows, itemIds: [...new Set(rows.map((row) => row.itemId))],
        attachments: [], inspection: { result, performedBy: context.uid, performedAt: serverTimestamp() }, status: 'confirmed', ...stock.header(store.campusId),
      });
      context.update(purchaseOrderRef, { lineItems: purchaseOrderLines, status, updatedAt: serverTimestamp() });
      if (full) await completeRequest(context, purchaseOrder.purchaseRequestIds[0], i.purchaseOrderId);
      context.audit({ action: 'inventoryPurchaseOrder.receive', documentPath: purchaseOrderRef.path, before: { status: purchaseOrder.status }, after: { status, goodsReceiptNumber: number, result } });
      await stock.finish();
      return { id: ref.id, number, purchaseOrderStatus: status };
    },
  }),
};

const amounts = z.object({ subtotal: money, tax: money.default(0), discount: money.default(0) });
const total = (invoiceAmounts: { subtotal: number; tax: number; discount: number }) => {
  if (invoiceAmounts.discount > invoiceAmounts.subtotal) throw failed('Discount exceeds the subtotal');
  return roundToCents(invoiceAmounts.subtotal - invoiceAmounts.discount + invoiceAmounts.tax);
};

async function loadInvoice(context: CallableContext, invoiceId: string) {
  const ref = context.doc(`inventoryInvoices/${invoiceId}`);
  const invoice = (await context.transaction.get(ref)).data();
  if (!invoice) throw missing('Invoice');
  context.requireCampus(invoice.campusId);
  return { ref, invoice };
}

export const invoices = {
  /** Record of a vendor's invoice against a PO (and optionally its receipts). Payment is Finance's; this only stores it. */
  invoiceSave: defineCallable({
    name: 'inventory.invoice.save',
    permission: 'inventory.procure.operate',
    input: amounts.extend({
      id: id.optional(),
      purchaseOrderId: id,
      invoiceNumber: z.string().trim().min(1).max(60),
      invoiceDate: isoDate,
      dueDate: isoDate.nullish(),
      receiptIds: z.array(id).max(50).default([]),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const { purchaseOrder: purchaseOrder } = await loadPurchaseOrder(context, i.purchaseOrderId);
      context.requireCampus(purchaseOrder.campusId);
      if (['draft', 'cancelled'].includes(purchaseOrder.status)) throw failed(`Order is ${purchaseOrder.status}`);
      if (i.invoiceDate > todayIST()) throw failed('Invoice date is in the future');
      if (i.dueDate && i.dueDate < i.invoiceDate) throw failed('Due date is before the invoice date');
      for (const rid of i.receiptIds) {
        const receipt = (await context.transaction.get(context.doc(`inventoryReceipts/${rid}`))).data();
        if (receipt?.purchaseOrderId !== i.purchaseOrderId) throw failed('Receiving reference does not belong to this order');
      }
      const invoiceTotal = total(i);
      const fields = {
        invoiceDate: i.invoiceDate, dueDate: i.dueDate ?? null, receiptIds: i.receiptIds, subtotal: i.subtotal, tax: i.tax,
        discount: i.discount, total: invoiceTotal, outstanding: invoiceTotal, remarks: i.remarks ?? null, updatedAt: serverTimestamp(),
      };
      if (i.id) {
        const { ref, invoice } = await loadInvoice(context, i.id);
        if (invoice.purchaseOrderId !== i.purchaseOrderId || invoice.invoiceNumber !== i.invoiceNumber) throw failed('Order and invoice number cannot change');
        if (invoice.paymentStatus !== 'unpaid') throw failed(`Invoice is ${invoice.paymentStatus}`);
        context.update(ref, fields);
        context.audit({ action: 'inventoryInvoice.update', documentPath: ref.path, before: { total: invoice.total }, after: { total: invoiceTotal } });
        return { id: ref.id };
      }
      const ref = context.newDoc('inventoryInvoices');
      await claimUniqueKey(context, 'inventoryInvoice', `${purchaseOrder.vendorId}__${i.invoiceNumber}`, ref.path);
      context.set(ref, {
        ...fields, vendorId: purchaseOrder.vendorId, purchaseOrderId: i.purchaseOrderId, purchaseOrderNumber: purchaseOrder.number, invoiceNumber: i.invoiceNumber, campusId: purchaseOrder.campusId,
        paymentStatus: 'unpaid', paidAmount: 0, payment: null, attachments: [], createdAt: serverTimestamp(), createdBy: context.uid,
      });
      context.audit({ action: 'inventoryInvoice.create', documentPath: ref.path, after: { invoiceNumber: i.invoiceNumber, total: invoiceTotal } });
      return { id: ref.id };
    },
  }),

  /** Records the cumulative amount Finance reports as paid. `overdue` is derived by readers from `dueDate`. */
  invoiceSetPayment: defineCallable({
    name: 'inventory.invoice.setPayment',
    permission: 'inventory.procure.operate',
    input: z.object({ id, paidAmount: money, reference: z.string().trim().max(60).nullish(), paidDate: isoDate.optional() }),
    handler: async (context, i) => {
      const { ref, invoice } = await loadInvoice(context, i.id);
      if (invoice.paymentStatus === 'cancelled') throw failed('Invoice is cancelled');
      if (i.paidAmount > invoice.total) throw failed('Paid amount exceeds the invoice total');
      const paymentStatus = i.paidAmount >= invoice.total ? 'paid' : i.paidAmount > 0 ? 'partially_paid' : 'unpaid';
      context.update(ref, {
        paidAmount: i.paidAmount, outstanding: roundToCents(invoice.total - i.paidAmount), paymentStatus,
        payment: { reference: i.reference ?? null, date: i.paidDate ?? todayIST(), performedBy: context.uid }, updatedAt: serverTimestamp(),
      });
      context.audit({ action: 'inventoryInvoice.setPayment', documentPath: ref.path, before: { paidAmount: invoice.paidAmount }, after: { paidAmount: i.paidAmount, paymentStatus } });
      return { id: ref.id, paymentStatus };
    },
  }),

  /** Only an unpaid invoice can be cancelled; its number is released so a corrected entry can reuse it. */
  invoiceCancel: defineCallable({
    name: 'inventory.invoice.cancel',
    permission: 'inventory.procure.operate',
    input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
    handler: async (context, i) => {
      const { ref, invoice } = await loadInvoice(context, i.id);
      if (invoice.paymentStatus !== 'unpaid') throw failed(`Invoice is ${invoice.paymentStatus}`);
      context.update(ref, { paymentStatus: 'cancelled', cancelReason: i.reason, updatedAt: serverTimestamp() });
      context.delete(uniqueKeyRef(context, 'inventoryInvoice', `${invoice.vendorId}__${invoice.invoiceNumber}`));
      context.audit({ action: 'inventoryInvoice.cancel', documentPath: ref.path, reason: i.reason });
      return { id: ref.id };
    },
  }),
};
