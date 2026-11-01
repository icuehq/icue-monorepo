import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { def, failed, id, missing, note, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';
import { lineKey, person, qty, Stock, todayIST, txnFields, unavailableEntry } from './stock';

/** Stock receiving, issuance, returns, transfers, adjustments, unavailable stock (FRS 10.7–10.12). */

const money = z.number().min(0).max(100_000_000);
export const batch = { batchNo: z.string().trim().min(1).max(40).nullish(), mfgDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullish(), expiryDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullish() };
const lines = <T extends z.ZodType>(l: T) => z.array(l).min(1).max(50);
// Firestore line items are untyped maps; shape is enforced by the callables that write them.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;
const stamp = () => FieldValue.serverTimestamp();
const keyOf = (l: { itemId?: string; variantId?: string | null }) => `${l.itemId}__${l.variantId ?? '-'}`;

function unique(ls: Array<{ itemId: string; variantId?: string | null }>) {
  if (new Set(ls.map(keyOf)).size !== ls.length) throw failed('Each item (and variant) may appear once');
}

export const stock = {
  /** FRS 10.7. PO-linked receiving is `inv.po.receive` (receiving.ts). */
  receiptConfirm: def({
    name: 'inv.receipt.confirm',
    perm: 'inv.stock.operate',
    input: z.object({
      ...txnFields,
      storeId: id,
      source: z.enum(['opening', 'adjustment', 'department_return', 'person_return', 'other']),
      reference: note,
      remarks: note,
      lines: lines(z.object({
        ...lineKey, ...batch,
        qtyAccepted: z.number().min(0).max(1_000_000),
        qtyRejected: z.number().min(0).max(1_000_000).default(0),
        condition: z.string().trim().max(60).nullish(),
        unitCost: money.nullish(),
      })),
    }),
    handler: async (ctx, i) => {
      const s = new Stock(ctx, i);
      const store = await s.store(i.storeId);
      const ref = ctx.newDoc('invReceipts');
      const number = await s.num('GRN');
      const out = [];
      for (const l of i.lines) {
        if (l.qtyAccepted + l.qtyRejected <= 0) throw failed('Each line needs a quantity');
        const item = await s.item(l.itemId, l.variantId);
        const b = s.batchOf(item, l);
        const unitCost = l.unitCost ?? item.defaultPrice ?? 0;
        if (l.qtyAccepted > 0) {
          s.receive(await s.balance(i.storeId, item, l.variantId, b, true), l.qtyAccepted, 'receive', 'receipt', ref.id, unitCost);
        }
        out.push({
          itemId: l.itemId, variantId: l.variantId ?? null, ...b, unitCost, condition: l.condition ?? null,
          qtyReceived: l.qtyAccepted + l.qtyRejected, qtyAccepted: l.qtyAccepted, qtyRejected: l.qtyRejected,
        });
      }
      ctx.set(ref, {
        number, storeId: i.storeId, source: i.source, reference: i.reference ?? null, remarks: i.remarks ?? null,
        lines: out, itemIds: [...new Set(out.map((l) => l.itemId))], attachments: [], status: 'confirmed', ...s.header(store.campusId),
      });
      ctx.audit({ action: 'invReceipt.create', ref: ref.path, after: { number, source: i.source } });
      await s.finish();
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.8 steps 1–2. */
  issueRequestSubmit: def({
    name: 'inv.issueRequest.submit',
    perm: 'inv.issue.request',
    input: z.object({
      storeId: id,
      departmentId: z.number().int().nullish(),
      destination: note,
      purpose: z.string().trim().min(1).max(500),
      remarks: note,
      lines: lines(z.object({ ...lineKey, qty })),
    }),
    handler: async (ctx, i) => {
      unique(i.lines);
      const s = new Stock(ctx);
      const store = await s.store(i.storeId);
      for (const l of i.lines) await s.item(l.itemId, l.variantId);
      const ref = ctx.newDoc('invIssueRequests');
      const number = await s.num('ISR');
      ctx.set(ref, {
        number, storeId: i.storeId, departmentId: i.departmentId ?? null, destination: i.destination ?? null,
        purpose: i.purpose, remarks: i.remarks ?? null, requesterId: ctx.access.eid ?? null,
        lines: i.lines.map((l) => ({ itemId: l.itemId, variantId: l.variantId ?? null, qtyRequested: l.qty, qtyApproved: null, qtyIssued: 0 })),
        itemIds: i.lines.map((l) => l.itemId), status: 'pending', approval: null, ...s.header(store.campusId),
      });
      ctx.audit({ action: 'invIssueRequest.create', ref: ref.path, after: { number } });
      await enqueue(ctx, `isr_new__${ref.id}`, {
        to: { perm: 'inv.issue.approve', campusId: store.campusId }, category: 'inv.issueRequest',
        title: 'Issue request awaiting approval', body: `${number}: ${i.purpose}`, data: { id: ref.id },
      });
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.8 step 3: one approval level; approved ≤ available now, re-checked at issuance. */
  issueRequestDecide: def({
    name: 'inv.issueRequest.decide',
    perm: 'inv.issue.approve',
    input: z.object({
      id,
      decision: z.enum(['approve', 'reject']),
      lines: z.array(z.object({ index: z.number().int().min(0), qtyApproved: z.number().min(0).max(1_000_000) })).max(50).default([]),
      comment: note,
    }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invIssueRequests/${i.id}`);
      const r = (await ctx.tx.get(ref)).data();
      if (!r) throw missing('Issue request');
      ctx.requireCampus(r.campusId);
      if (r.status !== 'pending') throw failed(`Request is already ${r.status}`);
      const reqLines = r.lines as Array<Row>;
      let patch: Record<string, unknown>;
      if (i.decision === 'reject') {
        if (!i.comment) throw failed('A reason is required to reject');
        patch = { status: 'rejected' };
      } else {
        const s = new Stock(ctx);
        const over = new Map(i.lines.map((l) => [l.index, l.qtyApproved]));
        const out = [];
        for (const [n, l] of reqLines.entries()) {
          const approved = over.get(n) ?? l.qtyRequested;
          if (approved > l.qtyRequested) throw failed('Approved quantity exceeds the request');
          if (approved > (await s.available(r.storeId, l.itemId, l.variantId))) throw failed('Approved quantity exceeds available stock');
          out.push({ ...l, qtyApproved: approved });
        }
        if (!out.some((l) => (l.qtyApproved as number) > 0)) throw failed('Nothing approved; reject the request instead');
        patch = { status: 'approved', lines: out };
      }
      ctx.update(ref, { ...patch, approval: { by: ctx.uid, at: stamp(), comment: i.comment ?? null }, updatedAt: stamp() });
      ctx.audit({ action: `invIssueRequest.${i.decision}`, ref: ref.path, reason: i.comment ?? undefined });
      await enqueue(ctx, `isr_decided__${i.id}`, {
        to: { uids: [r.createdBy] }, category: 'inv.issueRequest',
        title: `Issue request ${i.decision === 'approve' ? 'approved' : 'rejected'}`, body: r.number, data: { id: i.id },
      });
      return { id: i.id };
    },
  }),

  /** FRS 10.8 step 4. Without `balanceId` a line is allocated first-expiry-first-out. */
  issueCreate: def({
    name: 'inv.issue.create',
    perm: 'inv.stock.operate',
    input: z.object({
      ...txnFields,
      issueRequestId: id,
      recipient: person,
      remarks: note,
      lines: lines(z.object({ ...lineKey, qty, balanceId: id.nullish() })),
    }),
    handler: async (ctx, i) => {
      const reqRef = ctx.doc(`invIssueRequests/${i.issueRequestId}`);
      const r = (await ctx.tx.get(reqRef)).data();
      if (!r) throw missing('Issue request');
      if (r.status !== 'approved' && r.status !== 'partially_issued') throw failed(`Request is ${r.status}`);
      const s = new Stock(ctx, i);
      const store = await s.store(r.storeId, true);
      const reqLines = (r.lines as Array<Row>).map((l) => ({ ...l }));
      const ref = ctx.newDoc('invIssues');
      const number = await s.num('ISS');
      const issued = new Map<string, Record<string, unknown>>();
      for (const l of i.lines) {
        const rl = reqLines.find((x) => keyOf(x) === keyOf(l));
        if (!rl) throw failed('Item is not on the request');
        if (rl.qtyIssued + l.qty > rl.qtyApproved) throw failed('Issue exceeds the approved quantity');
        const item = await s.item(l.itemId, l.variantId, true);
        const picks = l.balanceId
          ? [{ bal: await s.existing(l.balanceId, item), qty: l.qty }]
          : await s.allocate(r.storeId, item, l.variantId, l.qty);
        for (const { bal, qty: q } of picks) {
          if (bal.d.storeId !== r.storeId || bal.d.itemId !== l.itemId || (bal.d.variantId ?? null) !== (l.variantId ?? null)) {
            throw failed('Balance does not match the item');
          }
          s.move(bal, 'available', -q, { type: 'issue', refType: 'issue', refId: ref.id });
          const row = issued.get(bal.id) ?? {
            itemId: l.itemId, variantId: l.variantId ?? null, balanceId: bal.id, batchNo: bal.d.batchNo ?? null,
            mfgDate: bal.d.mfgDate ?? null, expiryDate: bal.d.expiryDate ?? null, unitCost: bal.d.unitCost, qty: 0, qtyReturned: 0,
          };
          row.qty = (row.qty as number) + q;
          issued.set(bal.id, row);
        }
        rl.qtyIssued += l.qty;
      }
      const done = reqLines.every((l) => l.qtyIssued >= l.qtyApproved);
      ctx.set(ref, {
        number, issueRequestId: i.issueRequestId, storeId: r.storeId, recipient: i.recipient, issuedBy: ctx.uid,
        remarks: i.remarks ?? null, lines: [...issued.values()], itemIds: [...new Set(i.lines.map((l) => l.itemId))],
        ack: null, ...s.header(store.campusId),
      });
      ctx.update(reqRef, { lines: reqLines, status: done ? 'issued' : 'partially_issued', updatedAt: stamp() });
      ctx.audit({ action: 'invIssue.create', ref: ref.path, after: { number, issueRequestId: i.issueRequestId } });
      await s.finish();
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.8 step 5. */
  issueAcknowledge: def({
    name: 'inv.issue.acknowledge',
    perm: 'inv.stock.operate',
    input: z.object({ id, remarks: note }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invIssues/${i.id}`);
      const d = (await ctx.tx.get(ref)).data();
      if (!d) throw missing('Issue');
      ctx.requireCampus(d.campusId);
      if (d.ack) throw failed('Already acknowledged');
      ctx.update(ref, { ack: { by: ctx.uid, at: stamp(), remarks: i.remarks ?? null }, updatedAt: stamp() });
      ctx.audit({ action: 'invIssue.acknowledge', ref: ref.path });
      return { id: i.id };
    },
  }),

  /** FRS 10.9: returned ≤ outstanding per issue line; damaged goes to the unavailable register. */
  returnCreate: def({
    name: 'inv.return.create',
    perm: 'inv.stock.operate',
    input: z.object({
      ...txnFields,
      issueId: id,
      storeId: id.nullish(),
      returnedBy: person,
      remarks: note,
      lines: lines(z.object({ balanceId: id, qtyUsable: z.number().min(0).max(1_000_000), qtyDamaged: z.number().min(0).max(1_000_000).default(0) })),
    }),
    handler: async (ctx, i) => {
      const issueRef = ctx.doc(`invIssues/${i.issueId}`);
      const issue = (await ctx.tx.get(issueRef)).data();
      if (!issue) throw missing('Issue');
      const s = new Stock(ctx, i);
      const dest = i.storeId ?? issue.storeId;
      const store = await s.store(dest);
      const issueLines = (issue.lines as Array<Row>).map((l) => ({ ...l }));
      const ref = ctx.newDoc('invReturns');
      const number = await s.num('RET');
      const out = [];
      for (const l of i.lines) {
        const il = issueLines.find((x) => x.balanceId === l.balanceId);
        const q = l.qtyUsable + l.qtyDamaged;
        if (!il) throw failed('Line is not on the issue');
        if (q <= 0) throw failed('Each line needs a quantity');
        if (q > il.qty - il.qtyReturned) throw failed(`Only ${il.qty - il.qtyReturned} outstanding for this line`);
        il.qtyReturned += q;
        const item = await s.item(il.itemId, il.variantId, true);
        const bal = await s.balance(dest, item, il.variantId, { batchNo: il.batchNo, mfgDate: il.mfgDate, expiryDate: il.expiryDate }, true);
        if (bal.d.unitCost === 0) bal.d.unitCost = il.unitCost;
        if (l.qtyUsable > 0) s.move(bal, 'available', l.qtyUsable, { type: 'return', refType: 'return', refId: ref.id });
        if (l.qtyDamaged > 0) {
          s.move(bal, 'damaged', l.qtyDamaged, { type: 'return', refType: 'return', refId: ref.id });
          unavailableEntry(s, bal, l.qtyDamaged, { bucket: 'damaged', reason: 'damaged_return', refType: 'return', refId: ref.id });
        }
        out.push({ balanceId: bal.id, itemId: il.itemId, variantId: il.variantId, qtyUsable: l.qtyUsable, qtyDamaged: l.qtyDamaged });
      }
      ctx.set(ref, {
        number, issueId: i.issueId, storeId: dest, returnedBy: i.returnedBy, remarks: i.remarks ?? null, lines: out,
        inspection: { by: ctx.uid, at: stamp() }, ...s.header(store.campusId),
      });
      ctx.update(issueRef, { lines: issueLines, updatedAt: stamp() });
      ctx.audit({ action: 'invReturn.create', ref: ref.path, after: { number, issueId: i.issueId } });
      await s.finish();
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.10 step 1. */
  transferRequest: def({
    name: 'inv.transfer.request',
    perm: 'inv.stock.operate',
    input: z.object({ ...txnFields, fromStoreId: id, toStoreId: id, remarks: note, lines: lines(z.object({ ...lineKey, qty })) }),
    handler: async (ctx, i) => {
      if (i.fromStoreId === i.toStoreId) throw failed('Source and destination must differ');
      unique(i.lines);
      const s = new Stock(ctx, i);
      const from = await s.store(i.fromStoreId);
      const to = usable(await ctx.tx.get(ctx.doc(`invStores/${i.toStoreId}`)), 'Destination store', false);
      for (const l of i.lines) await s.item(l.itemId, l.variantId);
      const ref = ctx.newDoc('invTransfers');
      const number = await s.num('TRF');
      ctx.set(ref, {
        number, from: { campusId: from.campusId, storeId: i.fromStoreId }, to: { campusId: to.campusId, storeId: i.toStoreId },
        toCampusId: to.campusId, remarks: i.remarks ?? null,
        requested: i.lines.map((l) => ({ itemId: l.itemId, variantId: l.variantId ?? null, qty: l.qty })), lines: [],
        itemIds: i.lines.map((l) => l.itemId), status: 'requested', ...s.header(from.campusId),
      });
      ctx.audit({ action: 'invTransfer.request', ref: ref.path, after: { number } });
      return { id: ref.id, number };
    },
  }),

  /** Dispatch reduces the source (first-expiry-first-out); the stock stays in transit until received. */
  transferDispatch: def({
    name: 'inv.transfer.dispatch',
    perm: 'inv.stock.operate',
    input: z.object({ ...txnFields, id }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invTransfers/${i.id}`);
      const t = (await ctx.tx.get(ref)).data();
      if (!t) throw missing('Transfer');
      if (t.status !== 'requested') throw failed(`Transfer is ${t.status}`);
      const s = new Stock(ctx, i);
      await s.store(t.from.storeId);
      const out = [];
      for (const l of t.requested as Array<{ itemId: string; variantId: string | null; qty: number }>) {
        const item = await s.item(l.itemId, l.variantId, true);
        for (const { bal, qty: q } of await s.allocate(t.from.storeId, item, l.variantId, l.qty)) {
          s.move(bal, 'available', -q, { type: 'transfer_out', refType: 'transfer', refId: i.id });
          out.push({
            itemId: l.itemId, variantId: l.variantId, balanceId: bal.id, batchNo: bal.d.batchNo ?? null, mfgDate: bal.d.mfgDate ?? null,
            expiryDate: bal.d.expiryDate ?? null, unitCost: bal.d.unitCost, qtyDispatched: q, qtyReceived: 0, discrepancy: 0,
          });
        }
      }
      ctx.update(ref, { lines: out, status: 'dispatched', dispatch: { by: ctx.uid, date: s.date, at: stamp() }, updatedAt: stamp() });
      ctx.audit({ action: 'invTransfer.dispatch', ref: ref.path });
      await enqueue(ctx, `transfer_dispatched__${i.id}`, {
        to: { perm: 'inv.stock.operate', campusId: t.to.campusId }, category: 'inv.transfer',
        title: 'Stock on its way', body: `${t.number} has been dispatched to your store.`, data: { id: i.id },
      });
      await s.finish();
      return { id: i.id };
    },
  }),

  /**
   * Destination confirms what arrived. Partial receipts keep the transfer open;
   * `final` closes it and records any shortfall as `discrepancy` (never silently lost).
   */
  transferReceive: def({
    name: 'inv.transfer.receive',
    perm: 'inv.stock.operate',
    input: z.object({
      ...txnFields,
      id,
      final: z.boolean().default(false),
      remarks: note,
      lines: z.array(z.object({ index: z.number().int().min(0), qtyReceived: qty })).max(50).default([]),
    }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invTransfers/${i.id}`);
      const t = (await ctx.tx.get(ref)).data();
      if (!t) throw missing('Transfer');
      if (t.status !== 'dispatched' && t.status !== 'partially_received') throw failed(`Transfer is ${t.status}`);
      if (!i.lines.length && !i.final) throw failed('Enter the received quantities');
      const s = new Stock(ctx, i);
      await s.store(t.to.storeId, true);
      const rows = (t.lines as Array<Row>).map((l) => ({ ...l }));
      for (const l of i.lines) {
        const row = rows[l.index];
        if (!row) throw failed('Unknown transfer line');
        if (l.qtyReceived > row.qtyDispatched - row.qtyReceived) throw failed('Received more than was dispatched');
        const item = await s.item(row.itemId, row.variantId, true);
        const bal = await s.balance(t.to.storeId, item, row.variantId, { batchNo: row.batchNo, mfgDate: row.mfgDate, expiryDate: row.expiryDate }, true);
        s.receive(bal, l.qtyReceived, 'transfer_in', 'transfer', i.id, row.unitCost);
        row.qtyReceived += l.qtyReceived;
      }
      const complete = rows.every((r) => r.qtyReceived >= r.qtyDispatched);
      const close = complete || i.final;
      if (close) for (const r of rows) r.discrepancy = r.qtyDispatched - r.qtyReceived;
      ctx.update(ref, {
        lines: rows, status: close ? 'received' : 'partially_received', receipt: { by: ctx.uid, date: s.date, at: stamp(), remarks: i.remarks ?? null },
        updatedAt: stamp(),
      });
      ctx.audit({ action: 'invTransfer.receive', ref: ref.path, after: { final: close } });
      await s.finish();
      return { id: i.id };
    },
  }),

  /**
   * FRS 10.11. Applies at once (approval for count-driven adjustments arrives with Inv-7).
   * Damage and expiry are reported under unavailable stock, not here.
   */
  adjustmentCreate: def({
    name: 'inv.adjustment.create',
    perm: 'inv.stock.operate',
    input: z.object({
      ...txnFields, ...lineKey, ...batch,
      storeId: id,
      delta: z.number().min(-1_000_000).max(1_000_000).refine((n) => n !== 0, 'delta must not be 0'),
      reason: z.enum(['count_correction', 'data_entry', 'missing', 'excess', 'other']),
      note: z.string().trim().max(500).nullish(),
    }),
    handler: async (ctx, i) => {
      if (i.reason === 'other' && !i.note) throw failed('Describe the reason');
      if ((i.reason === 'missing' && i.delta > 0) || (i.reason === 'excess' && i.delta < 0)) throw failed('Reason does not match the direction');
      const s = new Stock(ctx, i);
      const store = await s.store(i.storeId);
      const item = await s.item(i.itemId, i.variantId);
      const bal = await s.balance(i.storeId, item, i.variantId, s.batchOf(item, i), i.delta > 0);
      if (bal.d.unitCost === 0) bal.d.unitCost = item.defaultPrice ?? 0;
      const before = bal.d.qtyAvailable;
      const ref = ctx.newDoc('invAdjustments');
      const number = await s.num('ADJ');
      s.move(bal, 'available', i.delta, { type: 'adjust', refType: 'adjustment', refId: ref.id });
      ctx.set(ref, {
        number, balanceId: bal.id, itemId: i.itemId, variantId: i.variantId ?? null, storeId: i.storeId, batchNo: bal.d.batchNo ?? null,
        before, delta: i.delta, after: before + i.delta, reason: i.reason, note: i.note ?? null, evidence: null, approval: null,
        status: 'completed', ...s.header(store.campusId),
      });
      ctx.audit({ action: 'invAdjustment.create', ref: ref.path, before: { qty: before }, after: { qty: before + i.delta }, reason: i.reason });
      await s.finish();
      return { id: ref.id, number };
    },
  }),

  /** FRS 10.12: moves usable stock out of `qtyAvailable` into a register entry. */
  unavailableReport: def({
    name: 'inv.unavailable.report',
    perm: 'inv.stock.operate',
    input: z.object({
      ...txnFields, ...lineKey, ...batch,
      storeId: id,
      qty,
      reason: z.enum(['damaged', 'expired', 'lost']),
      note: z.string().trim().min(1).max(500),
    }),
    handler: async (ctx, i) => {
      const s = new Stock(ctx, i);
      await s.store(i.storeId);
      const item = await s.item(i.itemId, i.variantId, true);
      const bal = await s.balance(i.storeId, item, i.variantId, s.batchOf(item, i), false);
      const ref = ctx.newDoc('invUnavailable');
      const refId = ref.id;
      if (i.reason === 'expired' && !(bal.d.expiryDate && bal.d.expiryDate <= todayIST())) throw failed('Batch has not expired');
      const type = i.reason === 'damaged' ? 'damage' : i.reason === 'expired' ? 'expire' : 'writeoff';
      s.move(bal, 'available', -i.qty, { type, refType: 'unavailable', refId });
      const bucket = i.reason === 'lost' ? null : i.reason;
      if (bucket) s.move(bal, bucket, i.qty, { type, refType: 'unavailable', refId });
      unavailableEntry(s, bal, i.qty, {
        ref, bucket, reason: i.reason, note: i.note, refType: 'unavailable', refId,
        ...(bucket ? {} : { status: 'resolved' as const, resolution: 'write_off' }),
      });
      ctx.audit({ action: 'invUnavailable.report', ref: ref.path, after: { reason: i.reason, qty: i.qty } });
      await s.finish();
      return { id: ref.id };
    },
  }),

  unavailableResolve: def({
    name: 'inv.unavailable.resolve',
    perm: 'inv.stock.operate',
    input: z.object({
      id,
      resolution: z.enum(['restore', 'repair', 'dispose', 'write_off', 'vendor_return', 'other']),
      note: z.string().trim().max(500).nullish(),
    }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invUnavailable/${i.id}`);
      const e = (await ctx.tx.get(ref)).data();
      if (!e) throw missing('Entry');
      ctx.requireCampus(e.campusId);
      const canRepair = e.status === 'open' && e.bucket === 'damaged';
      if ((e.status !== 'open' && e.status !== 'in_repair') || (i.resolution === 'repair' && !canRepair)) throw failed(`Entry is ${e.status}`);
      if (i.resolution === 'other' && !i.note) throw failed('Describe the resolution');
      if (i.resolution !== 'repair') {
        const s = new Stock(ctx);
        const item = await s.item(e.itemId, e.variantId, true);
        const bal = await s.existing(e.balanceId, item);
        const m = { refType: 'unavailable', refId: i.id };
        if (i.resolution === 'restore') {
          if (bal.d.expiryDate && bal.d.expiryDate < todayIST()) throw failed('Expired batches cannot return to usable stock');
          s.move(bal, e.bucket, -e.qty, { type: 'restore', ...m });
          s.move(bal, 'available', e.qty, { type: 'restore', ...m });
        } else {
          s.move(bal, e.bucket, -e.qty, { type: 'writeoff', ...m });
        }
        await s.finish();
      }
      const repair = i.resolution === 'repair';
      ctx.update(ref, {
        status: repair ? 'in_repair' : 'resolved', resolution: i.resolution, resolutionNote: i.note ?? null,
        ...(repair ? {} : { resolvedAt: stamp(), resolvedBy: ctx.uid }), updatedAt: stamp(),
      });
      ctx.audit({ action: 'invUnavailable.resolve', ref: ref.path, after: { resolution: i.resolution }, reason: i.note ?? undefined });
      return { id: i.id };
    },
  }),
};

