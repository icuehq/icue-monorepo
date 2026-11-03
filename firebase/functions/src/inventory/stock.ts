import { type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { isoDate, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { financialYearOf, nextNumber } from '../shared/keys';
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
  | 'receive'
  | 'issue'
  | 'return'
  | 'transfer_out'
  | 'transfer_in'
  | 'adjust'
  | 'expire'
  | 'damage'
  | 'writeoff'
  | 'restore';

export interface StockBalance {
  id: string;
  ref: DocumentReference;
  data: DocumentData;
  reorder: number | null;
  wasLow: boolean;
  wasOut: boolean;
}
export interface Batch {
  batchNumber?: string | null;
  manufacturingDate?: string | null;
  expiryDate?: string | null;
}

export const positiveQuantity = z.number().positive().max(1_000_000);
export const stockPerson = z.object({
  type: z.enum(['staff', 'student', 'department']),
  personErpId: z.number().int(),
});
/** Header fields stamped on every transaction (FRS 13): date defaults to today (IST), `academicYearId` is the ERP academic year. */
export const transactionFields = {
  date: isoDate.optional(),
  academicYearId: z.number().int().nullish(),
};
export const lineKey = { itemId: id, variantId: id.nullish() };

/** Identifies a line by item and variant. */
export const lineItemKey = (lineItem: { itemId?: string; variantId?: string | null }) =>
  `${lineItem.itemId}__${lineItem.variantId ?? '-'}`;

export function assertUniqueLines(lineItems: { itemId: string; variantId?: string | null }[]) {
  if (new Set(lineItems.map(lineItemKey)).size !== lineItems.length)
    throw failed('Each item (and variant) may appear once');
}

export const balanceId = (
  storeId: string,
  itemId: string,
  variantId?: string | null,
  batchNumber?: string | null,
) =>
  [storeId, itemId, variantId || '-', batchNumber ? encodeURIComponent(batchNumber) : '-'].join(
    '__',
  );

export class Stock {
  readonly date: string;
  readonly financialYear: string;
  readonly academicYearId: number | null;
  private readonly bals = new Map<string, StockBalance>();
  private readonly items = new Map<string, DocumentData>();
  private readonly moves: DocumentData[] = [];
  private seq = 0;

  constructor(
    readonly context: CallableContext,
    header: { date?: string; academicYearId?: number | null } = {},
  ) {
    this.date = header.date ?? todayIST();
    if (this.date > todayIST()) throw failed('Date cannot be in the future');
    this.financialYear = financialYearOf(new Date(`${this.date}T12:00:00+05:30`));
    this.academicYearId = header.academicYearId ?? null;
  }

  /** Store the caller may operate on; inactive stores are rejected for new transactions unless [inactiveOk]. */
  async store(storeId: string, inactiveOk = false): Promise<DocumentData> {
    const store = usable(
      await this.context.transaction.get(this.context.doc(`inventoryStores/${storeId}`)),
      'Store',
      inactiveOk,
    );
    this.context.requireCampus(store.campusId);
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

  /** Batch identity for a line: only batch-tracked items carry a batch. */
  batchOf(item: DocumentData, batch: Batch, receiving = false): Required<Batch> {
    if (item.tracking !== 'batch')
      return { batchNumber: null, manufacturingDate: null, expiryDate: null };
    if (!batch.batchNumber) throw failed(`${item.name} needs a batch number`);
    if (batch.manufacturingDate && batch.expiryDate && batch.expiryDate < batch.manufacturingDate)
      throw failed('Expiry date is before manufacturing date');
    if (receiving && batch.expiryDate && batch.expiryDate < todayIST())
      throw failed('Expired batches cannot be received');
    return {
      batchNumber: batch.batchNumber,
      manufacturingDate: batch.manufacturingDate ?? null,
      expiryDate: batch.expiryDate ?? null,
    };
  }

  /** The balance of store × item × variant × batch; created empty when [create], else `failed-precondition`. */
  async balance(
    storeId: string,
    item: DocumentData,
    variantId: string | null | undefined,
    batch: Required<Batch>,
    create: boolean,
  ): Promise<StockBalance> {
    const bid = balanceId(storeId, item.id, variantId, batch.batchNumber);
    const cached = this.bals.get(bid);
    if (cached) return cached;
    const ref = this.context.doc(`inventoryBalances/${bid}`);
    const snapshot = await this.context.transaction.get(ref);
    if (snapshot.exists) {
      const have = snapshot.data()!.expiryDate;
      if (batch.expiryDate && have && batch.expiryDate !== have)
        throw failed(`Batch ${batch.batchNumber} already exists with expiry ${have}`);
      return this.track(bid, ref, snapshot.data()!, item);
    }
    if (!create) throw failed(`No stock of ${item.name} in this store`);
    const store = (
      await this.context.transaction.get(this.context.doc(`inventoryStores/${storeId}`))
    ).data()!;
    return this.track(
      bid,
      ref,
      {
        campusId: store.campusId,
        storeId,
        itemId: item.id,
        variantId: variantId ?? null,
        ...batch,
        quantityAvailable: 0,
        quantityReserved: 0,
        quantityDamaged: 0,
        quantityExpired: 0,
        totalQuantityReceived: 0,
        totalQuantityIssued: 0,
        unitCost: 0,
        value: 0,
        isBelowReorderLevel: false,
        earliestExpiryDate: null,
        createdAt: serverTimestamp(),
        createdBy: this.context.uid,
      },
      item,
    );
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

  /** `PREFIX/2026-27/000123` for the transaction date. */
  num(type: string): Promise<string> {
    return nextNumber(this.context, type, new Date(`${this.date}T12:00:00+05:30`));
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
      .sort((earlierBatch, right) =>
        (earlierBatch.data.expiryDate ?? '9999').localeCompare(right.data.expiryDate ?? '9999'),
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

  /** Issuable stock of an item in a store (non-expired available). */
  async available(storeId: string, itemId: string, variantId?: string | null): Promise<number> {
    const snapshot = await this.context.transaction.get(
      this.context
        .coll('inventoryBalances')
        .where('storeId', '==', storeId)
        .where('itemId', '==', itemId),
    );
    return snapshot.docs
      .filter(
        (balance) =>
          (balance.data().variantId ?? null) === (variantId ?? null) &&
          !this.expired({ data: balance.data() }),
      )
      .reduce((total, balance) => total + (balance.data().quantityAvailable as number), 0);
  }

  private expired(balance: { data: DocumentData }): boolean {
    return !!balance.data.expiryDate && balance.data.expiryDate < todayIST();
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
      (movement.type === 'issue' || movement.type === 'transfer_out') &&
      this.expired(balance)
    ) {
      throw failed('Batch has expired and cannot be issued');
    }
    balance.data[field] += quantity;
    if (movement.type === 'receive' || movement.type === 'transfer_in')
      balance.data.totalQuantityReceived += quantity;
    if (movement.type === 'issue') balance.data.totalQuantityIssued -= quantity;
    if (movement.type === 'return') balance.data.totalQuantityIssued -= quantity;
    this.moves.push({
      type: movement.type,
      balanceId: balance.id,
      itemId: balance.data.itemId,
      variantId: balance.data.variantId ?? null,
      storeId: balance.data.storeId,
      campusId: balance.data.campusId,
      batchNumber: balance.data.batchNumber ?? null,
      quantity,
      bucket,
      referenceType: movement.referenceType,
      referenceId: movement.referenceId,
      unitCost: movement.unitCost ?? balance.data.unitCost,
      transactionDate: this.date,
      financialYear: this.financialYear,
      academicYearId: this.academicYearId,
      seq: this.seq++,
      createdAt: serverTimestamp(),
      createdBy: this.context.uid,
    });
  }

  /** Stock-in with weighted-average cost. */
  receive(
    balance: StockBalance,
    quantity: number,
    type: 'receive' | 'transfer_in',
    referenceType: string,
    referenceId: string,
    unitCost: number,
  ): void {
    const have = balance.data.quantityAvailable;
    balance.data.unitCost =
      have + quantity > 0
        ? (have * balance.data.unitCost + quantity * unitCost) / (have + quantity)
        : unitCost;
    this.move(balance, 'available', quantity, { type, referenceType, referenceId, unitCost });
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
      if (balance.data.isBelowReorderLevel && !balance.wasLow) {
        await enqueue(this.context, `inventory-low-stock__${balance.id}__${this.date}`, {
          to: { permission: 'inventory.stock.operate', campusId: balance.data.campusId },
          category: 'inventory.lowStock',
          title: 'Low stock',
          body: `${this.items.get(balance.data.itemId)?.name ?? 'An item'} is at ${balance.data.quantityAvailable} (reorder level ${balance.reorder}).`,
          data: { balanceId: balance.id },
        });
      }
      if (balance.data.quantityAvailable === 0 && !balance.wasOut) {
        await enqueue(this.context, `inventory-out-of-stock__${balance.id}__${this.date}`, {
          to: { permission: 'inventory.stock.operate', campusId: balance.data.campusId },
          category: 'inventory.outOfStock',
          title: 'Out of stock',
          body: `${this.items.get(balance.data.itemId)?.name ?? 'An item'} is out of stock.`,
          data: { balanceId: balance.id },
        });
      }
    }
    for (const movement of this.moves)
      this.context.set(this.context.newDoc('inventoryMovements'), movement);
  }

  /** Common header stamped on every stock document. */
  header(storeCampus: number) {
    return {
      campusId: storeCampus,
      transactionDate: this.date,
      financialYear: this.financialYear,
      academicYearId: this.academicYearId,
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
    ...stock.header(balance.data.campusId),
  });
  return ref;
}
