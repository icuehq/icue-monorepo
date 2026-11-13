import { type DocumentData, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import type { Change } from '../shared/audit';
import { BRANCH_TRIGGER, branchPathOf } from '../shared/branch';
import { timestampDay } from '../shared/dates';
import { bump, type Counts, increments } from '../shared/statsCounts';

/**
 * Inventory analytics summary `inventoryStats/overall`: current-state figures for the branch, and the balance
 * figures per store under `stores`. Kept only by the triggers below (the audit triggers of the request / order
 * collections run [recordStats] too); only `scripts/recompute-stats.ts`, run by hand, recounts it. Expiry needs no job: stock lines are counted by
 * the day of their earliest expiry (`expiryOn`) and the reader adds up the days before today and the next 30.
 *
 * ponytail: triggers are at-least-once and not retried, so a redelivered event counts twice and a failed one is lost,
 * and every write bumps one document (~1 write/s sustained), so a bulk import may fail a few. Key each event
 * (a marker per event ID) or split per store if the figures must be exact.
 */
const OPEN_ORDER = ['issued', 'acknowledged', 'partially_received'];
const AWAITING_RECEIPT = ['issued', 'acknowledged'];
const IN_MAINTENANCE = ['under_maintenance', 'under_repair'];

/** What the state of one document adds (`sign` = 1) or takes away (`sign` = -1): branch figures, and the store's. */
export function figures(collection: string, data: DocumentData | undefined, sign: number) {
  const branch: Counts = {};
  const store: Counts = {};
  if (!data) return { branch, store: undefined };
  switch (collection) {
    case 'inventoryItems':
      if (data.status === 'active') bump(branch, 'items', sign);
      break;
    case 'inventoryBalances': {
      for (const counts of [branch, store]) {
        bump(counts, 'available', sign * (data.quantityAvailable ?? 0));
        bump(counts, 'value', sign * (data.value ?? 0));
        if (data.isBelowReorderLevel === true) bump(counts, 'lowStock', sign);
        if (data.quantityAvailable === 0) bump(counts, 'outOfStock', sign);
        if (data.earliestExpiryDate)
          bump(counts, `expiryOn.${timestampDay(data.earliestExpiryDate)}`, sign);
      }
      return {
        branch,
        store: data.storeId ? { id: data.storeId as string, counts: store } : undefined,
      };
    }
    case 'inventoryPurchaseRequests':
      if (data.status === 'pending') bump(branch, 'pendingPurchaseRequests', sign);
      break;
    case 'inventoryIssueRequests':
      if (data.status === 'pending') bump(branch, 'pendingIssueRequests', sign);
      break;
    case 'inventoryPurchaseOrders':
      if (OPEN_ORDER.includes(data.status)) bump(branch, 'openPurchaseOrders', sign);
      if (AWAITING_RECEIPT.includes(data.status)) bump(branch, 'awaitingReceipt', sign);
      break;
    case 'inventoryAssets':
      bump(branch, 'assets', sign);
      if (IN_MAINTENANCE.includes(data.status)) bump(branch, 'underMaintenance', sign);
      break;
  }
  return { branch, store: undefined };
}

/** The signed difference a write makes to the summary, for the branch and for each store. */
export function deltas(collection: string, { before, after }: Change) {
  const branch: Counts = {};
  const stores: Record<string, Counts> = {};
  for (const [data, sign] of [
    [after, 1],
    [before, -1],
  ] as const) {
    const state = figures(collection, data, sign);
    for (const [key, amount] of Object.entries(state.branch)) bump(branch, key, amount);
    if (state.store)
      for (const [key, amount] of Object.entries(state.store.counts))
        bump((stores[state.store.id] ??= {}), key, amount);
  }
  const perStore = Object.entries(stores)
    .map(([id, counts]) => [id, increments(counts)] as const)
    .filter(([, fields]) => Object.keys(fields).length);
  return {
    ...increments(branch),
    ...(perStore.length && { stores: Object.fromEntries(perStore) }),
  };
}

/** Applies a write's effect on the summary. Collections the summary ignores, and writes that change no figure, cost nothing. */
export async function recordStats(collection: string, change: Change): Promise<void> {
  const update = deltas(collection, change);
  if (!Object.keys(update).length) return;
  await getFirestore()
    .doc(`${change.branchPath}/inventoryStats/overall`)
    .set(update, { merge: true });
}

/** Stats-only trigger for collections that are not audited (items, balances, assets). */
export const statsTrigger = (collection: string) =>
  onDocumentWritten(`${BRANCH_TRIGGER}/${collection}/{docId}`, async (event) =>
    recordStats(collection, {
      branchPath: branchPathOf(event.params),
      docId: event.params.docId,
      before: event.data?.before.data(),
      after: event.data?.after.data(),
    }),
  );

export const statsInventoryItems = statsTrigger('inventoryItems');
export const statsInventoryBalances = statsTrigger('inventoryBalances');
export const statsInventoryAssets = statsTrigger('inventoryAssets');
