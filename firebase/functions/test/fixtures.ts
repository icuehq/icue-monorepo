import { FieldValue } from 'firebase-admin/firestore';
import { dayTimestamp, todayIST } from '../src/shared/dates';
import { db } from './setup';

/** Documents the client writes directly (`firestore.rules`); the server only reads them, so tests seed them. */
const SCHOOL = 'orgs/8/zones/147/branches/427';
const audit = {
  status: 'active',
  createdBy: '1',
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
};

export async function seedStore(fields: {
  name: string;
  storekeeperIds?: number[];
}): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/inventoryStores`).doc();
  await ref.set({ description: null, location: null, storekeeperIds: [], ...fields, ...audit });
  return { id: ref.id };
}

export async function seedLibrary(fields: { name: string }): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/libraries`).doc();
  await ref.set({
    location: null,
    hours: null,
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
): Promise<string> {
  const ref = db().collection(`${SCHOOL}/inventoryPurchaseRequests`).doc();
  await ref.set({
    number: 'PR/TEST/000001',
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
  options: { discount?: number; tax?: number } = {},
): Promise<string> {
  const ref = db().collection(`${SCHOOL}/inventoryPurchaseOrders`).doc();
  const subtotal = lines.reduce((sum, line) => sum + line.quantityOrdered * line.unitPrice, 0);
  const { discount = 0, tax = 0 } = options;
  await ref.set({
    number: 'PO/TEST/000001',
    purchaseRequestIds: [purchaseRequestId],
    vendorId,
    quotationId: null,
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

/** An opening balance of [quantity] pieces of a quantity-tracked item, as a receipt would leave it. */
export async function seedBalance(storeId: string, itemId: string, quantity: number, unitCost = 0) {
  await db()
    .doc(`${SCHOOL}/inventoryBalances/${storeId}__${itemId}__-__-`)
    .set({
      storeId,
      itemId,
      variantId: null,
      batchNumber: null,
      manufacturingDate: null,
      expiryDate: null,
      quantityAvailable: quantity,
      quantityReserved: 0,
      quantityDamaged: 0,
      quantityExpired: 0,
      totalQuantityReceived: quantity,
      totalQuantityIssued: 0,
      unitCost,
      value: quantity * unitCost,
      isBelowReorderLevel: false,
      earliestExpiryDate: null,
    });
}
