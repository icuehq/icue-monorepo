import { beforeEach, describe, expect, it } from 'vitest';
import { runDailyInventory } from '../src/inventory/daily';
import { masters } from '../src/inventory/masters';
import { verification as v } from '../src/inventory/verification';
import { runCallable, type CallableDef } from '../src/shared/callable';
import { dayTimestamp } from '../src/shared/dates';
import { adjustStock, receiveStock, seedCount, seedStore } from './fixtures';
import { clearFirestore, db } from './setup';

const SCHOOL_ID = '12';
let requestSequence = 0;

const run = (definition: CallableDef<any, any>, data: Record<string, unknown>, uid = '1') =>
  runCallable(
    definition,
    { uid, token: { schoolId: 12, personType: 'staff' } },
    { requestId: `req-${String(++requestSequence).padStart(6, '0')}`, ...data },
  );
const get = async (path: string) => (await db().doc(`schools/${SCHOOL_ID}/${path}`).get()).data();
const col = async (path: string): Promise<Record<string, any>[]> =>
  (await db().collection(`schools/${SCHOOL_ID}/${path}`).get()).docs.map((outboxDocument) => ({
    id: outboxDocument.id,
    ...outboxDocument.data(),
  }));
const code = (promise: Promise<unknown>) =>
  promise.then(
    () => 'ok',
    (error) => error.code,
  );
const day = (offset: number) =>
  new Date(Date.now() + 330 * 60_000 + offset * 86_400_000).toISOString().slice(0, 10);

describe('stock verification and daily job', () => {
  let store: string, pen: string, ink: string, med: string;
  const bid = (item: string, batch = '-') => `${store}__${item}__-__${batch}`;
  const open = async () => (await run(v.create, { storeId: store })) as { id: string };
  const count = (id: string, lineItems: Parameters<typeof seedCount>[1]) =>
    seedCount(id, lineItems);

  beforeEach(async () => {
    await clearFirestore();
    const permissionsList = (permissions: string[], campusIds = [31]) => ({
      permissions,
      campusIds,
      hasAllCampuses: false,
      personErpId: 5,
    });
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/1`)
      .set(
        permissionsList([
          'inventory.settings',
          'inventory.items.manage',
          'inventory.stock.operate',
        ]),
      );
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/apr`)
      .set(permissionsList(['inventory.adjustment.approve']));
    await db()
      .doc(`schools/${SCHOOL_ID}/userAccess/far`)
      .set(permissionsList(['inventory.stock.operate'], [99]));
    await run(masters.seedDefaults, {});
    const category = (
      await run(masters.categoryUpsert, {
        code: 'GEN',
        name: 'General',
        suggestedTracking: 'quantity',
      })
    ).id;
    const makeItem = (itemCode: string, extra: Record<string, unknown> = {}) =>
      run(masters.itemUpsert, {
        code: itemCode,
        name: itemCode,
        categoryId: category,
        stockUnit: 'pcs',
        tracking: 'quantity',
        ...extra,
      }).then((result) => result.id as string);
    [pen, ink, med] = [
      await makeItem('PEN'),
      await makeItem('INK'),
      await makeItem('MED', { tracking: 'batch' }),
    ];
    store = (await seedStore({ name: 'Main', campusId: 31 })).id;
    await run(receiveStock, {
      storeId: store,
      source: 'opening',
      lineItems: [
        { itemId: pen, quantityAccepted: 10, unitCost: 5 },
        { itemId: ink, quantityAccepted: 4, unitCost: 20 },
        { itemId: med, quantityAccepted: 6, unitCost: 2, batchNumber: 'B1', expiryDate: day(10) },
      ],
    });
  });

  it('snapshots expected quantities, needs every line counted and every difference explained', async () => {
    const { id } = await open();
    expect(
      (await col(`inventoryVerifications/${id}/lineItems`))
        .map((verification) => verification.expected as number)
        .sort((left, right) => left - right),
    ).toEqual([4, 6, 10]);
    expect(await code(run(v.create, { storeId: store }, 'far'))).toBe('permission-denied');
    expect(await code(run(v.submit, { id }))).toBe('failed-precondition'); // nothing counted
    await count(id, [
      { balanceId: bid(pen), counted: 8 },
      { balanceId: bid(ink), counted: 4 },
      { balanceId: bid(med, 'B1'), counted: 6 },
    ]);
    expect(await code(run(v.submit, { id }))).toBe('failed-precondition'); // pen difference has no reason
    await count(id, [{ balanceId: bid(pen), counted: 8, reason: 'excess' }]);
    expect(await code(run(v.submit, { id }))).toBe('failed-precondition'); // reason contradicts direction
    await count(id, [{ balanceId: bid(pen), counted: 8, reason: 'missing' }]);
    expect(await run(v.submit, { id })).toMatchObject({ differences: 1 });
  });

  it('approval applies differences as adjustments that reference the session; rejection reopens counting', async () => {
    const { id } = await open();
    await count(id, [
      { balanceId: bid(pen), counted: 8, reason: 'missing' },
      { balanceId: bid(ink), counted: 5, reason: 'excess' },
      { balanceId: bid(med, 'B1'), counted: 6 },
    ]);
    await run(v.submit, { id });
    expect(await code(run(v.decide, { id, decision: 'approve' }))).toBe('permission-denied'); // 1 cannot approve
    await run(v.decide, { id, decision: 'reject', comment: 'Recount pens' }, 'apr');
    expect((await get(`inventoryVerifications/${id}`))!.status).toBe('counting');
    await run(v.submit, { id });
    expect(await run(v.decide, { id, decision: 'approve' }, 'apr')).toMatchObject({ applied: 2 });
    expect((await get(`inventoryBalances/${bid(pen)}`))!.quantityAvailable).toBe(8);
    expect((await get(`inventoryBalances/${bid(ink)}`))!.quantityAvailable).toBe(5);
    expect(await col('inventoryAdjustments')).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          verificationId: id,
          delta: -2,
          reason: 'missing',
          status: 'completed',
        }),
      ]),
    );
    expect(
      (await col('inventoryMovements')).filter(
        (movement) => movement.referenceType === 'verification',
      ),
    ).toHaveLength(2);
    expect(await get(`inventoryVerifications/${id}`)).toMatchObject({
      status: 'applied',
      adjustmentCount: 2,
    });
    expect(await code(run(v.decide, { id, decision: 'approve' }, 'apr'))).toBe(
      'failed-precondition',
    );
  });

  it('a session without differences closes itself', async () => {
    const { id } = await open();
    await count(id, [
      { balanceId: bid(pen), counted: 10 },
      { balanceId: bid(ink), counted: 4 },
      { balanceId: bid(med, 'B1'), counted: 6 },
    ]);
    expect(await run(v.submit, { id })).toMatchObject({ differences: 0 });
    expect((await get(`inventoryVerifications/${id}`))!.status).toBe('applied');
  });

  it('daily job moves expired batches once and posts reminders', async () => {
    expect((await get(`inventoryBalances/${bid(med, 'B1')}`))!.earliestExpiryDate).toEqual(
      dayTimestamp(day(10)),
    );
    await runDailyInventory(SCHOOL_ID, day(0));
    expect(await col('outbox')).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ category: 'inventory.expiry', title: 'Stock nearing expiry' }),
      ]),
    );
    await runDailyInventory(SCHOOL_ID, day(11));
    await runDailyInventory(SCHOOL_ID, day(11));
    expect(await get(`inventoryBalances/${bid(med, 'B1')}`)).toMatchObject({
      quantityAvailable: 0,
      quantityExpired: 6,
      earliestExpiryDate: null,
    });
    expect(
      (await col('inventoryMovements')).filter((movement) => movement.type === 'expire'),
    ).toHaveLength(2);
    expect(
      (await col('inventoryUnavailableStock')).filter(
        (unavailableStock) => unavailableStock.reason === 'expired',
      ),
    ).toHaveLength(1);
    expect(
      (await col('outbox')).filter((outboxEvent) => outboxEvent.title === 'Stock expired'),
    ).toHaveLength(1);
  });

  it('out of stock is announced once when an issue empties a balance', async () => {
    await run(adjustStock, {
      storeId: store,
      itemId: ink,
      delta: -4,
      reason: 'missing',
    });
    const out = (await col('outbox')).filter(
      (outboxEvent) => outboxEvent.category === 'inventory.outOfStock',
    );
    expect(out).toHaveLength(1);
  });
});
