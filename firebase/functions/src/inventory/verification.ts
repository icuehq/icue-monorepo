import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { def, failed, id, missing, note } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { Stock, todayIST } from './stock';

/** Stock verification (FRS 10.21): count a store, review the differences, apply them as adjustments. */

// ponytail: one transaction applies every difference (3 writes each), so a session is capped; narrow by category for larger stores.
const MAX_LINES = 150;
const stamp = () => FieldValue.serverTimestamp();
const reason = z.enum(['count_correction', 'missing', 'excess', 'other']);

export const verification = {
  /** Snapshots the expected quantity (`qtyAvailable`) of every balance in scope into `lines/{balanceId}`. */
  create: def({
    name: 'inv.verification.create',
    perm: 'inv.stock.operate',
    input: z.object({ storeId: id, categoryIds: z.array(id).max(30).default([]), remarks: note }),
    handler: async (ctx, i) => {
      const s = new Stock(ctx);
      const store = await s.store(i.storeId);
      let itemIds: Set<string> | null = null;
      if (i.categoryIds.length) {
        const items = await ctx.tx.get(ctx.coll('invItems').where('categoryId', 'in', i.categoryIds));
        itemIds = new Set(items.docs.map((d) => d.id));
      }
      const bals = (await ctx.tx.get(ctx.coll('invBalances').where('storeId', '==', i.storeId))).docs
        .filter((d) => !itemIds || itemIds.has(d.data().itemId));
      if (!bals.length) throw failed('No stock in scope');
      if (bals.length > MAX_LINES) throw failed(`${bals.length} stock lines in scope; select categories to stay within ${MAX_LINES}`);
      const number = await s.num('VER');
      const ref = ctx.newDoc('invVerifications');
      ctx.set(ref, {
        number, storeId: i.storeId, storeName: store.name, scope: { categoryIds: i.categoryIds }, remarks: i.remarks ?? null,
        status: 'counting', lineCount: bals.length, diffCount: null, approval: null, adjustmentCount: 0,
        verifiedDate: s.date, ...s.header(store.campusId),
      });
      for (const b of bals) {
        const d = b.data();
        ctx.set(ref.collection('lines').doc(b.id), {
          balanceId: b.id, itemId: d.itemId, variantId: d.variantId ?? null, batchNo: d.batchNo ?? null, campusId: store.campusId,
          expected: d.qtyAvailable, counted: null, diff: null, reason: null, note: null, countedBy: null, countedAt: null,
        });
      }
      ctx.audit({ action: 'invVerification.create', ref: ref.path, after: { number, lines: bals.length } });
      return { id: ref.id, number };
    },
  }),

  /** Records counts (and reasons for differences) while the session is open; callable again to recount. */
  count: def({
    name: 'inv.verification.count',
    perm: 'inv.stock.operate',
    input: z.object({
      id,
      lines: z.array(z.object({ balanceId: id, counted: z.number().min(0).max(1_000_000), reason: reason.nullish(), note: z.string().trim().max(500).nullish() })).min(1).max(MAX_LINES),
    }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invVerifications/${i.id}`);
      const v = (await ctx.tx.get(ref)).data();
      if (!v) throw missing('Verification');
      ctx.requireCampus(v.campusId);
      if (v.status !== 'counting') throw failed(`Verification is ${v.status}`);
      const refs = i.lines.map((l) => ref.collection('lines').doc(l.balanceId));
      const snaps = await ctx.tx.getAll(...refs);
      snaps.forEach((snap, k) => {
        const l = i.lines[k];
        if (!snap.exists) throw missing('Count line');
        const diff = l.counted - snap.data()!.expected;
        ctx.update(snap.ref, {
          counted: l.counted, diff, reason: diff === 0 ? null : (l.reason ?? null), note: l.note ?? null, countedBy: ctx.uid, countedAt: stamp(),
        });
      });
      ctx.update(ref, { updatedAt: stamp() });
      return { id: i.id };
    },
  }),

  /** Closes counting. Every line must be counted and every difference explained; no difference needs no approval. */
  submit: def({
    name: 'inv.verification.submit',
    perm: 'inv.stock.operate',
    input: z.object({ id }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invVerifications/${i.id}`);
      const v = (await ctx.tx.get(ref)).data();
      if (!v) throw missing('Verification');
      ctx.requireCampus(v.campusId);
      if (v.status !== 'counting') throw failed(`Verification is ${v.status}`);
      const lines = (await ctx.tx.get(ref.collection('lines'))).docs.map((d) => d.data());
      if (lines.some((l) => l.counted == null)) throw failed('Count every line first');
      const diffs = lines.filter((l) => l.diff !== 0);
      for (const l of diffs) {
        if (!l.reason) throw failed('Give a reason for every difference');
        if (l.reason === 'other' && !l.note) throw failed('Describe the reason for "other"');
        if ((l.reason === 'missing' && l.diff > 0) || (l.reason === 'excess' && l.diff < 0)) throw failed('Reason does not match the direction');
      }
      ctx.update(ref, {
        status: diffs.length ? 'submitted' : 'applied', diffCount: diffs.length, submittedAt: stamp(), submittedBy: ctx.uid, updatedAt: stamp(),
      });
      if (diffs.length) {
        await enqueue(ctx, `ver_submit__${i.id}`, {
          to: { perm: 'inv.adjustment.approve', campusId: v.campusId }, category: 'inv.verification',
          title: 'Stock verification to review', body: `${v.number}: ${diffs.length} difference(s) in ${v.storeName}.`, data: { verificationId: i.id },
        });
      }
      ctx.audit({ action: 'invVerification.submit', ref: ref.path, after: { diffs: diffs.length } });
      return { id: i.id, diffs: diffs.length };
    },
  }),

  /**
   * Approve applies every difference as an adjustment that references the session (the movement ledger is
   * only appended to); reject reopens counting. The delta is the counted-minus-expected difference, so stock
   * moved since the snapshot is kept; a delta that would take a balance below zero fails the whole approval.
   */
  decide: def({
    name: 'inv.verification.decide',
    perm: 'inv.adjustment.approve',
    input: z.object({ id, decision: z.enum(['approve', 'reject']), comment: z.string().trim().max(500).nullish() }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invVerifications/${i.id}`);
      const v = (await ctx.tx.get(ref)).data();
      if (!v) throw missing('Verification');
      ctx.requireCampus(v.campusId);
      if (v.status !== 'submitted') throw failed(`Verification is ${v.status}`);
      if (i.decision === 'reject' && !i.comment) throw failed('Give a reason for rejecting');
      const approval = { by: ctx.uid, at: stamp(), decision: i.decision, comment: i.comment ?? null };
      if (i.decision === 'reject') {
        ctx.update(ref, { status: 'counting', approval, updatedAt: stamp() });
        await enqueue(ctx, `ver_rejected__${i.id}__${Date.now()}`, {
          to: { uids: [v.createdBy] }, category: 'inv.verification',
          title: 'Stock verification sent back', body: `${v.number}: ${i.comment}`, data: { verificationId: i.id },
        });
        ctx.audit({ action: 'invVerification.reject', ref: ref.path, reason: i.comment ?? undefined });
        return { id: i.id, applied: 0 };
      }
      const s = new Stock(ctx);
      const diffs = (await ctx.tx.get(ref.collection('lines'))).docs.map((d) => d.data()).filter((l) => l.diff !== 0);
      let n = 0;
      for (const l of diffs) {
        const item = await s.item(l.itemId, l.variantId, true);
        const bal = await s.existing(l.balanceId, item);
        if (bal.d.unitCost === 0) bal.d.unitCost = item.defaultPrice ?? 0;
        const before = bal.d.qtyAvailable;
        const adj = ctx.newDoc('invAdjustments');
        s.move(bal, 'available', l.diff, { type: 'adjust', refType: 'verification', refId: i.id });
        ctx.set(adj, {
          number: `${v.number}/${++n}`, balanceId: l.balanceId, itemId: l.itemId, variantId: l.variantId, storeId: v.storeId, batchNo: l.batchNo,
          before, delta: l.diff, after: before + l.diff, reason: l.reason, note: l.note, evidence: null, verificationId: i.id, approval,
          status: 'completed', ...s.header(v.campusId),
        });
      }
      ctx.update(ref, { status: 'applied', approval, adjustmentCount: n, appliedAt: stamp(), appliedDate: todayIST(), updatedAt: stamp() });
      ctx.audit({ action: 'invVerification.approve', ref: ref.path, after: { adjustments: n }, reason: i.comment ?? undefined });
      await s.finish();
      return { id: i.id, applied: n };
    },
  }),
};
