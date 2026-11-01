import '../region';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { Ctx } from '../shared/callable';
import { enqueue, post } from '../shared/outbox';
import { Stock, todayIST, unavailableEntry } from './stock';

/** Daily inventory job (architecture §5.2): expiry, and the FRS 10.22 date-driven notifications. */

const NEAR_DAYS = 30;
const addDays = (d: string, n: number) => new Date(Date.parse(`${d}T00:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);
// Reminders that stay true for days repeat weekly, not daily.
const weekOf = (d: string) => Math.floor(Date.parse(`${d}T00:00:00Z`) / (7 * 86_400_000));

/** Moves one expired balance's usable stock to `qtyExpired`; re-checked in the transaction, so reruns are no-ops. */
async function expire(db: Firestore, sid: string, balanceId: string, today: string): Promise<void> {
  await db.runTransaction(async (tx) => {
    const ctx = new Ctx(tx, sid, 'system', { perms: [], cmp: [], all: true });
    const snap = await tx.get(ctx.doc(`invBalances/${balanceId}`));
    const d = snap.data();
    if (!d || !d.expiryDate || d.expiryDate >= today || !(d.qtyAvailable > 0)) return;
    const s = new Stock(ctx);
    const item = await s.item(d.itemId, d.variantId, true);
    const bal = await s.existing(balanceId, item);
    const q = bal.d.qtyAvailable;
    const refId = `expiry__${balanceId}__${today}`;
    s.move(bal, 'available', -q, { type: 'expire', refType: 'job', refId });
    s.move(bal, 'expired', q, { type: 'expire', refType: 'job', refId });
    unavailableEntry(s, bal, q, { bucket: 'expired', reason: 'expired', note: `Expired on ${d.expiryDate}`, refType: 'job', refId });
    await enqueue(ctx, `expired__${balanceId}__${today}`, {
      to: { perm: 'inv.stock.operate', campusId: d.campusId }, category: 'inv.expiry',
      title: 'Stock expired', body: `${item.name}${d.batchNo ? ` (batch ${d.batchNo})` : ''}: ${q} moved to expired.`, data: { balanceId },
    });
    await s.finish();
    ctx.flush();
  });
}

export async function runDailyInventory(sid: string, today = todayIST()): Promise<void> {
  const db = getFirestore();
  const coll = (p: string) => db.collection(`schools/${sid}/${p}`);

  for (const d of (await coll('invBalances').where('expKey', '<', today).get()).docs) await expire(db, sid, d.id, today);

  const week = weekOf(today);
  const near = await coll('invBalances').where('expKey', '>=', today).where('expKey', '<=', addDays(today, NEAR_DAYS)).get();
  const byStore = new Map<string, { campusId: number; n: number }>();
  for (const d of near.docs) {
    const e = byStore.get(d.data().storeId) ?? { campusId: d.data().campusId, n: 0 };
    byStore.set(d.data().storeId, { ...e, n: e.n + 1 });
  }
  for (const [storeId, { campusId, n }] of byStore) {
    await post(db, sid, `nearexpiry__${storeId}__${week}`, {
      to: { perm: 'inv.stock.operate', campusId }, category: 'inv.expiry',
      title: 'Stock nearing expiry', body: `${n} batch(es) expire within ${NEAR_DAYS} days.`, data: { storeId },
    });
  }

  const overdue = await coll('invPurchaseOrders').where('status', 'in', ['issued', 'acknowledged', 'partially_received']).where('expectedDate', '<', today).get();
  for (const d of overdue.docs) {
    const po = d.data();
    await post(db, sid, `po_overdue__${d.id}__${week}`, {
      to: { perm: 'inv.procure.operate', campusId: po.deliveryCampusId }, category: 'inv.purchaseOrder',
      title: 'Delivery overdue', body: `${po.number} was due ${po.expectedDate}.`, data: { poId: d.id },
    });
  }

  const live = (s: string) => s !== 'retired' && s !== 'disposed';
  const warranty = await coll('invAssets').where('warranty.end', '>=', today).where('warranty.end', '<=', addDays(today, NEAR_DAYS)).get();
  for (const d of warranty.docs.filter((x) => live(x.data().status))) {
    const a = d.data();
    await post(db, sid, `warranty__${d.id}__${a.warranty.end}`, {
      to: { perm: 'inv.assets.manage', campusId: a.campusId }, category: 'inv.asset',
      title: 'Warranty ending', body: `${a.assetId} ${a.name}: warranty ends ${a.warranty.end}.`, data: { assetId: d.id },
    });
  }

  const service = await coll('invAssets').where('nextServiceDate', '<=', addDays(today, 7)).get();
  for (const d of service.docs.filter((x) => live(x.data().status) && x.data().nextServiceDate)) {
    const a = d.data();
    await post(db, sid, `service_due__${d.id}__${a.nextServiceDate}`, {
      to: { perm: 'inv.assets.manage', campusId: a.campusId }, category: 'inv.asset',
      title: 'Maintenance due', body: `${a.assetId} ${a.name}: service due ${a.nextServiceDate}.`, data: { assetId: d.id },
    });
  }
}

/** 06:00 IST, every school. Idempotent: expiry is re-checked per balance and notification keys are deterministic. */
export const dailyInventory = onSchedule({ schedule: '0 6 * * *', timeZone: 'Asia/Kolkata' }, async () => {
  for (const school of await getFirestore().collection('schools').listDocuments()) await runDailyInventory(school.id);
});
