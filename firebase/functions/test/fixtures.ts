import { FieldValue } from 'firebase-admin/firestore';
import { db } from './setup';

/** Documents the client writes directly (`firestore.rules`); the server only reads them, so tests seed them. */
const SCHOOL = 'schools/12';
const audit = {
  status: 'active',
  createdBy: '1',
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
};

export async function seedLibrary(fields: {
  code: string;
  name: string;
  campusId: number;
  staffIds?: number[];
}): Promise<{ id: string }> {
  const id = fields.code.toLowerCase();
  await db()
    .doc(`${SCHOOL}/libraries/${id}`)
    .set({
      description: null,
      location: null,
      staffIds: [],
      contact: null,
      hours: null,
      ...fields,
      ...audit,
    });
  return { id };
}

export async function seedLibraryCategory(fields: {
  code: string;
  name: string;
  parentId?: string;
}): Promise<{ id: string }> {
  const id = fields.code.toLowerCase();
  await db()
    .doc(`${SCHOOL}/libraryCategories/${id}`)
    .set({ description: null, parentId: null, ...fields, ...audit });
  return { id };
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
    departmentId: null,
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
    validUntil: options.validUntil,
    quotationDate: options.validUntil,
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
