import { Timestamp } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';
import { recordStats } from '../src/inventory/stats';
import { dayTimestamp } from '../src/shared/dates';
import { clearFirestore, db } from './setup';

const BRANCH = 'orgs/8/zones/147/branches/427';
const read = async () => (await db().doc(`${BRANCH}/inventoryStats/overall`).get()).data();
const record = (collection: string, before?: object, after?: object) =>
  recordStats(collection, { branchPath: BRANCH, docId: 'x', before, after });
const balance = (over: Record<string, unknown> = {}) => ({
  storeId: 's1',
  quantityAvailable: 10,
  value: 250.5,
  isBelowReorderLevel: false,
  earliestExpiryDate: dayTimestamp('2999-01-01') as Timestamp,
  ...over,
});

describe('inventory analytics summary', () => {
  beforeEach(clearFirestore);

  it('a balance moves the branch and its store, and its expiry day', async () => {
    const first = balance();
    await record('inventoryBalances', undefined, first);
    await record(
      'inventoryBalances',
      first,
      balance({
        quantityAvailable: 0,
        value: 0,
        isBelowReorderLevel: true,
        earliestExpiryDate: null,
      }),
    );
    expect(await read()).toMatchObject({
      available: 0,
      value: 0,
      lowStock: 1,
      outOfStock: 1,
      expiryOn: { '2999-01-01': 0 },
      stores: { s1: { available: 0, lowStock: 1, outOfStock: 1, expiryOn: { '2999-01-01': 0 } } },
    });
  });

  it('request, order, asset and item counts follow their status', async () => {
    await record('inventoryPurchaseRequests', undefined, { status: 'pending' });
    await record('inventoryPurchaseRequests', { status: 'pending' }, { status: 'approved' });
    await record('inventoryIssueRequests', undefined, { status: 'pending' });
    await record('inventoryPurchaseOrders', undefined, { status: 'issued' });
    await record('inventoryPurchaseOrders', { status: 'issued' }, { status: 'partially_received' });
    await record('inventoryAssets', undefined, { status: 'under_repair' });
    await record('inventoryItems', undefined, { status: 'active' });
    await record('inventoryItems', undefined, { status: 'inactive' });
    expect(await read()).toMatchObject({
      pendingPurchaseRequests: 0,
      pendingIssueRequests: 1,
      openPurchaseOrders: 1,
      awaitingReceipt: 0,
      assets: 1,
      underMaintenance: 1,
      items: 1,
    });
  });

  it('a write that changes no figure writes nothing', async () => {
    await record('inventoryPurchaseRequests', { status: 'approved' }, { status: 'ordered' });
    await record('inventoryQuotations', undefined, { status: 'final' });
    expect(await read()).toBeUndefined();
  });
});
