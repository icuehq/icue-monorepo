import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { serverTimestamp } from '../shared/firestore';
import { defineCallable, failed, id, missing, optionalText } from '../shared/masters';
import {
  assertUniqueLines,
  type Batch,
  lineItemKey,
  lineKey,
  Stock,
  transactionFields,
} from './stock';
import { batch } from './stock-operations';

/** Goods receiving against purchase orders (FRS 10.17). Vendor invoices are client writes. */

const RECEIVABLE = ['issued', 'acknowledged', 'partially_received'];
// Firestore line items are untyped maps; shape is enforced by the callables that write them.
interface PurchaseOrderLine {
  itemId: string;
  variantId: string | null;
  quantityOrdered: number;
  quantityReceived: number;
  quantityAccepted: number;
  quantityRejected: number;
  unitPrice: number;
}

async function loadPurchaseOrder(context: CallableContext, purchaseOrderId: string) {
  const ref = context.doc(`inventoryPurchaseOrders/${purchaseOrderId}`);
  const purchaseOrder = (await context.transaction.get(ref)).data();
  if (!purchaseOrder) throw missing('Purchase order');
  return { ref, purchaseOrder };
}

/** The request is `completed` once its last live PO is fully received. */
async function completeRequest(
  context: CallableContext,
  purchaseRequestId: string,
  purchaseOrderId: string,
) {
  const purchaseRequestRef = context.doc(`inventoryPurchaseRequests/${purchaseRequestId}`);
  const purchaseRequest = (await context.transaction.get(purchaseRequestRef)).data();
  if (!purchaseRequest || purchaseRequest.status !== 'ordered') return;
  const purchaseOrders = await context.transaction.get(
    context
      .coll('inventoryPurchaseOrders')
      .where('purchaseRequestIds', 'array-contains', purchaseRequestId),
  );
  if (
    purchaseOrders.docs.some(
      (purchaseOrder) =>
        purchaseOrder.id !== purchaseOrderId &&
        ['issued', 'acknowledged', 'partially_received'].includes(purchaseOrder.data().status),
    )
  )
    return;
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
      lineItems: z
        .array(
          z.object({
            ...lineKey,
            ...batch,
            quantityAccepted: z.number().min(0).max(1_000_000),
            quantityRejected: z.number().min(0).max(1_000_000).default(0),
            condition: z.string().trim().max(60).nullish(),
            remarks: optionalText,
          }),
        )
        .min(1)
        .max(50),
    }),
    handler: async (context, i) => {
      assertUniqueLines(i.lineItems);
      const { ref: purchaseOrderRef, purchaseOrder: purchaseOrder } = await loadPurchaseOrder(
        context,
        i.purchaseOrderId,
      );
      if (!RECEIVABLE.includes(purchaseOrder.status))
        throw failed(`Order is ${purchaseOrder.status}`);
      const stock = new Stock(context, i);
      const store = await stock.store(i.storeId);
      if (store.campusId !== purchaseOrder.deliveryCampusId)
        throw failed("Store is not on the order's delivery campus");
      const purchaseOrderLines = (purchaseOrder.lineItems as PurchaseOrderLine[]).map(
        (lineItem) => ({ ...lineItem }),
      );
      const ref = context.newDoc('inventoryReceipts');
      const number = await stock.num('GRN');
      const rows = [];
      for (const lineItem of i.lineItems) {
        const orderLine = purchaseOrderLines.find(
          (purchaseOrderLine) => lineItemKey(purchaseOrderLine) === lineItemKey(lineItem),
        );
        if (!orderLine) throw failed('Receiving lines must be lines of the order');
        const got = lineItem.quantityAccepted + lineItem.quantityRejected;
        if (got <= 0) throw failed('Each line needs a quantity');
        // Only accepted units fill the order; rejected ones leave it open for a replacement delivery.
        if (got > orderLine.quantityOrdered - orderLine.quantityAccepted)
          throw failed('Received quantity exceeds what is still due on the order');
        // Asset units are counted on the order but never enter stock; each is registered individually (`inventory-asset-register`).
        const asset =
          (await context.transaction.get(context.doc(`inventoryItems/${lineItem.itemId}`))).data()
            ?.tracking === 'asset';
        if (asset && !Number.isInteger(lineItem.quantityAccepted + lineItem.quantityRejected))
          throw failed('Assets are received in whole units');
        let batch: Required<Batch> = {
          batchNumber: null,
          manufacturingDate: null,
          expiryDate: null,
        };
        if (!asset) {
          const item = await stock.item(lineItem.itemId, lineItem.variantId);
          batch = stock.batchOf(item, lineItem, true);
          if (lineItem.quantityAccepted > 0) {
            stock.receive(
              await stock.balance(i.storeId, item, lineItem.variantId, batch, true),
              lineItem.quantityAccepted,
              'receive',
              'receipt',
              ref.id,
              orderLine.unitPrice,
            );
          }
        }
        orderLine.quantityReceived += got;
        orderLine.quantityAccepted += lineItem.quantityAccepted;
        orderLine.quantityRejected += lineItem.quantityRejected;
        rows.push({
          itemId: lineItem.itemId,
          variantId: lineItem.variantId ?? null,
          ...batch,
          unitCost: orderLine.unitPrice,
          condition: lineItem.condition ?? null,
          remarks: lineItem.remarks ?? null,
          quantityReceived: got,
          quantityAccepted: lineItem.quantityAccepted,
          quantityRejected: lineItem.quantityRejected,
          result:
            lineItem.quantityRejected === 0
              ? 'accepted'
              : lineItem.quantityAccepted === 0
                ? 'rejected'
                : 'partial',
        });
      }
      const accepted = rows.reduce((sum, row) => sum + row.quantityAccepted, 0);
      const result = rows.every((row) => row.result === 'accepted')
        ? 'accepted'
        : accepted === 0
          ? 'rejected'
          : 'partial';
      const full = purchaseOrderLines.every(
        (purchaseOrderLine) =>
          purchaseOrderLine.quantityAccepted >= purchaseOrderLine.quantityOrdered,
      );
      const status = full ? 'fully_received' : 'partially_received';
      context.set(ref, {
        number,
        storeId: i.storeId,
        source: 'purchase_order',
        purchaseOrderId: i.purchaseOrderId,
        purchaseOrderNumber: purchaseOrder.number,
        vendorId: purchaseOrder.vendorId,
        reference: i.deliveryRef ?? null,
        remarks: i.remarks ?? null,
        lineItems: rows,
        itemIds: [...new Set(rows.map((row) => row.itemId))],
        attachments: [],
        inspection: { result, performedBy: context.uid, performedAt: serverTimestamp() },
        status: 'confirmed',
        ...stock.header(store.campusId),
      });
      context.update(purchaseOrderRef, {
        lineItems: purchaseOrderLines,
        status,
        updatedAt: serverTimestamp(),
      });
      if (full)
        await completeRequest(context, purchaseOrder.purchaseRequestIds[0], i.purchaseOrderId);
      context.audit({
        action: 'inventoryPurchaseOrder.receive',
        documentPath: purchaseOrderRef.path,
        before: { status: purchaseOrder.status },
        after: { status, goodsReceiptNumber: number, result },
      });
      await stock.finish();
      return { id: ref.id, number, purchaseOrderStatus: status };
    },
  }),
};
