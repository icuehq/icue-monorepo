import '../region';
import { z } from 'zod';
import { todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { defineCallable, failed, id, missing, optionalText, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import {
  lineKey,
  stockPerson,
  positiveQuantity,
  Stock,
  transactionFields,
  unavailableEntry,
} from './stock';

/** Stock receiving, issuance, returns, transfers, adjustments, unavailable stock (FRS 10.7–10.12). */

const money = z.number().min(0).max(100_000_000);
export const batch = {
  batchNumber: z.string().trim().min(1).max(40).nullish(),
  manufacturingDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullish(),
  expiryDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullish(),
};
const lineItems = <T extends z.ZodType>(lineSchema: T) => z.array(lineSchema).min(1).max(50);
// Firestore line items are untyped maps; shape is enforced by the callables that write them.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;
const stamp = () => serverTimestamp();
const keyOf = (lineItem: { itemId?: string; variantId?: string | null }) =>
  `${lineItem.itemId}__${lineItem.variantId ?? '-'}`;

function unique(candidates: { itemId: string; variantId?: string | null }[]) {
  if (new Set(candidates.map(keyOf)).size !== candidates.length)
    throw failed('Each item (and variant) may appear once');
}

export const stock = {
  /** FRS 10.7. PO-linked receiving is `inventory.purchaseOrder.receive` (receiving.ts). */
  receiptConfirm: defineCallable({
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
        const lineBatch = stockData.batchOf(item, lineItem);
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
  }),

  /** FRS 10.8 steps 1–2. */
  issueRequestSubmit: defineCallable({
    name: 'inventory.issueRequest.submit',
    permission: 'inventory.issue.request',
    input: z.object({
      storeId: id,
      departmentId: z.number().int().nullish(),
      destination: optionalText,
      purpose: z.string().trim().min(1).max(500),
      remarks: optionalText,
      lineItems: lineItems(z.object({ ...lineKey, quantity: positiveQuantity })),
    }),
    handler: async (context, i) => {
      unique(i.lineItems);
      const stockData = new Stock(context);
      const store = await stockData.store(i.storeId);
      for (const lineItem of i.lineItems) await stockData.item(lineItem.itemId, lineItem.variantId);
      const ref = context.newDoc('inventoryIssueRequests');
      const number = await stockData.num('ISR');
      context.set(ref, {
        number,
        storeId: i.storeId,
        departmentId: i.departmentId ?? null,
        destination: i.destination ?? null,
        purpose: i.purpose,
        remarks: i.remarks ?? null,
        requesterId: context.access.personErpId ?? null,
        lineItems: i.lineItems.map((lineItem) => ({
          itemId: lineItem.itemId,
          variantId: lineItem.variantId ?? null,
          quantityRequested: lineItem.quantity,
          quantityApproved: null,
          quantityIssued: 0,
        })),
        itemIds: i.lineItems.map((lineItem) => lineItem.itemId),
        status: 'pending',
        approval: null,
        ...stockData.header(store.campusId),
      });
      context.audit({
        action: 'inventoryIssueRequest.create',
        documentPath: ref.path,
        after: { number },
      });
      await enqueue(context, `inventory-issue-request-submitted__${ref.id}`, {
        to: { permission: 'inventory.issue.approve', campusId: store.campusId },
        category: 'inventory.issueRequest',
        title: 'Issue request awaiting approval',
        body: `${number}: ${i.purpose}`,
        data: { id: ref.id },
      });
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.8 step 3: one approval level; approved ≤ available now, re-checked at issuance. */
  issueRequestDecide: defineCallable({
    name: 'inventory.issueRequest.decide',
    permission: 'inventory.issue.approve',
    input: z.object({
      id,
      decision: z.enum(['approve', 'reject']),
      lineItems: z
        .array(
          z.object({
            index: z.number().int().min(0),
            quantityApproved: z.number().min(0).max(1_000_000),
          }),
        )
        .max(50)
        .default([]),
      comment: optionalText,
    }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryIssueRequests/${i.id}`);
      const issueRequest = (await context.transaction.get(ref)).data();
      if (!issueRequest) throw missing('Issue request');
      context.requireCampus(issueRequest.campusId);
      if (issueRequest.status !== 'pending')
        throw failed(`Request is already ${issueRequest.status}`);
      const reqLines = issueRequest.lineItems as Row[];
      let patch: Record<string, unknown>;
      if (i.decision === 'reject') {
        if (!i.comment) throw failed('A reason is required to reject');
        patch = { status: 'rejected' };
      } else {
        const stockData = new Stock(context);
        const over = new Map(
          i.lineItems.map((lineItem) => [lineItem.index, lineItem.quantityApproved]),
        );
        const out = [];
        for (const [index, lineItem] of reqLines.entries()) {
          const approved = over.get(index) ?? lineItem.quantityRequested;
          if (approved > lineItem.quantityRequested)
            throw failed('Approved quantity exceeds the request');
          if (
            approved >
            (await stockData.available(issueRequest.storeId, lineItem.itemId, lineItem.variantId))
          )
            throw failed('Approved quantity exceeds available stock');
          out.push({ ...lineItem, quantityApproved: approved });
        }
        if (!out.some((lineItem) => (lineItem.quantityApproved as number) > 0))
          throw failed('Nothing approved; reject the request instead');
        patch = { status: 'approved', lineItems: out };
      }
      context.update(ref, {
        ...patch,
        approval: { performedBy: context.uid, performedAt: stamp(), comment: i.comment ?? null },
        updatedAt: stamp(),
      });
      context.audit({
        action: `inventoryIssueRequest.${i.decision}`,
        documentPath: ref.path,
        reason: i.comment ?? undefined,
      });
      await enqueue(context, `inventory-issue-request-decided__${i.id}`, {
        to: { uids: [issueRequest.createdBy] },
        category: 'inventory.issueRequest',
        title: `Issue request ${i.decision === 'approve' ? 'approved' : 'rejected'}`,
        body: issueRequest.number,
        data: { id: i.id },
      });
      return { id: i.id };
    },
  }),

  /** FRS 10.8 step 4. Without `balanceId` a line is allocated first-expiry-first-out. */
  issueCreate: defineCallable({
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
        const requestLine = reqLines.find((reqLine) => keyOf(reqLine) === keyOf(lineItem));
        if (!requestLine) throw failed('Item is not on the request');
        if (requestLine.quantityIssued + lineItem.quantity > requestLine.quantityApproved)
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
        requestLine.quantityIssued += lineItem.quantity;
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
        updatedAt: stamp(),
      });
      context.audit({
        action: 'inventoryIssue.create',
        documentPath: ref.path,
        after: { number, issueRequestId: i.issueRequestId },
      });
      await stockData.finish();
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.8 step 5. */
  issueAcknowledge: defineCallable({
    name: 'inventory.issue.acknowledge',
    permission: 'inventory.stock.operate',
    input: z.object({ id, remarks: optionalText }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryIssues/${i.id}`);
      const issue = (await context.transaction.get(ref)).data();
      if (!issue) throw missing('Issue');
      context.requireCampus(issue.campusId);
      if (issue.acknowledgement) throw failed('Already acknowledged');
      context.update(ref, {
        acknowledgement: {
          performedBy: context.uid,
          performedAt: stamp(),
          remarks: i.remarks ?? null,
        },
        updatedAt: stamp(),
      });
      context.audit({ action: 'inventoryIssue.acknowledge', documentPath: ref.path });
      return { id: i.id };
    },
  }),

  /** FRS 10.9: returned ≤ outstanding per issue line; damaged goes to the unavailable register. */
  returnCreate: defineCallable({
    name: 'inventory.return.create',
    permission: 'inventory.stock.operate',
    input: z.object({
      ...transactionFields,
      issueId: id,
      storeId: id.nullish(),
      returnedBy: stockPerson,
      remarks: optionalText,
      lineItems: lineItems(
        z.object({
          balanceId: id,
          quantityUsable: z.number().min(0).max(1_000_000),
          quantityDamaged: z.number().min(0).max(1_000_000).default(0),
        }),
      ),
    }),
    handler: async (context, i) => {
      const issueRef = context.doc(`inventoryIssues/${i.issueId}`);
      const issue = (await context.transaction.get(issueRef)).data();
      if (!issue) throw missing('Issue');
      const stockData = new Stock(context, i);
      const dest = i.storeId ?? issue.storeId;
      const store = await stockData.store(dest);
      const issueLines = (issue.lineItems as Row[]).map((lineItem) => ({ ...lineItem }));
      const ref = context.newDoc('inventoryReturns');
      const number = await stockData.num('RET');
      const out = [];
      for (const lineItem of i.lineItems) {
        const issueLine = issueLines.find(
          (issueLine) => issueLine.balanceId === lineItem.balanceId,
        );
        const quantity = lineItem.quantityUsable + lineItem.quantityDamaged;
        if (!issueLine) throw failed('Line is not on the issue');
        if (quantity <= 0) throw failed('Each line needs a quantity');
        if (quantity > issueLine.quantity - issueLine.quantityReturned)
          throw failed(
            `Only ${issueLine.quantity - issueLine.quantityReturned} outstanding for this line`,
          );
        issueLine.quantityReturned += quantity;
        const item = await stockData.item(issueLine.itemId, issueLine.variantId, true);
        const balance = await stockData.balance(
          dest,
          item,
          issueLine.variantId,
          {
            batchNumber: issueLine.batchNumber,
            manufacturingDate: issueLine.manufacturingDate,
            expiryDate: issueLine.expiryDate,
          },
          true,
        );
        if (balance.data.unitCost === 0) balance.data.unitCost = issueLine.unitCost;
        if (lineItem.quantityUsable > 0)
          stockData.move(balance, 'available', lineItem.quantityUsable, {
            type: 'return',
            referenceType: 'return',
            referenceId: ref.id,
          });
        if (lineItem.quantityDamaged > 0) {
          stockData.move(balance, 'damaged', lineItem.quantityDamaged, {
            type: 'return',
            referenceType: 'return',
            referenceId: ref.id,
          });
          unavailableEntry(stockData, balance, lineItem.quantityDamaged, {
            bucket: 'damaged',
            reason: 'damaged_return',
            referenceType: 'return',
            referenceId: ref.id,
          });
        }
        out.push({
          balanceId: balance.id,
          itemId: issueLine.itemId,
          variantId: issueLine.variantId,
          quantityUsable: lineItem.quantityUsable,
          quantityDamaged: lineItem.quantityDamaged,
        });
      }
      context.set(ref, {
        number,
        issueId: i.issueId,
        storeId: dest,
        returnedBy: i.returnedBy,
        remarks: i.remarks ?? null,
        lineItems: out,
        inspection: { performedBy: context.uid, performedAt: stamp() },
        ...stockData.header(store.campusId),
      });
      context.update(issueRef, { lineItems: issueLines, updatedAt: stamp() });
      context.audit({
        action: 'inventoryReturn.create',
        documentPath: ref.path,
        after: { number, issueId: i.issueId },
      });
      await stockData.finish();
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.10 step 1. */
  transferRequest: defineCallable({
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
      unique(i.lineItems);
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
      context.audit({
        action: 'inventoryTransfer.request',
        documentPath: ref.path,
        after: { number },
      });
      return { id: ref.id, number };
    },
  }),

  /** Dispatch reduces the source (first-expiry-first-out); the stock stays in transit until received. */
  transferDispatch: defineCallable({
    name: 'inventory.transfer.dispatch',
    permission: 'inventory.stock.operate',
    input: z.object({ ...transactionFields, id }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryTransfers/${i.id}`);
      const transfer = (await context.transaction.get(ref)).data();
      if (!transfer) throw missing('Transfer');
      if (transfer.status !== 'requested') throw failed(`Transfer is ${transfer.status}`);
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
        dispatch: { performedBy: context.uid, date: stockData.date, performedAt: stamp() },
        updatedAt: stamp(),
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
  }),

  /**
   * Destination confirms what arrived. Partial receipts keep the transfer open;
   * `final` closes it and records any shortfall as `discrepancy` (never silently lost).
   */
  transferReceive: defineCallable({
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
        row.quantityReceived += lineItem.quantityReceived;
      }
      const complete = rows.every((row) => row.quantityReceived >= row.quantityDispatched);
      const close = complete || i.final;
      if (close)
        for (const row of rows) row.discrepancy = row.quantityDispatched - row.quantityReceived;
      context.update(ref, {
        lineItems: rows,
        status: close ? 'received' : 'partially_received',
        receipt: {
          performedBy: context.uid,
          date: stockData.date,
          performedAt: stamp(),
          remarks: i.remarks ?? null,
        },
        updatedAt: stamp(),
      });
      context.audit({
        action: 'inventoryTransfer.receive',
        documentPath: ref.path,
        after: { final: close },
      });
      await stockData.finish();
      return { id: i.id };
    },
  }),

  /**
   * FRS 10.11. Applies at once (approval for count-driven adjustments arrives with Inv-7).
   * Damage and expiry are reported under unavailable stock, not here.
   */
  adjustmentCreate: defineCallable({
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
        after: before + i.delta,
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
        after: { quantity: before + i.delta },
        reason: i.reason,
      });
      await stockData.finish();
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.12: moves usable stock out of `quantityAvailable` into a register entry. */
  unavailableReport: defineCallable({
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
        !(balance.data.expiryDate && balance.data.expiryDate <= todayIST())
      )
        throw failed('Batch has not expired');
      const type =
        i.reason === 'damaged' ? 'damage' : i.reason === 'expired' ? 'expire' : 'writeoff';
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
  }),

  unavailableResolve: defineCallable({
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
        const item = await stockData.item(
          unavailableStock.itemId,
          unavailableStock.variantId,
          true,
        );
        const balance = await stockData.existing(unavailableStock.balanceId, item);
        const reference = { referenceType: 'unavailable', referenceId: i.id };
        if (i.resolution === 'restore') {
          if (balance.data.expiryDate && balance.data.expiryDate < todayIST())
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
        ...(repair ? {} : { resolvedAt: stamp(), resolvedBy: context.uid }),
        updatedAt: stamp(),
      });
      context.audit({
        action: 'inventoryUnavailableStock.resolve',
        documentPath: ref.path,
        after: { resolution: i.resolution },
        reason: i.remarks ?? undefined,
      });
      return { id: i.id };
    },
  }),
};
