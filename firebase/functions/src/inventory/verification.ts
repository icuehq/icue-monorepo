import { z } from 'zod';
import { todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { defineCallable, failed, id, missing, optionalText } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { Stock } from './stock';

/** Stock verification (FRS 10.21): count a store, review the differences, apply them as adjustments. */

// Known limit: one transaction applies every difference (3 writes each), so a session is capped; narrow by category for larger stores.
const MAX_LINES = 150;
const reason = z.enum(['count_correction', 'missing', 'excess', 'other']);

export const verification = {
  /** Snapshots the expected quantity (`quantityAvailable`) of every balance in scope into `lineItems/{balanceId}`. */
  create: defineCallable({
    name: 'inventory.verification.create',
    permission: 'inventory.stock.operate',
    input: z.object({
      storeId: id,
      categoryIds: z.array(id).max(30).default([]),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const stock = new Stock(context);
      const store = await stock.store(i.storeId);
      let itemIds: Set<string> | null = null;
      if (i.categoryIds.length) {
        const items = await context.transaction.get(
          context.coll('inventoryItems').where('categoryId', 'in', i.categoryIds),
        );
        itemIds = new Set(items.docs.map((item) => item.id));
      }
      const balances = (
        await context.transaction.get(
          context.coll('inventoryBalances').where('storeId', '==', i.storeId),
        )
      ).docs.filter((balance) => !itemIds || itemIds.has(balance.data().itemId));
      if (!balances.length) throw failed('No stock in scope');
      if (balances.length > MAX_LINES)
        throw failed(
          `${balances.length} stock lines in scope; select categories to stay within ${MAX_LINES}`,
        );
      const number = await stock.num('VER');
      const ref = context.newDoc('inventoryVerifications');
      context.set(ref, {
        number,
        storeId: i.storeId,
        storeName: store.name,
        scope: { categoryIds: i.categoryIds },
        remarks: i.remarks ?? null,
        status: 'counting',
        lineCount: balances.length,
        differenceCount: null,
        approval: null,
        adjustmentCount: 0,
        verifiedDate: stock.date,
        ...stock.header(store.campusId),
      });
      for (const snapshot of balances) {
        const expectedBalance = snapshot.data();
        context.set(ref.collection('lineItems').doc(snapshot.id), {
          balanceId: snapshot.id,
          itemId: expectedBalance.itemId,
          variantId: expectedBalance.variantId ?? null,
          batchNumber: expectedBalance.batchNumber ?? null,
          campusId: store.campusId,
          expected: expectedBalance.quantityAvailable,
          counted: null,
          difference: null,
          reason: null,
          remarks: null,
          countedBy: null,
          countedAt: null,
        });
      }
      context.audit({
        action: 'inventoryVerification.create',
        documentPath: ref.path,
        after: { number, lineItems: balances.length },
      });
      return { id: ref.id, number };
    },
  }),

  /** Records counts (and reasons for differences) while the session is open; callable again to recount. */
  count: defineCallable({
    name: 'inventory.verification.count',
    permission: 'inventory.stock.operate',
    input: z.object({
      id,
      lineItems: z
        .array(
          z.object({
            balanceId: id,
            counted: z.number().min(0).max(1_000_000),
            reason: reason.nullish(),
            remarks: z.string().trim().max(500).nullish(),
          }),
        )
        .min(1)
        .max(MAX_LINES),
    }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryVerifications/${i.id}`);
      const session = (await context.transaction.get(ref)).data();
      if (!session) throw missing('Verification');
      context.requireCampus(session.campusId);
      if (session.status !== 'counting') throw failed(`Verification is ${session.status}`);
      const refs = i.lineItems.map((lineItem) =>
        ref.collection('lineItems').doc(lineItem.balanceId),
      );
      const snapshots = await context.transaction.getAll(...refs);
      snapshots.forEach((snapshot, index) => {
        const lineItem = i.lineItems[index];
        if (!snapshot.exists) throw missing('Count line');
        const difference = lineItem.counted - snapshot.data()!.expected;
        context.update(snapshot.ref, {
          counted: lineItem.counted,
          difference,
          reason: difference === 0 ? null : (lineItem.reason ?? null),
          remarks: lineItem.remarks ?? null,
          countedBy: context.uid,
          countedAt: serverTimestamp(),
        });
      });
      context.update(ref, { updatedAt: serverTimestamp() });
      return { id: i.id };
    },
  }),

  /** Closes counting. Every line must be counted and every difference explained; no difference needs no approval. */
  submit: defineCallable({
    name: 'inventory.verification.submit',
    permission: 'inventory.stock.operate',
    input: z.object({ id }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryVerifications/${i.id}`);
      const session = (await context.transaction.get(ref)).data();
      if (!session) throw missing('Verification');
      context.requireCampus(session.campusId);
      if (session.status !== 'counting') throw failed(`Verification is ${session.status}`);
      const lineItems = (await context.transaction.get(ref.collection('lineItems'))).docs.map(
        (lineItem) => lineItem.data(),
      );
      if (lineItems.some((lineItem) => lineItem.counted == null))
        throw failed('Count every line first');
      const differences = lineItems.filter((lineItem) => lineItem.difference !== 0);
      for (const difference of differences) {
        if (!difference.reason) throw failed('Give a reason for every difference');
        if (difference.reason === 'other' && !difference.remarks)
          throw failed('Describe the reason for "other"');
        if (
          (difference.reason === 'missing' && difference.difference > 0) ||
          (difference.reason === 'excess' && difference.difference < 0)
        )
          throw failed('Reason does not match the direction');
      }
      context.update(ref, {
        status: differences.length ? 'submitted' : 'applied',
        differenceCount: differences.length,
        submittedAt: serverTimestamp(),
        submittedBy: context.uid,
        updatedAt: serverTimestamp(),
      });
      if (differences.length) {
        await enqueue(context, `inventory-verification-submitted__${i.id}`, {
          to: { permission: 'inventory.adjustment.approve', campusId: session.campusId },
          category: 'inventory.verification',
          title: 'Stock verification to review',
          body: `${session.number}: ${differences.length} difference(s) in ${session.storeName}.`,
          data: { verificationId: i.id },
        });
      }
      context.audit({
        action: 'inventoryVerification.submit',
        documentPath: ref.path,
        after: { differences: differences.length },
      });
      return { id: i.id, differences: differences.length };
    },
  }),

  /**
   * Approve applies every difference as an adjustment that references the session (the movement ledger is
   * only appended to); reject reopens counting. The delta is the counted-minus-expected difference, so stock
   * moved since the snapshot is kept; a delta that would take a balance below zero fails the whole approval.
   */
  decide: defineCallable({
    name: 'inventory.verification.decide',
    permission: 'inventory.adjustment.approve',
    input: z.object({
      id,
      decision: z.enum(['approve', 'reject']),
      comment: z.string().trim().max(500).nullish(),
    }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryVerifications/${i.id}`);
      const session = (await context.transaction.get(ref)).data();
      if (!session) throw missing('Verification');
      context.requireCampus(session.campusId);
      if (session.status !== 'submitted') throw failed(`Verification is ${session.status}`);
      if (i.decision === 'reject' && !i.comment) throw failed('Give a reason for rejecting');
      const approval = {
        performedBy: context.uid,
        performedAt: serverTimestamp(),
        decision: i.decision,
        comment: i.comment ?? null,
      };
      if (i.decision === 'reject') {
        context.update(ref, { status: 'counting', approval, updatedAt: serverTimestamp() });
        await enqueue(context, `inventory-verification-rejected__${i.id}__${Date.now()}`, {
          to: { uids: [session.createdBy] },
          category: 'inventory.verification',
          title: 'Stock verification sent back',
          body: `${session.number}: ${i.comment}`,
          data: { verificationId: i.id },
        });
        context.audit({
          action: 'inventoryVerification.reject',
          documentPath: ref.path,
          reason: i.comment ?? undefined,
        });
        return { id: i.id, applied: 0 };
      }
      const stock = new Stock(context);
      const differences = (await context.transaction.get(ref.collection('lineItems'))).docs
        .map((lineItem) => lineItem.data())
        .filter((lineItem) => lineItem.difference !== 0);
      let appliedCount = 0;
      for (const difference of differences) {
        const item = await stock.item(difference.itemId, difference.variantId, true);
        const balance = await stock.existing(difference.balanceId, item);
        if (balance.data.unitCost === 0) balance.data.unitCost = item.defaultPrice ?? 0;
        const before = balance.data.quantityAvailable;
        const adj = context.newDoc('inventoryAdjustments');
        stock.move(balance, 'available', difference.difference, {
          type: 'adjust',
          referenceType: 'verification',
          referenceId: i.id,
        });
        context.set(adj, {
          number: `${session.number}/${++appliedCount}`,
          balanceId: difference.balanceId,
          itemId: difference.itemId,
          variantId: difference.variantId,
          storeId: session.storeId,
          batchNumber: difference.batchNumber,
          before,
          delta: difference.difference,
          after: before + difference.difference,
          reason: difference.reason,
          remarks: difference.remarks,
          evidence: null,
          verificationId: i.id,
          approval,
          status: 'completed',
          ...stock.header(session.campusId),
        });
      }
      context.update(ref, {
        status: 'applied',
        approval,
        adjustmentCount: appliedCount,
        appliedAt: serverTimestamp(),
        appliedDate: todayIST(),
        updatedAt: serverTimestamp(),
      });
      context.audit({
        action: 'inventoryVerification.approve',
        documentPath: ref.path,
        after: { adjustments: appliedCount },
        reason: i.comment ?? undefined,
      });
      await stock.finish();
      return { id: i.id, applied: appliedCount };
    },
  }),
};
