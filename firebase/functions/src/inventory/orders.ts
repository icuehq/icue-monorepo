import { type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import {
  Collections,
  orderablePurchaseRequestStatuses,
  PurchaseRequestStatus,
} from '../shared/contracts';
import { dayTimestamp, isoDate } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import {
  defineCallable,
  failed,
  id,
  missing,
  money,
  optionalText,
  text,
  usable,
} from '../shared/masters';
import { lineItemKey, lineKey } from './stock';

/** Purchase orders (FRS 10.16). Quotations and draft POs are client writes (`ProcurementWrites`); receiving is in receiving.ts. */

const roundToCents = (amount: number) => Math.round(amount * 100) / 100;

interface Line {
  itemId: string;
  variantId: string | null;
  quantity: number;
}

/** `subtotal - discount + tax + delivery`; a discount above the subtotal is rejected. */
function totals(
  lineItems: { quantity: number; unitPrice: number }[],
  charges: { discount: number; tax: number; delivery: number },
) {
  const subtotal = roundToCents(
    lineItems.reduce((total, lineItem) => total + lineItem.quantity * lineItem.unitPrice, 0),
  );
  if (charges.discount > subtotal) throw failed('Discount exceeds the subtotal');
  return {
    subtotal,
    total: roundToCents(subtotal - charges.discount + charges.tax + charges.delivery),
  };
}

async function loadPurchaseRequest(
  context: CallableContext,
  purchaseRequestId: string,
): Promise<{ ref: DocumentReference; purchaseRequest: DocumentData }> {
  const ref = context.doc(`${Collections.inventoryPurchaseRequests}/${purchaseRequestId}`);
  const purchaseRequest = (await context.transaction.get(ref)).data();
  if (!purchaseRequest) throw missing('Purchase request');
  context.requireCampus(purchaseRequest.campusId);
  if (!orderablePurchaseRequestStatuses.includes(purchaseRequest.status))
    throw failed(`Request is ${purchaseRequest.status}; it must be approved`);
  return { ref, purchaseRequest };
}

async function loadDoc(
  context: CallableContext,
  path: string,
  what: string,
): Promise<{ ref: DocumentReference; document: DocumentData }> {
  const ref = context.doc(path);
  const documentData = (await context.transaction.get(ref)).data();
  if (!documentData) throw missing(what);
  context.requireCampus(documentData.campusId);
  return { ref, document: documentData };
}

/** Request status follows the ordered quantity of its lines (set by PO issue / cancel). */
function purchaseRequestStatus(lineItems: { quantity: number; quantityOrdered: number }[]) {
  if (lineItems.every((lineItem) => lineItem.quantityOrdered >= lineItem.quantity))
    return PurchaseRequestStatus.ordered;
  return lineItems.some((lineItem) => lineItem.quantityOrdered > 0)
    ? PurchaseRequestStatus.partiallyOrdered
    : PurchaseRequestStatus.approved;
}

/** Moves ordered quantity on the request by [sign] × each PO line (floored at 0) and updates its status. */
function shiftOrdered(
  context: CallableContext,
  ref: DocumentReference,
  purchaseRequest: DocumentData,
  purchaseOrder: DocumentData,
  sign: 1 | -1,
) {
  const lineItems = (
    purchaseRequest.lineItems as {
      itemId: string;
      variantId?: string | null;
      quantity: number;
      quantityOrdered: number;
    }[]
  ).map((lineItem) => {
    const existingLine = (purchaseOrder.lineItems as Line[]).find(
      (orderLine) => lineItemKey(orderLine) === lineItemKey(lineItem),
    );
    return existingLine
      ? {
          ...lineItem,
          quantityOrdered: Math.max(0, lineItem.quantityOrdered + sign * existingLine.quantity),
        }
      : lineItem;
  });
  context.update(ref, {
    lineItems,
    status: purchaseRequestStatus(lineItems),
    updatedAt: serverTimestamp(),
  });
}

export const orders = {
  /** Issuing reserves the ordered quantity on the request (its `quantityOrdered`). */
  purchaseOrderIssue: defineCallable({
    name: 'inventory.purchaseOrder.issue',
    permission: 'inventory.procure.operate',
    input: z.object({ id }),
    handler: async (context, i) => {
      const { ref, document: purchaseOrder } = await loadDoc(
        context,
        `inventoryPurchaseOrders/${i.id}`,
        'Purchase order',
      );
      if (purchaseOrder.status !== 'draft') throw failed(`Order is ${purchaseOrder.status}`);
      const { ref: purchaseRequestRef, purchaseRequest: purchaseRequest } =
        await loadPurchaseRequest(context, purchaseOrder.purchaseRequestIds[0]);
      usable(
        await context.transaction.get(context.doc(`inventoryVendors/${purchaseOrder.vendorId}`)),
        'Vendor',
        false,
      );
      const lineItems = (
        purchaseOrder.lineItems as {
          itemId: string;
          variantId: string | null;
          quantityOrdered: number;
        }[]
      ).map((lineItem) => ({ ...lineItem, quantity: lineItem.quantityOrdered }));
      checkRemaining(purchaseRequest, lineItems);
      shiftOrdered(context, purchaseRequestRef, purchaseRequest, { lineItems }, 1);
      context.update(ref, {
        status: 'issued',
        issuedAt: serverTimestamp(),
        issuedBy: context.uid,
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'inventoryPurchaseOrder.issue',
        documentPath: ref.path,
        before: { status: 'draft' },
        after: { status: 'issued' },
      });
      return { id: ref.id, number: purchaseOrder.number as string };
    },
  }),

  /** Post-issue change (FRS 10.16): header terms and unit prices only, with the previous version kept in `revisions`. */
  purchaseOrderRevise: defineCallable({
    name: 'inventory.purchaseOrder.revise',
    permission: 'inventory.procure.operate',
    input: z.object({
      id,
      reason: z.string().trim().min(1).max(500),
      expectedDate: isoDate.optional(),
      terms: text(2000),
      prices: z
        .array(z.object({ ...lineKey, unitPrice: money }))
        .max(50)
        .default([]),
      discount: money.optional(),
      tax: money.optional(),
      delivery: money.optional(),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const { ref, document: purchaseOrder } = await loadDoc(
        context,
        `inventoryPurchaseOrders/${i.id}`,
        'Purchase order',
      );
      if (!['issued', 'acknowledged'].includes(purchaseOrder.status))
        throw failed(`Order is ${purchaseOrder.status}`);
      const lineItems = (
        purchaseOrder.lineItems as {
          itemId: string;
          variantId: string | null;
          quantityOrdered: number;
          unitPrice: number;
        }[]
      ).map((lineItem) => {
        const priceLine = i.prices.find((price) => lineItemKey(price) === lineItemKey(lineItem));
        return priceLine ? { ...lineItem, unitPrice: priceLine.unitPrice } : lineItem;
      });
      if (
        i.prices.some(
          (price) => !lineItems.some((lineItem) => lineItemKey(lineItem) === lineItemKey(price)),
        )
      )
        throw failed('Price given for an item not on the order');
      const charges = {
        discount: i.discount ?? purchaseOrder.discount,
        tax: i.tax ?? purchaseOrder.tax,
        delivery: i.delivery ?? purchaseOrder.delivery,
      };
      const orderTotals = totals(
        lineItems.map((lineItem) => ({
          quantity: lineItem.quantityOrdered,
          unitPrice: lineItem.unitPrice,
        })),
        charges,
      );
      context.set(ref.collection('revisions').doc(), {
        snapshot: purchaseOrder,
        changedBy: context.uid,
        reason: i.reason,
        performedAt: serverTimestamp(),
      });
      context.update(ref, {
        lineItems,
        ...charges,
        ...orderTotals,
        expectedDate: i.expectedDate ? dayTimestamp(i.expectedDate) : purchaseOrder.expectedDate,
        terms: i.terms === undefined ? purchaseOrder.terms : (i.terms ?? null),
        remarks: i.remarks === undefined ? purchaseOrder.remarks : (i.remarks ?? null),
        revision: purchaseOrder.revision + 1,
        status: 'issued',
        acknowledgement: null,
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'inventoryPurchaseOrder.revise',
        documentPath: ref.path,
        before: { total: purchaseOrder.total },
        after: { total: orderTotals.total },
        reason: i.reason,
      });
      return { id: ref.id, number: purchaseOrder.number as string };
    },
  }),

  purchaseOrderAcknowledge: defineCallable({
    name: 'inventory.purchaseOrder.acknowledge',
    permission: 'inventory.procure.operate',
    input: z.object({ id, vendorRef: text(60), remarks: text(500) }),
    handler: async (context, i) => {
      const { ref, document: purchaseOrder } = await loadDoc(
        context,
        `inventoryPurchaseOrders/${i.id}`,
        'Purchase order',
      );
      if (purchaseOrder.status !== 'issued') throw failed(`Order is ${purchaseOrder.status}`);
      context.update(ref, {
        status: 'acknowledged',
        updatedAt: serverTimestamp(),
        acknowledgement: {
          performedBy: context.uid,
          performedAt: serverTimestamp(),
          vendorRef: i.vendorRef ?? null,
          remarks: i.remarks ?? null,
        },
      });
      context.audit({
        action: 'inventoryPurchaseOrder.acknowledge',
        documentPath: ref.path,
        before: { status: 'issued' },
        after: { status: 'acknowledged' },
      });
      return { id: ref.id, number: purchaseOrder.number as string };
    },
  }),

  /** Cancelled orders keep their record and release the ordered quantity; nothing received yet. */
  purchaseOrderCancel: defineCallable({
    name: 'inventory.purchaseOrder.cancel',
    permission: 'inventory.procure.operate',
    input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
    handler: async (context, i) => {
      const { ref, document: purchaseOrder } = await loadDoc(
        context,
        `inventoryPurchaseOrders/${i.id}`,
        'Purchase order',
      );
      if (!['draft', 'issued', 'acknowledged'].includes(purchaseOrder.status))
        throw failed(`Order is ${purchaseOrder.status}`);
      if (purchaseOrder.status !== 'draft') {
        const purchaseRequestRef = context.doc(
          `${Collections.inventoryPurchaseRequests}/${purchaseOrder.purchaseRequestIds[0]}`,
        );
        const purchaseRequest = (await context.transaction.get(purchaseRequestRef)).data();
        if (purchaseRequest) {
          const lineItems = (
            purchaseOrder.lineItems as {
              itemId: string;
              variantId: string | null;
              quantityOrdered: number;
            }[]
          ).map((lineItem) => ({ ...lineItem, quantity: lineItem.quantityOrdered }));
          shiftOrdered(context, purchaseRequestRef, purchaseRequest, { lineItems }, -1);
        }
      }
      context.update(ref, {
        status: 'cancelled',
        cancelReason: i.reason,
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'inventoryPurchaseOrder.cancel',
        documentPath: ref.path,
        before: { status: purchaseOrder.status },
        reason: i.reason,
      });
      return { id: ref.id, number: purchaseOrder.number as string };
    },
  }),

  /** Closing a PO that is not fully received needs a reason. The unreceived quantity is released back to the request. */
  purchaseOrderClose: defineCallable({
    name: 'inventory.purchaseOrder.close',
    permission: 'inventory.procure.operate',
    input: z.object({ id, reason: text(500) }),
    handler: async (context, i) => {
      const { ref, document: purchaseOrder } = await loadDoc(
        context,
        `inventoryPurchaseOrders/${i.id}`,
        'Purchase order',
      );
      if (
        !['issued', 'acknowledged', 'partially_received', 'fully_received'].includes(
          purchaseOrder.status,
        )
      )
        throw failed(`Order is ${purchaseOrder.status}`);
      if (purchaseOrder.status !== 'fully_received' && !i.reason)
        throw failed('A reason is required to close an order that is not fully received');
      if (purchaseOrder.status !== 'fully_received') {
        const purchaseRequestRef = context.doc(
          `${Collections.inventoryPurchaseRequests}/${purchaseOrder.purchaseRequestIds[0]}`,
        );
        const purchaseRequest = (await context.transaction.get(purchaseRequestRef)).data();
        if (purchaseRequest) {
          // The unreceived remainder goes back to the request so a new order can cover it.
          const remainder = (
            purchaseOrder.lineItems as {
              itemId: string;
              variantId: string | null;
              quantityOrdered: number;
              quantityAccepted: number;
            }[]
          ).map((lineItem) => ({
            ...lineItem,
            quantity: Math.max(0, lineItem.quantityOrdered - lineItem.quantityAccepted),
          }));
          shiftOrdered(context, purchaseRequestRef, purchaseRequest, { lineItems: remainder }, -1);
        }
      }
      context.update(ref, {
        status: 'closed',
        closeReason: i.reason ?? null,
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'inventoryPurchaseOrder.close',
        documentPath: ref.path,
        before: { status: purchaseOrder.status },
        reason: i.reason ?? undefined,
      });
      return { id: ref.id, number: purchaseOrder.number as string };
    },
  }),
};

/** Ordered quantity per line may not exceed what the request still needs. */
function checkRemaining(purchaseRequest: DocumentData, lineItems: Line[]) {
  for (const lineItem of lineItems) {
    const requestLine = (
      purchaseRequest.lineItems as {
        itemId: string;
        variantId?: string | null;
        quantity: number;
        quantityOrdered: number;
      }[]
    ).find((candidate) => lineItemKey(candidate) === lineItemKey(lineItem));
    if (!requestLine) throw failed('Order lines must be lines of the request');
    if (lineItem.quantity > requestLine.quantity - requestLine.quantityOrdered)
      throw failed('Ordered quantity exceeds what the request still needs');
  }
}
