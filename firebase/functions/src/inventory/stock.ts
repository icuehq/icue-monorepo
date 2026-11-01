import { DocumentData, DocumentReference, FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { Ctx } from '../shared/callable';
import { fyOf, nextNumber } from '../shared/keys';
import { failed, id, missing, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';

/**
 * Stock ledger helper (architecture §4.2, §6). One `Stock` per callable: balances are
 * loaded once and mutated in memory (so several lines can hit the same balance), and
 * `finish()` queues the balance writes, the append-only `invMovements` and low-stock events.
 */

export type Bucket = 'available' | 'damaged' | 'expired';
const FIELD: Record<Bucket, string> = { available: 'qtyAvailable', damaged: 'qtyDamaged', expired: 'qtyExpired' };

export type MoveType =
  | 'receive' | 'issue' | 'return' | 'transfer_out' | 'transfer_in'
  | 'adjust' | 'expire' | 'damage' | 'writeoff' | 'restore';

export type Bal = { id: string; ref: DocumentReference; d: DocumentData; reorder: number | null; wasLow: boolean; wasOut: boolean };
export type Batch = { batchNo?: string | null; mfgDate?: string | null; expiryDate?: string | null };

export const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
export const qty = z.number().positive().max(1_000_000);
export const person = z.object({ type: z.enum(['staff', 'student', 'department']), erpId: z.number().int() });
/** Header fields stamped on every transaction (FRS 13): date defaults to today (IST), `ay` is the ERP academic year. */
export const txnFields = { date: day.optional(), ayId: z.number().int().nullish() };
export const lineKey = { itemId: id, variantId: id.nullish() };

const IST_MS = 330 * 60 * 1000;
export const todayIST = () => new Date(Date.now() + IST_MS).toISOString().slice(0, 10);

export const balanceId = (storeId: string, itemId: string, variantId?: string | null, batchNo?: string | null) =>
  [storeId, itemId, variantId || '-', batchNo ? encodeURIComponent(batchNo) : '-'].join('__');

export class Stock {
  readonly date: string;
  readonly fy: string;
  readonly ay: number | null;
  private readonly bals = new Map<string, Bal>();
  private readonly items = new Map<string, DocumentData>();
  private readonly moves: DocumentData[] = [];
  private seq = 0;

  constructor(readonly ctx: Ctx, t: { date?: string; ayId?: number | null } = {}) {
    this.date = t.date ?? todayIST();
    if (this.date > todayIST()) throw failed('Date cannot be in the future');
    this.fy = fyOf(new Date(`${this.date}T12:00:00+05:30`));
    this.ay = t.ayId ?? null;
  }

  /** Store the caller may operate on; inactive stores are rejected for new transactions unless [inactiveOk]. */
  async store(storeId: string, inactiveOk = false): Promise<DocumentData> {
    const s = usable(await this.ctx.tx.get(this.ctx.doc(`invStores/${storeId}`)), 'Store', inactiveOk);
    this.ctx.requireCampus(s.campusId);
    return s;
  }

  /** Stock-tracked item; variant is required exactly when the item declares variant attributes. */
  async item(itemId: string, variantId?: string | null, inactiveOk = false): Promise<DocumentData> {
    let item = this.items.get(itemId);
    if (!item) {
      item = usable(await this.ctx.tx.get(this.ctx.doc(`invItems/${itemId}`)), 'Item', inactiveOk);
      if (item.tracking === 'asset') throw failed(`${item.name} is an individual asset; assets are managed separately`);
      this.items.set(itemId, { ...item, id: itemId });
    }
    const hasVariants = (item.variantAttrs as string[]).length > 0;
    if (hasVariants !== !!variantId) throw failed(hasVariants ? `${item.name} needs a variant` : `${item.name} has no variants`);
    if (variantId) usable(await this.ctx.tx.get(this.ctx.doc(`invItems/${itemId}/variants/${variantId}`)), 'Variant', inactiveOk);
    return this.items.get(itemId)!;
  }

  /** Batch identity for a line: only batch-tracked items carry a batch. */
  batchOf(item: DocumentData, b: Batch): Required<Batch> {
    if (item.tracking !== 'batch') return { batchNo: null, mfgDate: null, expiryDate: null };
    if (!b.batchNo) throw failed(`${item.name} needs a batch number`);
    if (b.mfgDate && b.expiryDate && b.expiryDate < b.mfgDate) throw failed('Expiry date is before manufacturing date');
    return { batchNo: b.batchNo, mfgDate: b.mfgDate ?? null, expiryDate: b.expiryDate ?? null };
  }

  /** The balance of store × item × variant × batch; created empty when [create], else `failed-precondition`. */
  async balance(storeId: string, item: DocumentData, variantId: string | null | undefined, batch: Required<Batch>, create: boolean): Promise<Bal> {
    const bid = balanceId(storeId, item.id, variantId, batch.batchNo);
    const cached = this.bals.get(bid);
    if (cached) return cached;
    const ref = this.ctx.doc(`invBalances/${bid}`);
    const snap = await this.ctx.tx.get(ref);
    if (snap.exists) return this.track(bid, ref, snap.data()!, item);
    if (!create) throw failed(`No stock of ${item.name} in this store`);
    const store = (await this.ctx.tx.get(this.ctx.doc(`invStores/${storeId}`))).data()!;
    return this.track(bid, ref, {
      campusId: store.campusId, storeId, itemId: item.id, variantId: variantId ?? null, ...batch,
      qtyAvailable: 0, qtyReserved: 0, qtyDamaged: 0, qtyExpired: 0, qtyReceivedTotal: 0, qtyIssuedTotal: 0,
      unitCost: 0, value: 0, belowReorder: false, expKey: null,
      createdAt: FieldValue.serverTimestamp(), createdBy: this.ctx.uid,
    }, item);
  }

  /** Existing balance by id (cached), for flows that reference a balance directly. */
  async existing(bid: string, item: DocumentData): Promise<Bal> {
    const cached = this.bals.get(bid);
    if (cached) return cached;
    const ref = this.ctx.doc(`invBalances/${bid}`);
    const snap = await this.ctx.tx.get(ref);
    if (!snap.exists) throw missing('Balance');
    return this.track(bid, ref, snap.data()!, item);
  }

  /** `PREFIX/2026-27/000123` for the transaction date. */
  num(type: string): Promise<string> {
    return nextNumber(this.ctx, type, new Date(`${this.date}T12:00:00+05:30`));
  }

  private track(bid: string, ref: DocumentReference, d: DocumentData, item: DocumentData): Bal {
    const b: Bal = { id: bid, ref, d: { ...d }, reorder: item.reorderLevel ?? null, wasLow: d.belowReorder === true, wasOut: d.qtyAvailable === 0 };
    this.bals.set(bid, b);
    return b;
  }

  /**
   * Picks balances for [need] units of an item in a store, first-expiry-first-out,
   * skipping expired batches. Throws when the store cannot cover it.
   */
  async allocate(storeId: string, item: DocumentData, variantId: string | null | undefined, need: number): Promise<Array<{ bal: Bal; qty: number }>> {
    const snap = await this.ctx.tx.get(this.ctx.coll('invBalances').where('storeId', '==', storeId).where('itemId', '==', item.id));
    const cands = snap.docs
      .filter((s) => (s.data().variantId ?? null) === (variantId ?? null))
      .map((s) => this.bals.get(s.id) ?? this.track(s.id, s.ref, s.data(), item))
      .filter((b) => b.d.qtyAvailable > 0 && !this.expired(b))
      .sort((a, b) => (a.d.expiryDate ?? '9999').localeCompare(b.d.expiryDate ?? '9999'));
    const out: Array<{ bal: Bal; qty: number }> = [];
    let left = need;
    for (const bal of cands) {
      if (left <= 0) break;
      const q = Math.min(left, bal.d.qtyAvailable);
      out.push({ bal, qty: q });
      left -= q;
    }
    if (left > 0) throw failed(`Insufficient stock of ${item.name}`);
    return out;
  }

  /** Issuable stock of an item in a store (non-expired available). */
  async available(storeId: string, itemId: string, variantId?: string | null): Promise<number> {
    const snap = await this.ctx.tx.get(this.ctx.coll('invBalances').where('storeId', '==', storeId).where('itemId', '==', itemId));
    return snap.docs
      .filter((s) => (s.data().variantId ?? null) === (variantId ?? null) && !this.expired({ d: s.data() }))
      .reduce((n, s) => n + (s.data().qtyAvailable as number), 0);
  }

  private expired(b: { d: DocumentData }): boolean {
    return !!b.d.expiryDate && b.d.expiryDate < todayIST();
  }

  /**
   * Changes one bucket of [b] by signed [q] and appends the ledger row. Never below zero;
   * expired batches cannot leave the store as usable stock even before a job has run.
   */
  move(b: Bal, bucket: Bucket, q: number, m: { type: MoveType; refType: string; refId: string; unitCost?: number }): void {
    const f = FIELD[bucket];
    if (b.d[f] + q < 0) throw failed(`Insufficient stock (${b.d[f]} ${bucket})`);
    if (q < 0 && bucket === 'available' && (m.type === 'issue' || m.type === 'transfer_out') && this.expired(b)) {
      throw failed('Batch has expired and cannot be issued');
    }
    b.d[f] += q;
    if (m.type === 'receive' || m.type === 'transfer_in') b.d.qtyReceivedTotal += q;
    if (m.type === 'issue') b.d.qtyIssuedTotal -= q;
    if (m.type === 'return') b.d.qtyIssuedTotal -= q;
    this.moves.push({
      type: m.type, balanceId: b.id, itemId: b.d.itemId, variantId: b.d.variantId ?? null, storeId: b.d.storeId,
      campusId: b.d.campusId, batchNo: b.d.batchNo ?? null, qty: q, bucket, refType: m.refType, refId: m.refId,
      unitCost: m.unitCost ?? b.d.unitCost, txnDate: this.date, fy: this.fy, ay: this.ay,
      seq: this.seq++, createdAt: FieldValue.serverTimestamp(), createdBy: this.ctx.uid,
    });
  }

  /** Stock-in with weighted-average cost. */
  receive(b: Bal, q: number, type: 'receive' | 'transfer_in', refType: string, refId: string, unitCost: number): void {
    const have = b.d.qtyAvailable;
    b.d.unitCost = have + q > 0 ? (have * b.d.unitCost + q * unitCost) / (have + q) : unitCost;
    this.move(b, 'available', q, { type, refType, refId, unitCost });
  }

  /** Queues balances, ledger rows and low-stock events. Call once, last. */
  async finish(): Promise<void> {
    for (const b of this.bals.values()) {
      if (!this.moves.some((m) => m.balanceId === b.id)) continue;
      b.d.value = Math.round(b.d.qtyAvailable * b.d.unitCost * 100) / 100;
      b.d.belowReorder = b.reorder != null && b.d.qtyAvailable <= b.reorder;
      // Indexed expiry of usable stock only, so the dashboard counts expiring / expired stock with one range query.
      b.d.expKey = b.d.expiryDate && b.d.qtyAvailable > 0 ? b.d.expiryDate : null;
      this.ctx.set(b.ref, { ...b.d, updatedAt: FieldValue.serverTimestamp() });
      if (b.d.belowReorder && !b.wasLow) {
        await enqueue(this.ctx, `lowstock__${b.id}__${this.date}`, {
          to: { perm: 'inv.stock.operate', campusId: b.d.campusId },
          category: 'inv.lowStock',
          title: 'Low stock',
          body: `${this.items.get(b.d.itemId)?.name ?? 'An item'} is at ${b.d.qtyAvailable} (reorder level ${b.reorder}).`,
          data: { balanceId: b.id },
        });
      }
      if (b.d.qtyAvailable === 0 && !b.wasOut) {
        await enqueue(this.ctx, `outofstock__${b.id}__${this.date}`, {
          to: { perm: 'inv.stock.operate', campusId: b.d.campusId },
          category: 'inv.outOfStock',
          title: 'Out of stock',
          body: `${this.items.get(b.d.itemId)?.name ?? 'An item'} is out of stock.`,
          data: { balanceId: b.id },
        });
      }
    }
    for (const m of this.moves) this.ctx.set(this.ctx.newDoc('invMovements'), m);
  }

  /** Common header stamped on every stock document. */
  header(storeCampus: number) {
    return {
      campusId: storeCampus, txnDate: this.date, fy: this.fy, ay: this.ay,
      createdAt: FieldValue.serverTimestamp(), createdBy: this.ctx.uid, updatedAt: FieldValue.serverTimestamp(),
    };
  }
}

/** Register entry for stock that cannot be issued (FRS 10.12). */
export function unavailableEntry(s: Stock, b: Bal, q: number, o: { ref?: DocumentReference; bucket: Bucket | null; reason: string; note?: string | null; refType: string; refId: string; status?: 'open' | 'resolved'; resolution?: string }) {
  const ref = o.ref ?? s.ctx.newDoc('invUnavailable');
  s.ctx.set(ref, {
    balanceId: b.id, itemId: b.d.itemId, variantId: b.d.variantId ?? null, storeId: b.d.storeId, batchNo: b.d.batchNo ?? null,
    qty: q, bucket: o.bucket, reason: o.reason, note: o.note ?? null, evidence: null, refType: o.refType, refId: o.refId,
    status: o.status ?? 'open', resolution: o.resolution ?? null, resolvedAt: null, reportedBy: s.ctx.uid,
    ...s.header(b.d.campusId),
  });
  return ref;
}
