import { FieldValue } from 'firebase-admin/firestore';
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
}): Promise<{ id: string }> {
  const ref = db().collection(`${SCHOOL}/inventoryStores`).doc();
  await ref.set({ description: null, location: null, ...fields, ...audit });
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
