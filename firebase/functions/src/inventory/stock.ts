import { type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { dayTimestamp, timestampDay, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { financialYearOf } from '../shared/keys';
import { failed, id, missing, usable } from '../shared/masters';
import { enqueue } from '../shared/outbox';

/**
 * Stock ledger helper (architecture §4.2, §6). One `Stock` per callable: balances are
 * loaded once and mutated in memory (so several lines can hit the same balance), and
 * `finish()` queues the balance writes, the append-only `inventoryMovements` and low-stock events.
 */

export type Bucket = 'available' | 'damaged' | 'expired';
const FIELD: Record<Bucket, string> = {
  available: 'quantityAvailable',
  damaged: 'quantityDamaged',
  expired: 'quantityExpired',
};

export type MoveType =
  'receive' | 'issue' | 'return' | 'adjust' | 'expire' | 'damage' | 'writeoff' | 'restore';

export interface StockBalance {
  id: string;
  ref: DocumentReference;
  data: DocumentData;
  reorder: number | null;
  wasLow: boolean;
  wasOut: boolean;
}

export const positiveQuantity = z.number().positive().max(1_000_000);
export const stockPerson = z.object({
  type: z.enum(['staff', 'student', 'department']),
  personErpId: z.number().int(),
});
export const lineKey = { itemId: id, variantId: id.nullish() };

export class Stock {
  readonly date: string;
  readonly financialYear: string;
  private readonly bals = new Map<string, StockBalance>();
  private readonly items = new Map<string, DocumentData>();
  private readonly moves: DocumentData[] = [];
  private seq = 0;

  constructor(
    readonly context: CallableContext,
    header: { date?: string } = {},
  ) {
    this.date = header.date ?? todayIST();
    if (this.date > todayIST()) throw failed('Date cannot be in the future');
    this.financialYear = financialYearOf(new Date(`${this.date}T12:00:00+05:30`));
  }

  /** Store the caller may operate on; inactive stores are rejected for new transactions unless [inactiveOk]. */
  async store(storeId: string, inactiveOk = false): Promise<DocumentData> {
    const store = usable(
      await this.context.transaction.get(this.context.doc(`inventoryStores/${storeId}`)),
      'Store',
      inactiveOk,
    );
    return store;
  }

  /** Stock-tracked item; variant is required exactly when the item declares variant attributes. */
  async item(itemId: string, variantId?: string | null, inactiveOk = false): Promise<DocumentData> {
    let item = this.items.get(itemId);
    if (item && !inactiveOk && item.status !== 'active') throw failed(`Item is inactive`);
    if (!item) {
      item = usable(
        await this.context.transaction.get(this.context.doc(`inventoryItems/${itemId}`)),
        'Item',
        inactiveOk,
      );
      if (item.tracking === 'asset')
        throw failed(`${item.name} is an individual asset; assets are managed separately`);
      this.items.set(itemId, { ...item, id: itemId });
    }
    const hasVariants = ((item.variantAttrs as string[] | undefined) ?? []).length > 0;
    if (hasVariants !== !!variantId)
      throw failed(hasVariants ? `${item.name} needs a variant` : `${item.name} has no variants`);
    if (variantId)
      usable(
        await this.context.transaction.get(
          this.context.doc(`inventoryItems/${itemId}/variants/${variantId}`),
        ),
        'Variant',
        inactiveOk,
      );
    return this.items.get(itemId)!;
  }

  /** Existing balance by id (cached), for flows that reference a balance directly. */
  async existing(bid: string, item: DocumentData): Promise<StockBalance> {
    const cached = this.bals.get(bid);
    if (cached) return cached;
    const ref = this.context.doc(`inventoryBalances/${bid}`);
    const snapshot = await this.context.transaction.get(ref);
    if (!snapshot.exists) throw missing('Balance');
    return this.track(bid, ref, snapshot.data()!, item);
  }

  private track(
    bid: string,
    ref: DocumentReference,
    balanceDocument: DocumentData,
    item: DocumentData,
  ): StockBalance {
    const balance: StockBalance = {
      id: bid,
      ref,
      data: { ...balanceDocument },
      reorder: item.reorderLevel ?? null,
      wasLow: balanceDocument.isBelowReorderLevel === true,
      wasOut: balanceDocument.quantityAvailable === 0,
    };
    this.bals.set(bid, balance);
    return balance;
  }

  /**
   * Picks balances for [need] units of an item in a store, first-expiry-first-out,
   * skipping expired batches. Throws when the store cannot cover it.
   */
  async allocate(
    storeId: string,
    item: DocumentData,
    variantId: string | null | undefined,
    need: number,
  ): Promise<{ bal: StockBalance; quantity: number }[]> {
    const snapshot = await this.context.transaction.get(
      this.context
        .coll('inventoryBalances')
        .where('storeId', '==', storeId)
        .where('itemId', '==', item.id),
    );
    const cands = snapshot.docs
      .filter((balance) => (balance.data().variantId ?? null) === (variantId ?? null))
      .map(
        (balance) =>
          this.bals.get(balance.id) ?? this.track(balance.id, balance.ref, balance.data(), item),
      )
      .filter((balance) => balance.data.quantityAvailable > 0 && !this.expired(balance))
      .sort(
        (earlierBatch, right) =>
          (earlierBatch.data.expiryDate?.toMillis() ?? Infinity) -
          (right.data.expiryDate?.toMillis() ?? Infinity),
      );
    const out: { bal: StockBalance; quantity: number }[] = [];
    let left = need;
    for (const balance of cands) {
      if (left <= 0) break;
      const quantity = Math.min(left, balance.data.quantityAvailable);
      out.push({ bal: balance, quantity });
      left -= quantity;
    }
    if (left > 0) throw failed(`Insufficient stock of ${item.name}`);
    return out;
  }

  private expired(balance: { data: DocumentData }): boolean {
    return !!balance.data.expiryDate && timestampDay(balance.data.expiryDate) < todayIST();
  }

  /**
   * Changes one bucket of [b] by signed [q] and appends the ledger row. Never below zero;
   * expired batches cannot leave the store as usable stock even before a job has run.
   */
  move(
    balance: StockBalance,
    bucket: Bucket,
    quantity: number,
    movement: { type: MoveType; referenceType: string; referenceId: string; unitCost?: number },
  ): void {
    const field = FIELD[bucket];
    if (balance.data[field] + quantity < 0)
      throw failed(`Insufficient stock (${balance.data[field]} ${bucket})`);
    if (
      quantity < 0 &&
      bucket === 'available' &&
      movement.type === 'issue' &&
      this.expired(balance)
    ) {
      throw failed('Batch has expired and cannot be issued');
    }
    balance.data[field] += quantity;
    if (movement.type === 'receive') balance.data.totalQuantityReceived += quantity;
    if (movement.type === 'issue' || movement.type === 'return')
      balance.data.totalQuantityIssued -= quantity;
    this.moves.push({
      type: movement.type,
      balanceId: balance.id,
      itemId: balance.data.itemId,
      variantId: balance.data.variantId ?? null,
      storeId: balance.data.storeId,
      batchNumber: balance.data.batchNumber ?? null,
      quantity,
      bucket,
      referenceType: movement.referenceType,
      referenceId: movement.referenceId,
      unitCost: movement.unitCost ?? balance.data.unitCost,
      transactionDate: dayTimestamp(this.date),
      financialYear: this.financialYear,
      seq: this.seq++,
      createdAt: serverTimestamp(),
      createdBy: this.context.uid,
    });
  }

  /** Queues balances, ledger rows and low-stock events. Call once, last. */
  async finish(): Promise<void> {
    for (const balance of this.bals.values()) {
      if (!this.moves.some((move) => move.balanceId === balance.id)) continue;
      balance.data.value =
        Math.round(balance.data.quantityAvailable * balance.data.unitCost * 100) / 100;
      balance.data.isBelowReorderLevel =
        balance.reorder != null && balance.data.quantityAvailable <= balance.reorder;
      // Indexed expiry of usable stock only, so the dashboard counts expiring / expired stock with one range query.
      balance.data.earliestExpiryDate =
        balance.data.expiryDate && balance.data.quantityAvailable > 0
          ? balance.data.expiryDate
          : null;
      this.context.set(balance.ref, { ...balance.data, updatedAt: serverTimestamp() });
      const name = this.items.get(balance.data.itemId)?.name ?? 'An item';
      const alerts = [
        balance.data.isBelowReorderLevel &&
          !balance.wasLow && {
            slug: 'low-stock',
            category: 'inventory.lowStock',
            title: 'Low stock',
            body: `${name} is at ${balance.data.quantityAvailable} (reorder level ${balance.reorder}).`,
          },
        balance.data.quantityAvailable === 0 &&
          !balance.wasOut && {
            slug: 'out-of-stock',
            category: 'inventory.outOfStock',
            title: 'Out of stock',
            body: `${name} is out of stock.`,
          },
      ];
      for (const alert of alerts) {
        if (!alert) continue;
        await enqueue(this.context, `inventory-${alert.slug}__${balance.id}__${this.date}`, {
          to: { permission: 'inventory.stock.operate' },
          category: alert.category,
          title: alert.title,
          body: alert.body,
          data: { balanceId: balance.id },
        });
      }
    }
    for (const movement of this.moves)
      this.context.set(this.context.newDoc('inventoryMovements'), movement);
  }

  /** Common header stamped on every stock document. */
  header() {
    return {
      transactionDate: dayTimestamp(this.date),
      financialYear: this.financialYear,
      createdAt: serverTimestamp(),
      createdBy: this.context.uid,
      updatedAt: serverTimestamp(),
    };
  }
}

/** Register entry for stock that cannot be issued (FRS 10.12). */
export function unavailableEntry(
  stock: Stock,
  balance: StockBalance,
  quantity: number,
  reference: {
    ref?: DocumentReference;
    bucket: Bucket | null;
    reason: string;
    remarks?: string | null;
    referenceType: string;
    referenceId: string;
    status?: 'open' | 'resolved';
    resolution?: string;
  },
) {
  const ref = reference.ref ?? stock.context.newDoc('inventoryUnavailableStock');
  stock.context.set(ref, {
    balanceId: balance.id,
    itemId: balance.data.itemId,
    variantId: balance.data.variantId ?? null,
    storeId: balance.data.storeId,
    batchNumber: balance.data.batchNumber ?? null,
    quantity,
    bucket: reference.bucket,
    reason: reference.reason,
    remarks: reference.remarks ?? null,
    evidence: null,
    referenceType: reference.referenceType,
    referenceId: reference.referenceId,
    status: reference.status ?? 'open',
    resolution: reference.resolution ?? null,
    resolvedAt: null,
    reportedBy: stock.context.uid,
    ...stock.header(),
  });
  return ref;
}
