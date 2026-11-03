import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { lineKey, Stock, transactionFields } from '../src/inventory/stock';
import { batch } from '../src/inventory/stock-operations';
import { dayTimestamp } from '../src/shared/dates';
import { defineCallable, failed, id, money, optionalText } from '../src/shared/masters';
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
    departmentId: null,
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
