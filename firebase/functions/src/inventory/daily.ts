import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { CallableContext } from '../shared/callable';
import { todayIST, addDays, weekOf } from '../shared/dates';
import { schoolCollection } from '../shared/firestore';
import { enqueue, post } from '../shared/outbox';
import { forEachSchool } from '../shared/scheduled';
import { Stock, unavailableEntry } from './stock';

/** Daily inventory job (architecture §5.2): expiry, and the FRS 10.22 date-driven notifications. */

const NEAR_DAYS = 30;

/** Moves one expired balance's usable stock to `quantityExpired`; re-checked in the transaction, so reruns are no-ops. */
async function expire(
  db: Firestore,
  schoolId: string,
  balanceId: string,
  today: string,
): Promise<void> {
  await db.runTransaction(async (transaction) => {
    const context = new CallableContext(transaction, schoolId, 'system', {
      permissions: [],
      campusIds: [],
      hasAllCampuses: true,
    });
    const snapshot = await transaction.get(context.doc(`inventoryBalances/${balanceId}`));
    const balance = snapshot.data();
    if (!balance?.expiryDate || balance.expiryDate >= today || !(balance.quantityAvailable > 0))
      return;
    const stock = new Stock(context);
    const item = await stock.item(balance.itemId, balance.variantId, true);
    const expiringBalance = await stock.existing(balanceId, item);
    const quantity = expiringBalance.data.quantityAvailable;
    const referenceId = `expiry__${balanceId}__${today}`;
    stock.move(expiringBalance, 'available', -quantity, {
      type: 'expire',
      referenceType: 'job',
      referenceId,
    });
    stock.move(expiringBalance, 'expired', quantity, {
      type: 'expire',
      referenceType: 'job',
      referenceId,
    });
    unavailableEntry(stock, expiringBalance, quantity, {
      bucket: 'expired',
      reason: 'expired',
      remarks: `Expired on ${balance.expiryDate}`,
      referenceType: 'job',
      referenceId,
    });
    await enqueue(context, `inventory-stock-expired__${balanceId}__${today}`, {
      to: { permission: 'inventory.stock.operate', campusId: balance.campusId },
      category: 'inventory.expiry',
      title: 'Stock expired',
      body: `${item.name}${balance.batchNumber ? ` (batch ${balance.batchNumber})` : ''}: ${quantity} moved to expired.`,
      data: { balanceId },
    });
    await stock.finish();
    context.flush();
  });
}

export async function runDailyInventory(schoolId: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const collection = (name: string) => schoolCollection(schoolId, name);

  for (const snapshot of (
    await collection('inventoryBalances').where('earliestExpiryDate', '<', today).get()
  ).docs)
    await expire(db, schoolId, snapshot.id, today);

  const week = weekOf(today);
  const near = await collection('inventoryBalances')
    .where('earliestExpiryDate', '>=', today)
    .where('earliestExpiryDate', '<=', addDays(today, NEAR_DAYS))
    .get();
  const byStore = new Map<string, { campusId: number; batchCount: number }>();
  for (const snapshot of near.docs) {
    const entry = byStore.get(snapshot.data().storeId) ?? {
      campusId: snapshot.data().campusId,
      batchCount: 0,
    };
    byStore.set(snapshot.data().storeId, { ...entry, batchCount: entry.batchCount + 1 });
  }
  for (const [storeId, { campusId, batchCount: count }] of byStore) {
    await post(db, schoolId, `inventory-near-expiry__${storeId}__${week}`, {
      to: { permission: 'inventory.stock.operate', campusId },
      category: 'inventory.expiry',
      title: 'Stock nearing expiry',
      body: `${count} batch(es) expire within ${NEAR_DAYS} days.`,
      data: { storeId },
    });
  }

  const overdue = await collection('inventoryPurchaseOrders')
    .where('status', 'in', ['issued', 'acknowledged', 'partially_received'])
    .where('expectedDate', '<', today)
    .get();
  for (const snapshot of overdue.docs) {
    const purchaseOrder = snapshot.data();
    await post(db, schoolId, `inventory-purchase-order-overdue__${snapshot.id}__${week}`, {
      to: { permission: 'inventory.procure.operate', campusId: purchaseOrder.deliveryCampusId },
      category: 'inventory.purchaseOrder',
      title: 'Delivery overdue',
      body: `${purchaseOrder.number} was due ${purchaseOrder.expectedDate}.`,
      data: { purchaseOrderId: snapshot.id },
    });
  }

  const live = (assetStatus: string) => assetStatus !== 'retired' && assetStatus !== 'disposed';
  const warranty = await collection('inventoryAssets')
    .where('warranty.end', '>=', today)
    .where('warranty.end', '<=', addDays(today, NEAR_DAYS))
    .get();
  for (const snapshot of warranty.docs.filter((asset) => live(asset.data().status))) {
    const asset = snapshot.data();
    await post(db, schoolId, `inventory-warranty-ending__${snapshot.id}__${asset.warranty.end}`, {
      to: { permission: 'inventory.assets.manage', campusId: asset.campusId },
      category: 'inventory.asset',
      title: 'Warranty ending',
      body: `${asset.assetId} ${asset.name}: warranty ends ${asset.warranty.end}.`,
      data: { assetId: snapshot.id },
    });
  }

  const service = await collection('inventoryAssets')
    .where('nextServiceDate', '<=', addDays(today, 7))
    .get();
  for (const snapshot of service.docs.filter(
    (asset) => live(asset.data().status) && asset.data().nextServiceDate,
  )) {
    const asset = snapshot.data();
    await post(
      db,
      schoolId,
      `inventory-maintenance-due__${snapshot.id}__${asset.nextServiceDate}`,
      {
        to: { permission: 'inventory.assets.manage', campusId: asset.campusId },
        category: 'inventory.asset',
        title: 'Maintenance due',
        body: `${asset.assetId} ${asset.name}: service due ${asset.nextServiceDate}.`,
        data: { assetId: snapshot.id },
      },
    );
  }
}

/** 06:00 IST, every school. Idempotent: expiry is re-checked per balance and notification keys are deterministic. */
export const dailyInventory = onSchedule(
  { schedule: '0 6 * * *', timeZone: 'Asia/Kolkata', timeoutSeconds: 540 },
  async () => {
    await forEachSchool(runDailyInventory);
  },
);
