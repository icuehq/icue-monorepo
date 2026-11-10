import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import {
  batch,
  lineKey,
  positiveQuantity,
  Stock,
  stockPerson,
  unavailableEntry,
} from '../src/inventory/stock';
import { dayTimestamp, isoDate, timestampDay, todayIST } from '../src/shared/dates';
import { serverTimestamp } from '../src/shared/firestore';
import {
  defineCallable,
  failed,
  id,
  missing,
  money,
  optionalText,
  usable,
} from '../src/shared/masters';
import { enqueue } from '../src/shared/outbox';
import { db } from './setup';

const transactionFields = { date: isoDate.optional() };
const lineItemKey = (lineItem: { itemId?: string; variantId?: string | null }) =>
  `${lineItem.itemId}__${lineItem.variantId ?? '-'}`;
function assertUniqueLines(lineItems: { itemId: string; variantId?: string | null }[]) {
  if (new Set(lineItems.map(lineItemKey)).size !== lineItems.length)
    throw failed('Each item (and variant) may appear once');
}

/** Documents the client writes directly (`firestore.rules`); the server only reads them, so tests seed them. */
const SCHOOL = 'schools/12';
const audit = {
  status: 'active',
  createdBy: '1',
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
};

export async function seedStore(fields: {
  name: string;
  campusId: number;
  storekeeperIds?: number[];
}): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/inventoryStores`).doc();
  await ref.set({ description: null, location: null, storekeeperIds: [], ...fields, ...audit });
  return { id: ref.id };
}

/** Counts written straight to the lines, as the client does (rules tests cover that path). */
export async function seedCount(
  id: string,
  lineItems: { balanceId: string; counted: number; reason?: string; remarks?: string }[],
): Promise<void> {
  for (const lineItem of lineItems) {
    const ref = db().doc(`${SCHOOL}/inventoryVerifications/${id}/lineItems/${lineItem.balanceId}`);
    const expected = (await ref.get()).data()!.expected as number;
    const difference = lineItem.counted - expected;
    await ref.update({
      counted: lineItem.counted,
      difference,
      reason: difference === 0 ? null : (lineItem.reason ?? null),
      remarks: lineItem.remarks ?? null,
      countedBy: '1',
      countedAt: FieldValue.serverTimestamp(),
    });
  }
}

export async function seedLibrary(fields: {
  name: string;
  campusId: number;
}): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/libraries`).doc();
  await ref.set({
    location: null,
    hours: null,
    ...fields,
    ...audit,
  });
  return { id: ref.id };
}

/** A borrowing policy written straight to Firestore (policies are client-written; rules tests cover that path). */
export async function seedLibraryPolicy(fields: {
  libraryId: string;
  campusId?: number;
  memberType: string;
  name: string;
  maxBooks: number;
  loanDays: number;
  maxRenewals: number;
  fineType: string;
  fineAmount?: number;
  graceDays?: number;
  maxFine?: number | null;
  categoryIds?: string[];
}): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/libraryBorrowingPolicies`).doc();
  await ref.set({
    campusId: 31,
    fineAmount: 0,
    graceDays: 0,
    maxFine: null,
    categoryIds: [],
    ...fields,
    ...audit,
  });
  return { id: ref.id };
}

export async function seedLibraryCategory(fields: {
  name: string;
  parentId?: string;
}): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/libraryCategories`).doc();
  await ref.set({ description: null, parentId: null, ...fields, ...audit });
  return { id: ref.id };
}

/** A catalogue title written straight to Firestore (titles are client-written; rules tests cover that path). */
export async function seedLibraryTitle(fields: {
  title: string;
  authors: string[];
  categoryId: string;
  [field: string]: unknown;
}): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/libraryCatalogue`).doc();
  await ref.set({
    subtitle: null,
    publisher: null,
    edition: null,
    year: null,
    language: null,
    classIds: [],
    description: null,
    pages: null,
    shelf: null,
    keywords: [],
    coverPath: null,
    ...Object.fromEntries(Object.entries(fields).filter(([, value]) => value !== undefined)),
    ...audit,
  });
  return { id: ref.id };
}

export async function seedVariant(fields: {
  itemId: string;
  code: string;
  attrs: Record<string, string>;
}): Promise<{ id: string }> {
  const id = fields.code.toLowerCase();
  await db()
    .doc(`${SCHOOL}/inventoryItems/${fields.itemId}/variants/${id}`)
    .set({
      itemId: fields.itemId,
      sku: fields.code,
      attrs: fields.attrs,
      code: fields.code,
      ...audit,
    });
  return { id };
}

/** An approved purchase request, as the client's approval leaves it. */
export async function seedPurchaseRequest(
  lines: { itemId: string; quantity: number; estimatedPrice?: number }[],
  campusId = 31,
): Promise<string> {
  const ref = db().collection(`${SCHOOL}/inventoryPurchaseRequests`).doc();
  await ref.set({
    number: 'PR/TEST/000001',
    campusId,
    status: 'approved',
    purpose: 'Term',
    priority: 'normal',
    remarks: null,
    lineItems: lines.map((line) => ({
      itemId: line.itemId,
      variantId: null,
      quantity: line.quantity,
      estimatedPrice: line.estimatedPrice ?? 0,
      quantityOrdered: 0,
    })),
    itemIds: [...new Set(lines.map((line) => line.itemId))],
    history: [],
    approval: null,
    attachments: [],
    createdBy: 'req',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

/** A final quotation (as the client leaves it); pass `selected` for the one a purchase order may use. */
export async function seedQuotation(
  purchaseRequestId: string,
  vendorId: string,
  lines: { itemId: string; quantity: number; unitPrice: number }[],
  options: { selected?: boolean; validUntil: string },
): Promise<string> {
  const ref = db().collection(`${SCHOOL}/inventoryQuotations`).doc();
  const subtotal = lines.reduce((sum, line) => sum + line.quantity * line.unitPrice, 0);
  await ref.set({
    number: 'QT/TEST/000001',
    purchaseRequestId,
    vendorId,
    campusId: 31,
    status: 'final',
    validUntil: dayTimestamp(options.validUntil),
    quotationDate: dayTimestamp(options.validUntil),
    deliveryDays: null,
    lineItems: lines.map((line) => ({ ...line, variantId: null })),
    discount: 0,
    tax: 0,
    delivery: 0,
    subtotal,
    total: subtotal,
    selected: options.selected ?? false,
    selectionReason: options.selected ? 'best' : null,
    attachments: [],
    createdBy: 'proc',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

/** A draft purchase order (as the client leaves it); lines are `{ itemId, quantityOrdered, unitPrice }`. */
export async function seedPurchaseOrder(
  purchaseRequestId: string,
  vendorId: string,
  lines: { itemId: string; quantityOrdered: number; unitPrice: number }[],
  options: { deliveryCampusId?: number; discount?: number; tax?: number } = {},
): Promise<string> {
  const ref = db().collection(`${SCHOOL}/inventoryPurchaseOrders`).doc();
  const subtotal = lines.reduce((sum, line) => sum + line.quantityOrdered * line.unitPrice, 0);
  const { discount = 0, tax = 0 } = options;
  await ref.set({
    number: 'PO/TEST/000001',
    purchaseRequestIds: [purchaseRequestId],
    vendorId,
    quotationId: null,
    campusId: 31,
    deliveryCampusId: options.deliveryCampusId ?? 31,
    purchaseOrderDate: dayTimestamp(todayIST()),
    expectedDate: dayTimestamp(todayIST()),
    terms: null,
    remarks: null,
    lineItems: lines.map((line) => ({
      ...line,
      variantId: null,
      quantityReceived: 0,
      quantityAccepted: 0,
      quantityRejected: 0,
    })),
    discount,
    tax,
    delivery: 0,
    subtotal,
    total: subtotal - discount + tax,
    status: 'draft',
    acknowledgement: null,
    revision: 0,
    createdBy: 'proc',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

/** Issues a seeded draft order as the client does: reserves its quantities on the request. */
export async function issuePurchaseOrder(id: string): Promise<void> {
  const orderRef = db().doc(`${SCHOOL}/inventoryPurchaseOrders/${id}`);
  const order = (await orderRef.get()).data()!;
  const requestRef = db().doc(`${SCHOOL}/inventoryPurchaseRequests/${order.purchaseRequestIds[0]}`);
  const request = (await requestRef.get()).data()!;
  const lineItems = (request.lineItems as Row[]).map((line) => {
    const ordered = (order.lineItems as Row[]).find(
      (candidate) => lineItemKey(candidate) === lineItemKey(line),
    );
    return ordered
      ? { ...line, quantityOrdered: Number(line.quantityOrdered) + Number(ordered.quantityOrdered) }
      : line;
  });
  const status = lineItems.every((line) => line.quantityOrdered >= line.quantity)
    ? 'ordered'
    : 'partially_ordered';
  await requestRef.update({ lineItems, status });
  await orderRef.update({ status: 'issued', issuedBy: 'proc' });
}

/** Marks units of an issued order as received, as the client's receiving transaction leaves its lines. */
export async function receivePurchaseOrderUnits(
  id: string,
  received: { itemId: string; quantityAccepted: number; quantityRejected: number }[],
): Promise<void> {
  const ref = db().doc(`${SCHOOL}/inventoryPurchaseOrders/${id}`);
  const lineItems = ((await ref.get()).data()!.lineItems as Row[]).map((line) => {
    const units = received.find((candidate) => candidate.itemId === line.itemId);
    return units
      ? {
          ...line,
          quantityReceived: units.quantityAccepted + units.quantityRejected,
          quantityAccepted: units.quantityAccepted,
          quantityRejected: units.quantityRejected,
        }
      : line;
  });
  const full = lineItems.every((line) => line.quantityAccepted >= line.quantityOrdered);
  await ref.update({ lineItems, status: full ? 'fully_received' : 'partially_received' });
}

type Row = Record<string, any>;

const lineItems = <T extends z.ZodType>(lineSchema: T) => z.array(lineSchema).min(1).max(50);

/** Stock seeder for tests: Receive Stock itself is a client transaction (`StockWrites`). */
export const receiveStock = defineCallable({
  name: 'inventory.receipt.confirm',
  permission: 'inventory.stock.operate',
  input: z.object({
    ...transactionFields,
    storeId: id,
    source: z.enum(['opening', 'adjustment', 'department_return', 'person_return', 'other']),
    reference: optionalText,
    remarks: optionalText,
    lineItems: lineItems(
      z.object({
        ...lineKey,
        ...batch,
        quantityAccepted: z.number().min(0).max(1_000_000),
        quantityRejected: z.number().min(0).max(1_000_000).default(0),
        condition: z.string().trim().max(60).nullish(),
        unitCost: money.nullish(),
      }),
    ),
  }),
  handler: async (context, i) => {
    const stockData = new Stock(context, i);
    const store = await stockData.store(i.storeId);
    const ref = context.newDoc('inventoryReceipts');
    const number = await stockData.num('GRN');
    const out = [];
    for (const lineItem of i.lineItems) {
      if (lineItem.quantityAccepted + lineItem.quantityRejected <= 0)
        throw failed('Each line needs a quantity');
      const item = await stockData.item(lineItem.itemId, lineItem.variantId);
      const lineBatch = stockData.batchOf(item, lineItem, true);
      const unitCost = lineItem.unitCost ?? item.defaultPrice ?? 0;
      if (lineItem.quantityAccepted > 0) {
        stockData.receive(
          await stockData.balance(i.storeId, item, lineItem.variantId, lineBatch, true),
          lineItem.quantityAccepted,
          'receive',
          'receipt',
          ref.id,
          unitCost,
        );
      }
      out.push({
        itemId: lineItem.itemId,
        variantId: lineItem.variantId ?? null,
        ...lineBatch,
        unitCost,
        condition: lineItem.condition ?? null,
        quantityReceived: lineItem.quantityAccepted + lineItem.quantityRejected,
        quantityAccepted: lineItem.quantityAccepted,
        quantityRejected: lineItem.quantityRejected,
      });
    }
    context.set(ref, {
      number,
      storeId: i.storeId,
      source: i.source,
      reference: i.reference ?? null,
      remarks: i.remarks ?? null,
      lineItems: out,
      itemIds: [...new Set(out.map((lineItem) => lineItem.itemId))],
      attachments: [],
      status: 'confirmed',
      ...stockData.header(store.campusId),
    });
    context.audit({
      action: 'inventoryReceipt.create',
      documentPath: ref.path,
      after: { number, source: i.source },
    });
    await stockData.finish();
    return { id: ref.id, number };
  },
});

/** An issue request as the client writes and decides it (`StockWrites`); the server only issues against it. */
export async function seedIssueRequest(fields: {
  storeId: string;
  itemId: string;
  quantity: number;
  createdBy: string;
  status?: 'pending' | 'approved' | 'rejected';
}): Promise<string> {
  const status = fields.status ?? 'pending';
  const reference = db().collection(`${SCHOOL}/inventoryIssueRequests`).doc();
  await reference.set({
    number: `ISR/test/${reference.id}`,
    storeId: fields.storeId,
    destination: null,
    purpose: 'Class',
    remarks: null,
    requesterId: null,
    lineItems: [
      {
        itemId: fields.itemId,
        variantId: null,
        quantityRequested: fields.quantity,
        quantityApproved: status === 'approved' ? fields.quantity : null,
        quantityIssued: 0,
      },
    ],
    itemIds: [fields.itemId],
    status,
    approval: status === 'pending' ? null : { performedBy: 'apr', comment: null },
    campusId: 31,
    transactionDate: dayTimestamp(new Date().toISOString().slice(0, 10)),
    createdAt: FieldValue.serverTimestamp(),
    createdBy: fields.createdBy,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return reference.id;
}

/** Issue seeder for tests: issuing stock itself is a client transaction (`StockWrites`). */
export const issueStock = defineCallable({
  name: 'inventory.issue.create',
  permission: 'inventory.stock.operate',
  input: z.object({
    ...transactionFields,
    issueRequestId: id,
    recipient: stockPerson,
    remarks: optionalText,
    lineItems: lineItems(
      z.object({ ...lineKey, quantity: positiveQuantity, balanceId: id.nullish() }),
    ),
  }),
  handler: async (context, i) => {
    const reqRef = context.doc(`inventoryIssueRequests/${i.issueRequestId}`);
    const issueRequest = (await context.transaction.get(reqRef)).data();
    if (!issueRequest) throw missing('Issue request');
    if (issueRequest.status !== 'approved' && issueRequest.status !== 'partially_issued')
      throw failed(`Request is ${issueRequest.status}`);
    const stockData = new Stock(context, i);
    const store = await stockData.store(issueRequest.storeId, true);
    const reqLines = (issueRequest.lineItems as Row[]).map((lineItem) => ({ ...lineItem }));
    const ref = context.newDoc('inventoryIssues');
    const number = await stockData.num('ISS');
    const issued = new Map<string, Record<string, unknown>>();
    for (const lineItem of i.lineItems) {
      const requestLine = reqLines.find(
        (reqLine) => lineItemKey(reqLine) === lineItemKey(lineItem),
      );
      if (!requestLine) throw failed('Item is not on the request');
      if ((requestLine.quantityIssued as number) + lineItem.quantity > requestLine.quantityApproved)
        throw failed('Issue exceeds the approved quantity');
      const item = await stockData.item(lineItem.itemId, lineItem.variantId, true);
      const picks = lineItem.balanceId
        ? [
            {
              bal: await stockData.existing(lineItem.balanceId, item),
              quantity: lineItem.quantity,
            },
          ]
        : await stockData.allocate(
            issueRequest.storeId,
            item,
            lineItem.variantId,
            lineItem.quantity,
          );
      for (const { bal: balance, quantity: quantity } of picks) {
        if (
          balance.data.storeId !== issueRequest.storeId ||
          balance.data.itemId !== lineItem.itemId ||
          (balance.data.variantId ?? null) !== (lineItem.variantId ?? null)
        ) {
          throw failed('Balance does not match the item');
        }
        stockData.move(balance, 'available', -quantity, {
          type: 'issue',
          referenceType: 'issue',
          referenceId: ref.id,
        });
        const row = issued.get(balance.id) ?? {
          itemId: lineItem.itemId,
          variantId: lineItem.variantId ?? null,
          balanceId: balance.id,
          batchNumber: balance.data.batchNumber ?? null,
          manufacturingDate: balance.data.manufacturingDate ?? null,
          expiryDate: balance.data.expiryDate ?? null,
          unitCost: balance.data.unitCost,
          quantity: 0,
          quantityReturned: 0,
        };
        row.quantity = (row.quantity as number) + quantity;
        issued.set(balance.id, row);
      }
      requestLine.quantityIssued = (requestLine.quantityIssued as number) + lineItem.quantity;
    }
    const done = reqLines.every((reqLine) => reqLine.quantityIssued >= reqLine.quantityApproved);
    context.set(ref, {
      number,
      issueRequestId: i.issueRequestId,
      storeId: issueRequest.storeId,
      recipient: i.recipient,
      issuedBy: context.uid,
      remarks: i.remarks ?? null,
      lineItems: [...issued.values()],
      itemIds: [...new Set(i.lineItems.map((lineItem) => lineItem.itemId))],
      acknowledgement: null,
      ...stockData.header(store.campusId),
    });
    context.update(reqRef, {
      lineItems: reqLines,
      status: done ? 'issued' : 'partially_issued',
      updatedAt: serverTimestamp(),
    });
    context.audit({
      action: 'inventoryIssue.create',
      documentPath: ref.path,
      after: { number, issueRequestId: i.issueRequestId },
    });
    await stockData.finish();
    return { id: ref.id, number };
  },
});

/** Transfer seeder for tests: requesting a transfer itself is a client transaction (`StockWrites`). */
export const requestTransfer = defineCallable({
  name: 'inventory.transfer.request',
  permission: 'inventory.stock.operate',
  input: z.object({
    ...transactionFields,
    fromStoreId: id,
    toStoreId: id,
    remarks: optionalText,
    lineItems: lineItems(z.object({ ...lineKey, quantity: positiveQuantity })),
  }),
  handler: async (context, i) => {
    if (i.fromStoreId === i.toStoreId) throw failed('Source and destination must differ');
    assertUniqueLines(i.lineItems);
    const stockData = new Stock(context, i);
    const from = await stockData.store(i.fromStoreId);
    const store = usable(
      await context.transaction.get(context.doc(`inventoryStores/${i.toStoreId}`)),
      'Destination store',
      false,
    );
    for (const lineItem of i.lineItems) await stockData.item(lineItem.itemId, lineItem.variantId);
    const ref = context.newDoc('inventoryTransfers');
    const number = await stockData.num('TRF');
    context.set(ref, {
      number,
      from: { campusId: from.campusId, storeId: i.fromStoreId },
      to: { campusId: store.campusId, storeId: i.toStoreId },
      toCampusId: store.campusId,
      remarks: i.remarks ?? null,
      requested: i.lineItems.map((lineItem) => ({
        itemId: lineItem.itemId,
        variantId: lineItem.variantId ?? null,
        quantity: lineItem.quantity,
      })),
      lineItems: [],
      itemIds: i.lineItems.map((lineItem) => lineItem.itemId),
      status: 'requested',
      ...stockData.header(from.campusId),
    });
    await enqueue(context, `inventory-transfer-requested__${ref.id}`, {
      to: { permission: 'inventory.adjustment.approve', campusId: from.campusId },
      category: 'inventory.transfer',
      title: 'Transfer needs approval',
      body: `${number} is waiting for your approval.`,
      data: { id: ref.id },
    });
    context.audit({
      action: 'inventoryTransfer.request',
      documentPath: ref.path,
      after: { number },
    });
    return { id: ref.id, number };
  },
});

/** Approval seeder for tests: approving a transfer itself is a client transaction (`StockWrites`). */
export const approveTransfer = defineCallable({
  name: 'inventory.transfer.approve',
  permission: 'inventory.adjustment.approve',
  input: z.object({ id }),
  handler: async (context, i) => {
    const ref = context.doc(`inventoryTransfers/${i.id}`);
    const transfer = (await context.transaction.get(ref)).data();
    if (!transfer) throw missing('Transfer');
    context.requireCampus(transfer.from.campusId);
    if (transfer.status !== 'requested') throw failed(`Transfer is ${transfer.status}`);
    context.update(ref, {
      status: 'approved',
      approval: { performedBy: context.uid, performedAt: serverTimestamp() },
      updatedAt: serverTimestamp(),
    });
    context.audit({
      action: 'inventoryTransfer.approve',
      documentPath: ref.path,
      before: { status: transfer.status },
      after: { status: 'approved' },
    });
    return { id: i.id };
  },
});

/** Cancel seeder for tests: cancelling a transfer itself is a client transaction (`StockWrites`). */
export const cancelTransfer = defineCallable({
  name: 'inventory.transfer.cancel',
  permission: 'inventory.stock.operate',
  input: z.object({ id, reason: z.string().trim().min(1).max(500) }),
  handler: async (context, i) => {
    const ref = context.doc(`inventoryTransfers/${i.id}`);
    const transfer = (await context.transaction.get(ref)).data();
    if (!transfer) throw missing('Transfer');
    context.requireCampus(transfer.from.campusId);
    if (transfer.status !== 'requested' && transfer.status !== 'approved')
      throw failed(`Transfer is ${transfer.status}`);
    context.update(ref, {
      status: 'cancelled',
      cancelReason: i.reason,
      cancelledBy: context.uid,
      updatedAt: serverTimestamp(),
    });
    context.audit({
      action: 'inventoryTransfer.cancel',
      documentPath: ref.path,
      before: { status: transfer.status },
      reason: i.reason,
    });
    return { id: i.id };
  },
});

/** Dispatch seeder for tests: dispatching a transfer itself is a client transaction (`StockWrites`). */
export const dispatchTransfer = defineCallable({
  name: 'inventory.transfer.dispatch',
  permission: 'inventory.stock.operate',
  input: z.object({ ...transactionFields, id }),
  handler: async (context, i) => {
    const ref = context.doc(`inventoryTransfers/${i.id}`);
    const transfer = (await context.transaction.get(ref)).data();
    if (!transfer) throw missing('Transfer');
    if (transfer.status !== 'approved') throw failed(`Transfer is ${transfer.status}`);
    const stockData = new Stock(context, i);
    await stockData.store(transfer.from.storeId);
    const out = [];
    for (const lineItem of transfer.requested as {
      itemId: string;
      variantId: string | null;
      quantity: number;
    }[]) {
      const item = await stockData.item(lineItem.itemId, lineItem.variantId, true);
      for (const { bal: balance, quantity: quantity } of await stockData.allocate(
        transfer.from.storeId,
        item,
        lineItem.variantId,
        lineItem.quantity,
      )) {
        stockData.move(balance, 'available', -quantity, {
          type: 'transfer_out',
          referenceType: 'transfer',
          referenceId: i.id,
        });
        out.push({
          itemId: lineItem.itemId,
          variantId: lineItem.variantId,
          balanceId: balance.id,
          batchNumber: balance.data.batchNumber ?? null,
          manufacturingDate: balance.data.manufacturingDate ?? null,
          expiryDate: balance.data.expiryDate ?? null,
          unitCost: balance.data.unitCost,
          quantityDispatched: quantity,
          quantityReceived: 0,
          discrepancy: 0,
        });
      }
    }
    context.update(ref, {
      lineItems: out,
      status: 'dispatched',
      dispatch: {
        performedBy: context.uid,
        date: dayTimestamp(stockData.date),
        performedAt: serverTimestamp(),
      },
      updatedAt: serverTimestamp(),
    });
    context.audit({ action: 'inventoryTransfer.dispatch', documentPath: ref.path });
    await enqueue(context, `inventory-transfer-dispatched__${i.id}`, {
      to: { permission: 'inventory.stock.operate', campusId: transfer.to.campusId },
      category: 'inventory.transfer',
      title: 'Stock on its way',
      body: `${transfer.number} has been dispatched to your store.`,
      data: { id: i.id },
    });
    await stockData.finish();
    return { id: i.id };
  },
});

/** Receipt seeder for tests: receiving a transfer itself is a client transaction (`StockWrites`). */
/**
 * Destination confirms what arrived. Partial receipts keep the transfer open;
 * `final` closes it and records any shortfall as `discrepancy` (never silently lost).
 */
export const receiveTransfer = defineCallable({
  name: 'inventory.transfer.receive',
  permission: 'inventory.stock.operate',
  input: z.object({
    ...transactionFields,
    id,
    final: z.boolean().default(false),
    remarks: optionalText,
    lineItems: z
      .array(z.object({ index: z.number().int().min(0), quantityReceived: positiveQuantity }))
      .max(50)
      .default([]),
  }),
  handler: async (context, i) => {
    const ref = context.doc(`inventoryTransfers/${i.id}`);
    const transfer = (await context.transaction.get(ref)).data();
    if (!transfer) throw missing('Transfer');
    if (transfer.status !== 'dispatched' && transfer.status !== 'partially_received')
      throw failed(`Transfer is ${transfer.status}`);
    if (!i.lineItems.length && !i.final) throw failed('Enter the received quantities');
    const stockData = new Stock(context, i);
    await stockData.store(transfer.to.storeId, true);
    const rows = (transfer.lineItems as Row[]).map((lineItem) => ({ ...lineItem }));
    for (const lineItem of i.lineItems) {
      const row = rows[lineItem.index];
      if (!row) throw failed('Unknown transfer line');
      if (lineItem.quantityReceived > row.quantityDispatched - row.quantityReceived)
        throw failed('Received more than was dispatched');
      const item = await stockData.item(row.itemId, row.variantId, true);
      const balance = await stockData.balance(
        transfer.to.storeId,
        item,
        row.variantId,
        {
          batchNumber: row.batchNumber,
          manufacturingDate: row.manufacturingDate,
          expiryDate: row.expiryDate,
        },
        true,
      );
      stockData.receive(
        balance,
        lineItem.quantityReceived,
        'transfer_in',
        'transfer',
        i.id,
        row.unitCost,
      );
      row.quantityReceived = (row.quantityReceived as number) + lineItem.quantityReceived;
    }
    const complete = rows.every((row) => row.quantityReceived >= row.quantityDispatched);
    const close = complete || i.final;
    if (close) {
      for (const row of rows) {
        row.discrepancy = row.quantityDispatched - row.quantityReceived;
        if (row.discrepancy <= 0) continue;
        // The stock already left the source at dispatch; register the loss so stock and value reconcile.
        const item = await stockData.item(row.itemId, row.variantId, true);
        const sourceBalance = await stockData.existing(row.balanceId, item);
        unavailableEntry(stockData, sourceBalance, row.discrepancy, {
          bucket: null,
          reason: 'lost',
          remarks: `Transfer ${transfer.number} shortfall`,
          referenceType: 'transfer',
          referenceId: i.id,
          status: 'resolved',
          resolution: 'write_off',
        });
      }
    }
    context.update(ref, {
      lineItems: rows,
      status: close ? 'received' : 'partially_received',
      receipt: {
        performedBy: context.uid,
        date: dayTimestamp(stockData.date),
        performedAt: serverTimestamp(),
        remarks: i.remarks ?? null,
      },
      receipts: [
        ...((transfer.receipts as Row[] | undefined) ?? []),
        {
          performedBy: context.uid,
          date: dayTimestamp(stockData.date),
          remarks: i.remarks ?? null,
        },
      ],
      updatedAt: serverTimestamp(),
    });
    context.audit({
      action: 'inventoryTransfer.receive',
      documentPath: ref.path,
      after: { final: close },
    });
    await stockData.finish();
    return { id: i.id };
  },
});

/** Adjustment seeder for tests: adjusting stock itself is a client transaction (`StockWrites`). */
export const adjustStock = defineCallable({
  name: 'inventory.adjustment.create',
  permission: 'inventory.stock.operate',
  input: z.object({
    ...transactionFields,
    ...lineKey,
    ...batch,
    storeId: id,
    delta: z
      .number()
      .min(-1_000_000)
      .max(1_000_000)
      .refine((value) => value !== 0, 'delta must not be 0'),
    reason: z.enum(['count_correction', 'data_entry', 'missing', 'excess', 'other']),
    remarks: z.string().trim().max(500).nullish(),
  }),
  handler: async (context, i) => {
    if (i.reason === 'other' && !i.remarks) throw failed('Describe the reason');
    if ((i.reason === 'missing' && i.delta > 0) || (i.reason === 'excess' && i.delta < 0))
      throw failed('Reason does not match the direction');
    const stockData = new Stock(context, i);
    const store = await stockData.store(i.storeId);
    const item = await stockData.item(i.itemId, i.variantId);
    const balance = await stockData.balance(
      i.storeId,
      item,
      i.variantId,
      stockData.batchOf(item, i),
      i.delta > 0,
    );
    if (balance.data.unitCost === 0) balance.data.unitCost = item.defaultPrice ?? 0;
    const before = balance.data.quantityAvailable;
    const ref = context.newDoc('inventoryAdjustments');
    const number = await stockData.num('ADJ');
    stockData.move(balance, 'available', i.delta, {
      type: 'adjust',
      referenceType: 'adjustment',
      referenceId: ref.id,
    });
    context.set(ref, {
      number,
      balanceId: balance.id,
      itemId: i.itemId,
      variantId: i.variantId ?? null,
      storeId: i.storeId,
      batchNumber: balance.data.batchNumber ?? null,
      before,
      delta: i.delta,
      after: (before as number) + i.delta,
      reason: i.reason,
      remarks: i.remarks ?? null,
      evidence: null,
      approval: null,
      status: 'completed',
      ...stockData.header(store.campusId),
    });
    context.audit({
      action: 'inventoryAdjustment.create',
      documentPath: ref.path,
      before: { quantity: before },
      after: { quantity: (before as number) + i.delta },
      reason: i.reason,
    });
    await stockData.finish();
    return { id: ref.id, number };
  },
});

/** Report seeder for tests: reporting unavailable stock itself is a client transaction (`StockWrites`). */
export const reportUnavailable = defineCallable({
  name: 'inventory.unavailable.report',
  permission: 'inventory.stock.operate',
  input: z.object({
    ...transactionFields,
    ...lineKey,
    ...batch,
    storeId: id,
    quantity: positiveQuantity,
    reason: z.enum(['damaged', 'expired', 'lost']),
    remarks: z.string().trim().min(1).max(500),
  }),
  handler: async (context, i) => {
    const stockData = new Stock(context, i);
    await stockData.store(i.storeId);
    const item = await stockData.item(i.itemId, i.variantId, true);
    const balance = await stockData.balance(
      i.storeId,
      item,
      i.variantId,
      stockData.batchOf(item, i),
      false,
    );
    const ref = context.newDoc('inventoryUnavailableStock');
    const referenceId = ref.id;
    if (
      i.reason === 'expired' &&
      !(balance.data.expiryDate && timestampDay(balance.data.expiryDate) < todayIST())
    )
      throw failed('Batch has not expired');
    const type = i.reason === 'damaged' ? 'damage' : i.reason === 'expired' ? 'expire' : 'writeoff';
    stockData.move(balance, 'available', -i.quantity, {
      type,
      referenceType: 'unavailable',
      referenceId,
    });
    const bucket = i.reason === 'lost' ? null : i.reason;
    if (bucket)
      stockData.move(balance, bucket, i.quantity, {
        type,
        referenceType: 'unavailable',
        referenceId,
      });
    unavailableEntry(stockData, balance, i.quantity, {
      ref,
      bucket,
      reason: i.reason,
      remarks: i.remarks,
      referenceType: 'unavailable',
      referenceId,
      ...(bucket ? {} : { status: 'resolved' as const, resolution: 'write_off' }),
    });
    context.audit({
      action: 'inventoryUnavailableStock.report',
      documentPath: ref.path,
      after: { reason: i.reason, quantity: i.quantity },
    });
    await stockData.finish();
    return { id: ref.id };
  },
});

/** Resolve seeder for tests: resolving unavailable stock itself is a client transaction (`StockWrites`). */
export const resolveUnavailable = defineCallable({
  name: 'inventory.unavailable.resolve',
  permission: 'inventory.stock.operate',
  input: z.object({
    id,
    resolution: z.enum(['restore', 'repair', 'dispose', 'write_off', 'vendor_return', 'other']),
    remarks: z.string().trim().max(500).nullish(),
  }),
  handler: async (context, i) => {
    const ref = context.doc(`inventoryUnavailableStock/${i.id}`);
    const unavailableStock = (await context.transaction.get(ref)).data();
    if (!unavailableStock) throw missing('Entry');
    context.requireCampus(unavailableStock.campusId);
    const canRepair = unavailableStock.status === 'open' && unavailableStock.bucket === 'damaged';
    if (
      (unavailableStock.status !== 'open' && unavailableStock.status !== 'in_repair') ||
      (i.resolution === 'repair' && !canRepair)
    )
      throw failed(`Entry is ${unavailableStock.status}`);
    if (i.resolution === 'other' && !i.remarks) throw failed('Describe the resolution');
    if (i.resolution !== 'repair') {
      const stockData = new Stock(context);
      const item = await stockData.item(unavailableStock.itemId, unavailableStock.variantId, true);
      const balance = await stockData.existing(unavailableStock.balanceId, item);
      const reference = { referenceType: 'unavailable', referenceId: i.id };
      if (i.resolution === 'restore') {
        if (balance.data.expiryDate && timestampDay(balance.data.expiryDate) < todayIST())
          throw failed('Expired batches cannot return to usable stock');
        stockData.move(balance, unavailableStock.bucket, -unavailableStock.quantity, {
          type: 'restore',
          ...reference,
        });
        stockData.move(balance, 'available', unavailableStock.quantity, {
          type: 'restore',
          ...reference,
        });
      } else {
        stockData.move(balance, unavailableStock.bucket, -unavailableStock.quantity, {
          type: 'writeoff',
          ...reference,
        });
      }
      await stockData.finish();
    }
    const repair = i.resolution === 'repair';
    context.update(ref, {
      status: repair ? 'in_repair' : 'resolved',
      resolution: i.resolution,
      resolutionNote: i.remarks ?? null,
      ...(repair ? {} : { resolvedAt: serverTimestamp(), resolvedBy: context.uid }),
      updatedAt: serverTimestamp(),
    });
    context.audit({
      action: 'inventoryUnavailableStock.resolve',
      documentPath: ref.path,
      after: { resolution: i.resolution },
      reason: i.remarks ?? undefined,
    });
    return { id: i.id };
  },
});

/** The person a desk sends to issue. */
export const person = (erpId: number, memberType = 'student') => ({
  memberType,
  personErpId: erpId,
  name: `${memberType} ${erpId}`,
});
